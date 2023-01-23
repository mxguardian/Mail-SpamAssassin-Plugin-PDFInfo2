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
            'Encrypted'    => 0,
            'Version'      => '1.6',
            'PageCount'    => 4,
            'Producer'     => 'Adobe PDF Library 10.0.1',
            'ModDate'      => 'D:20221010104230-04\'00\'',
            'Trapped'      => '/False',
            'PageArea'     => 484704,
            'Creator'      => 'Adobe InDesign CS6 (Macintosh)',
            'ImageArea'    => 14293,
            'CreationDate' => 'D:20221010092750-05\'00\'',
            'ImageCount'   => 2,
            'Title'        => '',
            'ImageDensity' => '2.95',
            'LinkCount'    => 0,
            'uris'         => {},
            'FuzzyMD5'     => '715E8FD2D08512EA74B7CCB18DE49F88',
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
            'CreationDate' => 'D:20200724162630-05\'00\'',
            'LinkCount'    => 0,
            'uris'         => {},
            'FuzzyMD5'     => '332ED68EE285723FCE457839231B2FEF',
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
            'ImageDensity' => '67.28',
            'LinkCount'    => 1,
            'uris' => {
                'https://bit.ly/3PVE5IZ' => 1
            },
            'FuzzyMD5'     => 'B6E6F110F2EE80CDC083FDC496860210',
        }
    },
    {
        filename => 't/data/Encrypted2.pdf',
        expected => {
            'CreationDate' => 'D:20230102234612+00\'00\'',
            'PageCount' => 1,
            'Version' => '1.4',
            'ImageCount' => 1,
            'ImageDensity' => '61.43',
            'PageArea' => 143385,
            'Encrypted' => 1,
            'ImageArea' => 88077,
            'LinkCount' => 1,
            'Creator' => 'Pdfcrowd.com v20200619.084',
            'ModDate' => 'D:20230102234612+00\'00\'',
            'Producer' => 'Skia/PDF',
            'uris' => {
                'https://l.ead.me/bdbWna' => 1
            },
            'FuzzyMD5' => 'F5EBE02D8AD86A1C55C228ADB17D1787',
        }
    },
    {
        filename => 't/data/Encrypted3.pdf',
        expected => {
            'Producer' => "iText\xAE 5.5.13.3 \xA92000-2022 iText Group NV (AGPL-version)",
            'ImageArea' => 175000,
            'ImageDensity' => '34.93',
            'Encrypted' => 1,
            'LinkCount' => 1,
            'uris' => {
                'http://rot.come-over-here.site/?s1=ptt1' => 1
            },
            'CreationDate' => 'D:20230102151215+01\'00\'',
            'PageCount' => 1,
            'PageArea' => 500990,
            'Version' => '1.4',
            'ImageCount' => 1,
            'FuzzyMD5' => 'AC884B5E28A1E6CF784820C4BBF561F2',
            'ModDate' => 'D:20230102151215+01\'00\''
        }
    },
    {
        filename => 't/data/VectorText.pdf',
        expected => {
            'LinkCount' => 2,
            'Title' => '',
            'Encrypted' => 0,
            'PageArea' => 500990,
            'Version' => '1.4',
            'PageCount' => 1,
            'CreationDate' => 'D:20230121040738',
            'ImageCount' => 2,
            'ImageDensity' => '2.34',
            'uris' => {
                'mailto:support@itarian.com' => 1,
                'https://forum.itarian.com/' => 1
            },
            'FuzzyMD5' => '0BDF548E3805B31A05E85B3B71E0B017',
            'ImageArea' => 11700,
            'Creator' => '',
            'Producer' => 'Qt 5.5.1',
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
            'Author' => 'jjj',
            'LinkCount'    => 1,
            'uris' => {
                'https://s.id/1tzdg' => 1
            },
            'FuzzyMD5'     => '481E37EC16FF667D3512C20E7184DC0A',
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
            'LinkCount'    => 1,
            'uris' => {
                'http://gkjdepok.org/docdir/SCANS_PP2849.zip' => 1
            },
            'FuzzyMD5'     => 'F6483B538F996BF452681FBB5B153691',
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
            'ModDate' => 'D:20221221152022+00\'00\'',
            'LinkCount'    => 3,
            'uris' => {
                'https://sgef.collstreampay.co.uk/sgef/'             => 1,
                'http://www.equipmentfinance.societegenerale.co.uk/' => 1,
                'mailto:settlements@sgef.co.uk'                      => 1
            },
            'FuzzyMD5'     => '506CC279ED3A27A3F84992DD9CDF7DD0',
        }
    },
    {
        filename => 't/data/CamScanner.pdf',
        expected => {
            'Encrypted' => 0,
            'PageCount' => 1,
            'Producer' => 'intsig.com pdf producer',
            'Author' => 'CamScanner',
            'ImageDensity' => '92.06',
            'Subject' => 'CamScanner 01-02-2023 12.41',
            'PageArea' => 500990,
            'Title' => 'CamScanner 01-02-2023 12.41',
            'Version' => '1.7',
            'ImageCount' => 2,
            'ImageArea' => 461221,
            'Keywords' => '',
            'ModDate' => '',
            'LinkCount'    => 1,
            'uris' => {
                'https://digital-camscanner.onelink.me/P3GL/w1r4frhy' => 1
            },
            'FuzzyMD5'     => '13CF979A8E09F71E6DBD53931A58B444',
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
