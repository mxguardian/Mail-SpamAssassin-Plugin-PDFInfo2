use strict;
use warnings;
use Test::More;
use PDF::Parser;
use PDF::Context::Info;
use Data::Dumper;

my @tests = (
    {
        filename => 't/data/North Gaston HS flyer.pdf',
        expected => {
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
        filename => 't/data/Profile_with_photo_and_videos_from_Gianna-4267fZmSNyvIvbc.pdf',
        expected => {
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
        filename => 't/data/Doc2 (1).pdf',
        expected => {
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
        filename => 't/data/9221092480 NB Settlement Quote.pdf',
        expected => {
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
    my $context = PDF::Context::Info->new();
    my $pdf = PDF::Parser->new(
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
