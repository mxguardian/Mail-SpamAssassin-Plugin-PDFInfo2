use strict;
use warnings;
use Test::More;
use Capture::Tiny qw(:all);
use PDF::Info;
use Data::Dumper;

my @files = glob('t/Data/*.pdf');
plan tests => scalar(@files);

test_file($_) for @files;

sub test_file {
    my ($filename) = @_;

    open my $fh, '<', $filename or die;
    local $/ = undef;
    my $data = <$fh>;
    close $fh;

    my $pdf = PDF::Info->new($data);
    
    is_deeply pdf_info($filename), $pdf->info(), "$filename";
}

sub pdf_info {
    my ($filename) = @_;
    my ($stdout, $stderr, $exit);
    my $pdf_text_info = {
        links  => 0,
        uris   => {},
        pages  => 0,
        images => 0,
    };

    # Get page count and URI's
    ($stdout, $stderr, $exit) = capture {
        system('/usr/bin/podofopdfinfo', $filename);
    };
    $exit == 0 or die "PDFText: podofopdfinfo: $stderr";
    for (split(/^/, $stdout)) {
        if (/Action URI:\s+(http.*)/) {
            $pdf_text_info->{uris}->{$1} = 1;
            $pdf_text_info->{links}++;
        }
        elsif (/^Page Count:\s+(\d+)/) { # be careful: Page Count appears twice
            $pdf_text_info->{pages} += $1;
        }
    }

    # Count images
    my $images = 0;
    ($stdout, $stderr, $exit) = capture {
        system('/usr/bin/pdfimages', '-list', $filename);
    };
    $exit == 0 or die "PDFText: $stderr";
    for (split(/^/, $stdout)) {
        $images++ if /^\s*\d/;
    }
    $pdf_text_info->{images} += $images;

    return $pdf_text_info;
}
