package PDF::Info;
use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Carp;

use base 'Exporter';
our @EXPORT_OK = qw(parse_data parse_file);

sub new {
    my ($class,$filename) = @_;
    open my $fh, '<', $filename or die;
    bless {
        fh       => $fh,
        filename => $filename,
        tokens   => [],
        p        => 0,
    }, $class;
}

sub _get_tokens {
    my ($self) = @_;
    return pop(@{$self->{tokens}}) if @{$self->{tokens}};
    my $line = readline($self->{fh});

}

sub info {
    my ($self) = @_;
    return $self->{info} if defined($self->{info});

    $self->{info} = {
        links  => 0,
        uris   => {},
        pages  => 0,
        words  => 0,
        images => 0,
        md5    => '',
        fuzzy   => '',
    };

    my %objects;
    my %trailer;

    my $offset = 0;

    while (my @toks = PDFGetPrimitive($self->{fh},\$offset) ) {
        print Dumper(\@toks);
        if ( $toks[0] eq 'xref' ) {
            for(my $i=1;$i<scalar(@toks);$i++) {
                if ( $toks[$i] eq 'trailer' ) {
                    %trailer = ( %{$toks[++$i]}, %trailer );
                }
            }
            print Dumper(\%trailer);
            last;
        } elsif ( $toks[2] eq 'obj' ) {
            if ( $toks[4] eq 'stream' ) {
                 while (my $line = readline($self->{fh}) ) {
                     $offset += length($line);
                     last if $line =~ /^endobj\b/;
                 }
            }
        } else {
            die "Invalid token";
        }

    }

    return $self->{info};
}

sub _get_obj {
    my ($self) = @_;
    my %obj;

    while (my $line = readline($self->{fh}) ) {
        last if $line =~ /^endobj\b/;
    }
    return \%obj;
}

sub parse_file {
    my ($file) = @_;
    open my $fh, '<', $file or die;
    local $/ = undef;
    my $data = <$fh>;
    close $fh;
    return parse_data($data);
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

    # Remove UTF-8 BOM
    $data =~ s/^\xef\xbb\xbf//;

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

1;
