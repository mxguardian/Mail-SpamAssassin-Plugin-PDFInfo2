package PDF::Info;
use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

use base 'Exporter';
our @EXPORT_OK = qw(parse_data parse_file);


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

1;
