package PDF::Info;
use strict;
use bytes;
use warnings FATAL => 'all';
use PDF::Core;
use PDF::FlateDecode;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Carp;

sub new {
    my ($class,$data) = @_;

    $data =~ /^%PDF\-(\d\.\d)/ or carp("PDF magic header not found");

    my $self = bless {
        data    => $data,
        version => $1,
        xref    => {},
        trailer => {}
    }, $class;

    $self;
}

sub info {
    my ($self) = @_;
    $self->parse unless defined($self->{info});
    return $self->{info};
}

sub parse {
    my ($self) = @_;

    $self->{info} = {
        links  => 0,
        uris   => {},
        pages  => 0,
        images => {
            count => 0,
            area  => 0,
        },
    };

    $self->{data} =~ /(\d+)\s+\%\%EOF\s*$/ or die "EOF marker not found";

    $self->_parse_xref($1);

    $self->{catalog} = $self->_get_obj($self->{trailer}->{'/Root'});

    $self->{pages} = $self->_get_obj($self->{catalog}->{'/Pages'});

    $self->{info}->{pages} = $self->{pages}->{'/Count'};

    $self->_parse_pages($self->{catalog}->{'/Pages'});

}

sub _parse_xref {
    my ($self,$pos) = @_;

    pos($self->{data}) = $pos;

    if ( $self->{data} =~ /\G\s*\d+ \d+ obj\s+/) {
        return $self->_parse_xref_stream($+[0]);
    }
    $self->{data} =~ /\G\s*xref\s+/g or die "xref not found at position $pos";

    while ($self->{data} =~ /\G(\d+) (\d+)\s+/) {
        pos($self->{data}) = $+[0]; # advance the pointer
        my ($start,$count) = ($1,$2);
        # print "xref $start $count\n";
        for (my ($i,$n)=($start,0);$n<$count;$i++,$n++) {
            $self->{data} =~ /\G(\d+) (\d+) (f|n)\s+/g or die "Invalid xref entry";
            # print "$1 $2 $3\n";
            next unless $3 eq 'n';
            my ($offset,$gen) = ($1+0,$2+0);
            my $key = "$i $gen R";
            # print "$key = $offset\n";
            $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
        }
    }

    $self->{data} =~ /\G\s*trailer\s+/g or die "trailer not found";

    my $trailer = PDF::Core::_get_dict(\$self->{data});
    $self->{trailer} = {
        %{$trailer},
        %{$self->{trailer}}
    };

    if ( defined($trailer->{'/Prev'}) ) {
        $self->_parse_xref($trailer->{'/Prev'});
    }

}

sub _parse_xref_stream {
    my ($self,$pos) = @_;

    pos($self->{data}) = $pos;

    my $xref = PDF::Core::_get_dict(\$self->{data});
    # print Dumper($xref);
    my $start = $xref->{'/Index'}->[0];
    my $count = $xref->{'/Index'}->[1];
    my $width = $xref->{'/W'}->[0] + $xref->{'/W'}->[1] + $xref->{'/W'}->[2];
    my $template = 'H'.($xref->{'/W'}->[0]*2).'H'.($xref->{'/W'}->[1]*2).'H'.($xref->{'/W'}->[2]*2);

    my $data = $self->_get_stream_data($xref);

    for ( my ($i,$n,$o)=($start,0,0); $n<$count; $i++,$n++,$o+=$width ) {
        my ($type,@fields) = map { hex($_) } unpack("x$o $template",$data);
        # print join(',',@fields),"\n";
        if ( $type == 0 ) {
            next;
        } elsif ( $type == 1 ) {
            my ($offset,$gen) = @fields;
            my $key = "$i $gen R";
            # print "$key = $offset\n";
            $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
        } elsif ( $type == 2 ) {
            my ($obj,$index) = @fields;
            my $key = "$i 0 R";
            # print "$key = $obj,$index\n";
            $self->{xref}->{$key} = [ "$obj 0 R", $index ] unless defined($self->{xref}->{$key});
        }
    }

    $self->{trailer} = $xref;

}

sub _parse_pages {
    my ($self,$ref) = @_;

    my $node = $self->_get_obj($ref);
    # print Dumper($node);
    return unless defined($node);

    if ( $node->{'/Type'} eq '/Pages' ) {
        $self->_parse_pages($_) for (@{$node->{'/Kids'}});
        return;
    } elsif ( $node->{'/Type'} eq '/Page' ) {
        $self->_parse_annotations($node->{'/Annots'}) if (defined($node->{'/Annots'}));
        $self->_parse_resources($node->{'/Resources'}) if (defined($node->{'/Resources'}));
    } else {
        die "Unexpected page type";
    }

}

sub _parse_annotations {
    my ($self,$annots) = @_;
    $annots = $self->_dereference($annots);
    return unless defined($annots);

    for my $ref (@$annots) {
        my $annot = $self->_get_obj($ref);
        if ( $annot->{'/Subtype'} eq '/Link' && defined($annot->{'/A'}) ) {
            $self->_parse_action($annot->{'/A'});
        }
    }

}

sub _parse_action {
    my ($self,$action) = @_;

    if ( $action->{'/S'} eq '/URI' ) {
        my $location = $action->{'/URI'};
        $self->{info}->{uris}->{$location} = 1;
        $self->{info}->{links}++;
    }

    if ( defined($action->{'/Next'}) ) {
        # can be array or dict
        if ( ref($action->{'/Next'}) eq 'ARRAY' ) {
            $self->_parse_action($_) for @{$action->{'/Next'}};
        } else {
            $self->_parse_action($action->{'/Next'});
        }
    }

}
sub _parse_resources {
    my ($self,$resources) = @_;
    $resources = $self->_dereference($resources);
    return unless defined($resources);

    $self->_parse_xobject($resources->{'/XObject'}) if (defined($resources->{'/XObject'}));

}

sub _parse_xobject {
    my ($self,$xobject) = @_;
    $xobject = $self->_dereference($xobject);
    return unless defined($xobject);

    for my $name (keys %$xobject) {
        my $ref = $xobject->{$name};
        my $obj = $self->_get_obj($ref);
        if ( $obj->{'/Subtype'} eq '/Image' ) {
            if ( !defined($self->{images}->{$ref}) ) {
                $self->{images}->{$ref} = 1;
                $self->_parse_image($obj)
            }
        } elsif ( $obj->{'/Subtype'} eq '/Form' ) {
            $self->_parse_resources($obj->{'/Resources'}) if (defined($obj->{'/Resources'}));
        }
    }

}

sub _parse_image {
    my ($self,$image) = @_;
    return unless defined($image);

    $self->{info}->{images}->{count}++;

    # if ( defined($image->{'/SMask'}) ) {
    #     $self->_parse_image( $self->_dereference($image->{'/SMask'}) );
    # }

}

sub _get_obj {
    my ($self,$ref) = @_;

    # return undef for non-existent objects
    return undef unless defined($ref) && defined($self->{xref}->{$ref});

    # return cached object if possible
    return $self->{cache}->{$ref} if defined($self->{cache}->{$ref});

    if ( ref($self->{xref}->{$ref}) eq 'ARRAY' ) {
        my ($stream_obj_ref,$index) = @{$self->{xref}->{$ref}};
        return $self->{cache}->{$ref} = $self->_get_compressed_obj($stream_obj_ref,$index,$ref);
    }
    pos($self->{data}) = $self->{xref}->{$ref};
    $self->{data} =~ /\G\s*(\d+ \d+) obj\s*/g or die "object $ref not found";

    return $self->{cache}->{$ref} = PDF::Core::_get_primitive(\$self->{data});
}

sub _dereference {
    my ($self,$obj) = @_;
    while ( defined($obj) && !ref($obj) && $obj =~ /^\d+ \d+ R$/ ) {
        $obj = $self->_get_obj($obj);
    }
    return $obj;
}

sub _get_compressed_obj {
    my ($self,$stream_obj_ref,$index,$ref) = @_;

    $ref =~ /^(\d+)/ or die "invalid object reference";
    my $obj = $1;

    my $stream_obj = $self->_get_obj($stream_obj_ref);
    # print Dumper($stream_obj);
    my $data = $self->_get_stream_data($stream_obj);

    if ( !defined($stream_obj->{xref}) ) {
        while ( $data =~ /\G\s*(\d+) (\d+)/ ) {
            $stream_obj->{xref}->{$1} = $2;
            pos($data) = $+[0];
            # print "$1 -> $2\n";
        }
    }

    # print $data,"\n";
    # print "$stream_obj_ref $index $ref\n";
    # print $stream_obj->{xref}->{$obj},"\n";
    pos($data) = pos($data) + $stream_obj->{xref}->{$obj};
    return $self->{cache}->{$ref} = PDF::Core::_get_primitive(\$data);
}

sub _get_stream_data {
    my ($self,$stream_obj) = @_;

    return $stream_obj->{_stream} if defined($stream_obj->{_stream});

    my $offset = $stream_obj->{'_offset'};
    my $length = $stream_obj->{'/Length'};
    my $filter = $stream_obj->{'/Filter'} || '';

    if ( $filter eq '/FlateDecode' ) {
        return $stream_obj->{_stream} = PDF::FlateDecode::decode(
            substr($self->{data},$offset,$length),
            $stream_obj->{'/DecodeParms'},
        );
    }

    return substr($self->{data},$offset,$length);
}

sub parse_data {
    my ($data) = @_;
    my %info = (
        links  => 0,
        uris   => {},
        pages  => 0,
        words  => 0,
        images => 0,
        md5    => '',
        fuzzy   => '',
    );

    # Search magic in first 1024 bytes
    if ($data !~ /^.{0,1024}\%PDF\-(\d\.\d)/s) {
        dbg("PDF magic header not found, invalid file?");
        return;
    }
    my $version = $1;

    my ($fuzzy_data, $pdf_tags);
    my ($md5, $fuzzy_md5) = ('','');
    my ($total_height, $total_width, $total_area, $line_count) = (0,0,0,0);
    my $no_more_fuzzy = 0;
    my $got_image = 0;
    my $encrypted = 0;
    my ($width, $height);

    my %uris;
    my $pms = {};


    my %objects;
    while ($data =~ m/\b(\d+)\s+(\d+)\s*obj\b/g) {
        $objects{"$1.$2"} = {
            pos => pos($data)
        }
    }



    print Dumper(\%objects);
    return \%info;

    while ($data =~ /([^\n]+)/g) {
        #dbg("pdfinfo: line=$1");
        my $line = $1;


        if ($line =~ /\/Type\s*\/Page\b/) {
            $info{pages}++;
        }

        if (!$no_more_fuzzy && ++$line_count < 70) {
            if ($line !~ m/^\%/ && $line !~ m/^\/(?:Height|Width|(?:(?:Media|Crop)Box))/ && $line !~ m/^\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+cm$/) {
                $line =~ s/\s+$//;  # strip off whitespace at end.
                $fuzzy_data .= $line;
            }
            # once we hit the first stream, we stop collecting data for fuzzy md5
            $no_more_fuzzy = 1  if index($line, 'stream') >= 0;
        }

        $got_image = 1  if index($line, '/Image') >= 0;
        if (!$encrypted && index($line, '/Encrypt') == 0) {
            # store encrypted flag.
            $encrypted = $pms->{pdfinfo}->{encrypted} = 1;
        }

        # From a v1.3 pdf
        # [12234] dbg: pdfinfo: line=630 0 0 149 0 0 cm
        # [12234] dbg: pdfinfo: line=/Width 630
        # [12234] dbg: pdfinfo: line=/Height 149
        if ($got_image) {
            if ($line =~ /^(\d+)\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+cm$/) {
                $width = $1;
                $height = $2;
            }
            elsif ($line =~ /^\/Width\s(\d+)/) {
                $width = $1;
            }
            elsif ($line =~ /^\/Height\s(\d+)/) {
                $height = $1;
            }
            elsif ($line =~ m/\/Width\s(\d+)\/Height\s(\d+)/) {
                $width = $1;
                $height = $2;
            }
            if ($width && $height) {
                $no_more_fuzzy = 1;
                my $area = $width * $height;
                $total_height += $height;
                $total_width += $width;
                $total_area += $area;
                $pms->{pdfinfo}->{dems_pdf}->{"${height}x${width}"} = 1;
                $info{images}++;
                dbg("pdfinfo: Found image: $height x $width pixels ($area pixels sq.)");
                _set_tag($pms, 'PDFIMGDIM', "${height}x${width}");
                $got_image = $height = $width = 0;  # reset and check for next image
            }
        }

        #
        # Triage - expecting / to be found for rest of the checks
        #
        next unless index($line, '/') >= 0;

        if ($line =~ m/^\/([A-Za-z]+)/) {
            $pdf_tags .= $1;
        }

        # XXX some pdf have uris but are stored inside binary data
        if (keys %uris < 20 && $line =~ /(?:\/S\s{0,2}\/URI\s{0,2}|^\s*)\/URI\s{0,2}( \( .*? (?<!\\) \) | < [^>]* > )/x) {
            my $location = _parse_string($1);
            next unless index($location, '.') > 0; # ignore some binary mess
            if (!exists $uris{$location}) {
                $uris{$location} = 1;
                $info{uris}->{$location} = 1;
                $info{links}++;
                dbg("pdfinfo: found URI: $location");
            }
        }

        # [5310] dbg: pdfinfo: line=<</Producer(GPL Ghostscript 8.15)
        # [5310] dbg: pdfinfo: line=/CreationDate(D:20070703144220)
        # [5310] dbg: pdfinfo: line=/ModDate(D:20070703144220)
        # [5310] dbg: pdfinfo: line=/Title(Microsoft Word - Document1)
        # [5310] dbg: pdfinfo: line=/Creator(PScript5.dll Version 5.2)
        # [5310] dbg: pdfinfo: line=/Author(colet)>>endobj
        # or all on same line inside xml - v1.6+
        # <</CreationDate(D:20070226165054-06'00')/Creator( Adobe Photoshop CS2 Windows)/Producer(Adobe Photoshop for Windows -- Image Conversion Plug-in)/ModDate(D:20070226165100-06'00')>>
        # Or hex values
        # /Creator<FEFF005700720069007400650072>
        if ($line =~ /\/Author\s{0,2}( \( .*? (?<!\\) \) | < [^>]* > )/x) {
            my $author = _parse_string($1);
            dbg("pdfinfo: found property Author=$author");
            $pms->{pdfinfo}->{details}->{author}->{$author} = 1;
            _set_tag($pms, 'PDFAUTHOR', $author);
        }
        if ($line =~ /\/Creator\s{0,2}( \( .*? (?<!\\) \) | < [^>]* > )/x) {
            my $creator = _parse_string($1);
            dbg("pdfinfo: found property Creator=$creator");
            $pms->{pdfinfo}->{details}->{creator}->{$creator} = 1;
            _set_tag($pms, 'PDFCREATOR', $creator);
        }
        if ($line =~ /\/CreationDate\s{0,2}\(D\:(\d+)/) {
            my $created = _parse_string($1);
            dbg("pdfinfo: found property Created=$created");
            $pms->{pdfinfo}->{details}->{created}->{$created} = 1;
        }
        if ($line =~ /\/ModDate\s{0,2}\(D\:(\d+)/) {
            my $modified = _parse_string($1);
            dbg("pdfinfo: found property Modified=$modified");
            $pms->{pdfinfo}->{details}->{modified}->{$modified} = 1;
        }
        if ($line =~ /\/Producer\s{0,2}( \( .*? (?<!\\) \) | < [^>]* > )/x) {
            my $producer = _parse_string($1);
            dbg("pdfinfo: found property Producer=$producer");
            $pms->{pdfinfo}->{details}->{producer}->{$producer} = 1;
            _set_tag($pms, 'PDFPRODUCER', $producer);
        }
        if ($line =~ /\/Title\s{0,2}( \( .*? (?<!\\) \) | < [^>]* > )/x) {
            my $title = _parse_string($1);
            dbg("pdfinfo: found property Title=$title");
            $pms->{pdfinfo}->{details}->{title}->{$title} = 1;
            _set_tag($pms, 'PDFTITLE', $title);
        }
    }

    $md5 = uc(md5_hex($data)) if $data;
    $fuzzy_md5 = uc(md5_hex($fuzzy_data)) if $fuzzy_data;


    $info{md5} = $md5;
    $info{fuzzy} = $fuzzy_md5;

    return \%info;
}

sub _parse_string {
    local $_ = shift;
    # Anything inside < > is hex encoded
    if (/^</) {
        # Might contain whitespace so search all hex values
        my $str = '';
        $str .= pack("H*", $1) while (/([0-9A-Fa-f]{2})/g);
        $_ = $str;
        # Handle/strip UTF-16 (in ultra-naive way for now)
        s/\x00//g if (s/^(?:\xfe\xff|\xff\xfe)//);
    } else {
        s/^\(//; s/\)$//;
        # Decode octals
        # Author=\376\377\000H\000P\000_\000A\000d\000m\000i\000n\000i\000s\000t\000r\000a\000t\000o\000r
        s/(?<!\\)\\([0-3][0-7][0-7])/pack("C",oct($1))/ge;
        # Handle/strip UTF-16 (in ultra-naive way for now)
        s/\x00//g if (s/^(?:\xfe\xff|\xff\xfe)//);
        # Unescape some stuff like \\ \( \)
        # Title(Foo \(bar\))
        s/\\([()\\])/$1/g;
    }
    # Limit to some sane length
    return substr($_, 0, 256);
}


sub dbg {
    warn(shift);
}

sub _set_tag {

}

sub UnQuoteName ($)
{
    my $value = shift;
    $value =~ s/#([\da-f]{2})/chr(hex($1))/ige;
    return $value;
}

sub UnQuoteString ($)
{
    #
    # Translate quoted character.
    #
    my $param = shift;
    my $value;
    if (($value) = $param =~ m/^<(.*)>$/)
    {
        $value =~ tr/0-9A-Fa-f//cd;
        $value .= "0" if (length ($value) % 2);
        $value =~ s/([\da-f]{2})/chr(hex($1))/ige;
    }
    elsif (($value) = $param =~ m/^\((.*)\)$/)
    {
        my %quoted = ("n" => "\n", "r" => "\r",
            "t" => "\t", "b" => "\b",
            "f" => "\f", "\\" => "\\",
            "(" => "(", ")" => ")");
        $value =~ s/\\([nrtbf\\()]|[0-7]{1,3})/
            defined ($quoted{$1}) ? $quoted{$1} : chr(oct($1))/gex;
    }
    else
    {
        $value = $param;
    }

    return $value;
}

sub PDFGetPrimitive
{
    my $fd = shift;
    my $offset = shift;

    binmode $fd;
    seek $fd, $$offset, 0;

    my $state = 0;
    my $buffer = '';
    my @collector;
    my $lastchar;

    while ()
    {
        # File offset is positioned on start of stream.
        last if ($state == -4);

        $state = 0;

        # Process last element
        if ($#collector >= 0)
        {
            my $lastvalue = $collector[$#collector];

            if ($lastvalue eq "R")
            {
                # Process references
                if ($#collector >= 2
                    && $collector[$#collector - 1] =~ m/\d+/
                    && $collector[$#collector - 2] =~ m/\d+/)
                {
                    $collector[$#collector - 2] .= join (" ",
                        "", @collector[$#collector - 1, $#collector]);
                    $#collector -= 2;
                }
                else
                {
                    carp "Bad reference at offset ", $$offset;
                }
            }
            elsif ($lastvalue eq "endobj")
            {
                # End of object
                last;
            }
            elsif ($lastvalue eq "stream")
            {
                # End of object
                $state = -4;
            }
        }

        # Set state for next element
        if ($buffer eq "[")
        {
            # Read array
            $buffer = "";
            push @collector, [ PDFGetPrimitive ($fd, $offset) ];
        }
        elsif ($buffer eq "<<")
        {
            # Read dictionary
            $buffer = "";
            push @collector, { PDFGetPrimitive ($fd, $offset) };
        }
        elsif ($buffer eq "(")
        {
            # Here comes a string
            $state = 1;
            $lastchar = "";
        }
        elsif ($buffer eq "<")
        {
            # Here comes a hex string
            $state = -1;
        }
        elsif ($buffer eq ">")
        {
            # Wait for next > to terminate dictionary
            $state = -2;
        }
        elsif ($buffer eq "%")
        {
            # Skip comments
            $state = -3;
            $buffer = "";
        }
        elsif ($buffer eq "]")
        {
            last;
        }
        elsif ($buffer eq ">>")
        {
            last;
        }

        # Read next item
        while (read ($fd, $_, 1))
        {
            $$offset++;

            if ($state == 0)
            {
                # Normal mode
                if (m/[^\x00-\x20\x7f-\xff%()\[\]<>\/]/)
                {
                    # Normal character inside a name or number
                    $buffer .= $_;
                }
                elsif (m/[\/\(\[\]\<\>%]/)
                {
                    if ($buffer ne "")
                    {
                        # A new item starts
                        if ($buffer =~ m/^\//)
                        {
                            push @collector, UnQuoteName ($buffer);
                        }
                        else
                        {
                            push @collector, $buffer;
                        }
                    }
                    $buffer = $_;
                    last;
                }
                elsif (m/\s/)
                {
                    # All kind of whitespaces are ignored
                    if ($buffer ne "")
                    {
                        # The old item is done starts
                        if ($buffer =~ m/^\//)
                        {
                            push @collector, UnQuoteName ($buffer);
                        }
                        else
                        {
                            push @collector, $buffer;
                        }
                        $buffer = "";
                        last;
                    }
                }
                else
                {
                    # Strange character. Should not exist.
                    # Complain and move on.
                    carp "Strange character '", $_, "' at offset ",
                        $$offset, " in mode ", $state, " detected";
                    $buffer .= $_;
                }
            }
            elsif ($state > 0)
            {
                # We have a string

                if ($lastchar =~ m/\\[\r\n]+/ && m/[^\r\n]/)
                {
                    # Clean up after line continuation
                    $lastchar = "";
                }

                if ($lastchar =~ m/\\[\r\n]*/)
                {
                    # Process character after backslash
                    if (m/[\r\n]/)
                    {
                        # end of line
                        $lastchar .= $_;
                    }
                    else
                    {
                        # Just a quote
                        $buffer .= $lastchar . $_;
                        $lastchar = "";
                    }
                }
                else
                {
                    if ($_ eq "\\")
                    {
                        # Quoted string starts
                        $lastchar = $_;
                    }
                    elsif ($_ eq "(")
                    {
                        # Count braces
                        $buffer .= $_;
                        $state ++;
                    }
                    elsif ($_ eq ")")
                    {
                        # End of string
                        $buffer .= $_;
                        unless (-- $state)
                        {
                            push @collector, $buffer;
                            $buffer = "";
                            last;
                        }
                    }
                    else
                    {
                        $buffer .= $_;
                    }
                }
            }
            elsif ($state == -1)
            {
                if (m/[0-9a-f\s]/i)
                {
                    # Hex character
                    $buffer .= $_;
                }
                elsif ($_ eq ">")
                {
                    # End of string
                    $buffer .= $_;
                    push @collector, $buffer;
                    $buffer = "";
                    last;
                }
                elsif ($_ eq "<" && $buffer eq "<")
                {
                    # This is not a string, but a dictionary instead
                    $buffer .= $_;
                    last;
                }
                else
                {
                    # Should not be there. Complain and add it to the $buffer
                    carp "Bad character '", $_ , "' in hex string";
                    $buffer .= $_;
                }
            }
            elsif ($state == -2)
            {
                # Wait for second > to terminate dictionary

                # Some sanity checks
                carp "Character '", $_, "' appeared while waiting for '>'"
                    if ($_ ne ">");
                carp "Buffer contains '", $buffer, "' and not '>'"
                    if ($buffer ne ">");

                $buffer = ">>";
                last;
            }
            elsif ($state == -3)
            {
                # Skip comments;
                last if (m/[\r\n]/);
            }
            elsif ($state == -4)
            {
                # Wait for newline to start stream

                if ($_ eq "\n")
                {
                    # Some sanity checks
                    carp "Text '", $buffer,
                        "' appeared while waiting for start of stream"
                        if ($buffer ne "");

                    $buffer = "";
                    last;
                }
                elsif (m/\S/)
                {
                    $buffer .= $_;
                }
            }
            else
            {
                # Unhandled status. Complain and reset
                carp "Unhandled status ", $state;
            }
        }
        if ($_ eq "")
        {
            # Unhandled status. Complain and reset
            carp "Premature end of file reached";

            if ($buffer ne "")
            {
                push @collector, $buffer;
                $buffer = "";
            }
            last;
        }
    }

    return @collector;
}

sub _bin2hex {
    my $b = shift;
    my $n = length($b);
    my $s = 2*$n;
    return unpack("H$s", $b);
}

1;
