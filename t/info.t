use strict;
use warnings;
use Test::More;
use Mail::SpamAssassin::PDF::Parser;
use Mail::SpamAssassin::PDF::Context::Info;
use Data::Dumper;

my @tests = (
    {
        filename => 't/data/North Gaston HS flyer.pdf',
        expected => {
            'Encrypted' => 0,
            'Version' => '1.6',
            'PageCount' => 4,
            'Producer' => 'Adobe PDF Library 10.0.1',
            'ModDate' => 'D:20221010104230-04\'00\'',
            'Trapped' => '/False',
            'PageArea' => 484704,
            'Creator' => 'Adobe InDesign CS6 (Macintosh)',
            'ImageArea' => 14293,
            'CreationDate' => 'D:20221010092750-05\'00\'',
            'ImageCount' => 2,
            'Title' => '',
            'ImageDensity' => '2.95'
        }
    },
    {
        filename => 't/data/how_to_manage_club_members_en.pdf',
        expected   => {
            'Encrypted' => 0,
            'Version' => '1.5',
            'Producer' => 'Foxit PhantomPDF Printer Version 9.1.0.0531',
            'ImageCount' => 12,
            'PageCount' => 8,
            'ImageArea' => 296978,
            'Keywords' => '',
            'ModDate' => 'D:20200724162723-06\'00\'',
            'Creator' => '',
            'Author' => '',
            'ImageDensity' => '59.26',
            'Title' => '',
            'PageArea' => 501170,
            'Subject' => '',
            'CreationDate' => 'D:20200724162630-05\'00\''
        }
    },
    {
        filename => 't/data/Encrypted.pdf',
        expected => {
            'Encrypted' => 1,
            'Version' => '1.4',
            'CreationDate' => 'D:20230106154216+03\'00\'',
            'Creator' => 'wkhtmltopdf 0.12.5',
            'PageCount' => 2,
            'PageArea' => 500990,
            'ImageCount' => 1,
            'ImageArea' => 337055,
            'Title' => '',
            'Producer' => 'Qt 4.8.7',
            'ImageDensity' => '67.28'
        }
    },
    {
        filename => 't/data/Phishing.pdf',
        expected => {
            'Encrypted' => 0,
            'Version' => '1.5',
            'ImageDensity' => '33.08',
            'ModDate' => 'D:20221206220444-08\'00\'',
            'ImageCount' => 1,
            'ImageArea' => 160359,
            'PageArea' => 484704,
            'CreationDate' => 'D:20221206220444-08\'00\'',
            'PageCount' => 1,
            'Author' => 'jjj'
        }
    },
    {
        filename => 't/data/Phishing2.pdf',
        expected => {
            'Encrypted'    => 0,
            'Version'      => '1.3',
            'ImageDensity' => '100.00',
            'ImageCount'   => 1,
            'ImageArea'    => 501160,
            'PageArea'     => 501160,
            'CreationDate' => 'D:19700101030000+03\'00\'',
            'PageCount'    => 1,
            'Title'        => 'Adobe Document Cloud',
            'Producer'     => 'FPDF 1.85',
        }
    },
    {
        filename => 't/data/SlicedImages.pdf',
        expected => {
            'Encrypted' => 0,
            'Version' => '1.7',
            'PageCount' => 1,
            'ImageDensity' => '18.47',
            'Author' => 'Tom Orkney',
            'CreationDate' => 'D:20221221152022+00\'00\'',
            'ImageCount' => 111,
            'Producer' => 'Microsoft® Word for Microsoft 365',
            'Creator' => 'Microsoft® Word for Microsoft 365',
            'PageArea' => 501212,
            'ImageArea' => 92587,
            'ModDate' => 'D:20221221152022+00\'00\''
        }
    },
);

plan tests => scalar(@tests);

for my $test (@tests) {
    my $context = Mail::SpamAssassin::PDF::Context::Info->new();
    my $pdf = Mail::SpamAssassin::PDF::Parser->new(
        context => $context
    );

    $pdf->parse(get_file_contents($test->{filename}));
    is_deeply $context->get_info(), $test->{expected}, $test->{filename};

}


sub get_file_contents {
    my $file = shift;
    open my $fh, '<', $file or die;
    local $/ = undef;
    my $data = <$fh>;
    close $fh;
    return $data;
}
