use strict;
use warnings;
use Test::More;
use Capture::Tiny qw(:all);
use PDF::Parser;
use Data::Dumper;

my @files = glob('t/Data/*.pdf');
plan tests => scalar(@files);

test_file($_) for @files;

sub test_file {
    my ($filename) = @_;

    # print "Testing $filename\n";

    open my $fh, '<', $filename or die;
    local $/ = undef;
    my $data = <$fh>;
    close $fh;

    my $pdf = PDF::Parser->new($data);

    my ($got,$expected) = ($pdf->info()->{images}->{count},pdf_info($filename)->{images}->{count});
    if ( $got == $expected ) {
        ok 1;
    } else {
        ok 0, $filename;
        print "#       test: image count\n";
        print "#        got: $got\n";
        print "#   expected: $expected\n";
        print "#\n";
    }
    # is_deeply $pdf->info(), pdf_info($filename), "$filename";
}

sub pdf_info {
    my ($filename) = @_;
    my ($stdout, $stderr, $exit);
    my $pdf_text_info = {
        links  => 0,
        uris   => {},
        pages  => 0,
        images => {
            count => 0,
            area  => 0,
        },
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
    my %images;
    ($stdout, $stderr, $exit) = capture {
        system('/usr/bin/pdfimages', '-list', $filename);
    };
    $exit == 0 or die "PDFText: $stderr";
    for (split(/^/, $stdout)) {
        my $color = substr($_,32,3);
        next if $color eq 'gra'; # skip grayscale images - probably a mask
        my $object = substr($_,60,6);
        $object =~ s/^\s+|\s+$//;
        $images{$object} = 1 if $object =~ /^\d+$/;
    }
    $pdf_text_info->{images}->{count} += scalar(keys %images);

    return $pdf_text_info;
}
