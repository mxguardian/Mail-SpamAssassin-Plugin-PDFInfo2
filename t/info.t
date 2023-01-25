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
            'Protected'    => 0,
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
            'ImageRatio' => '2.95',
            'LinkCount'    => 0,
            'uris'         => {},
            'FuzzyMD5'     => '715E8FD2D08512EA74B7CCB18DE49F88',
            'ClickArea' => 0,
            'ClickRatio' => '0.00',
        }
    },
    {
        filename => 't/data/how_to_manage_club_members_en.pdf',
        expected   => {
            'Encrypted' => 0,
            'Protected'    => 0,
            'Version' => '1.5',
            'Producer' => 'Foxit PhantomPDF Printer Version 9.1.0.0531',
            'ImageCount' => 12,
            'PageCount' => 8,
            'ImageArea' => 296978,
            'Keywords' => '',
            'ModDate' => 'D:20200724162723-06\'00\'',
            'Creator' => '',
            'Author' => '',
            'ImageRatio' => '59.26',
            'Title' => '',
            'PageArea' => 501170,
            'Subject' => '',
            'CreationDate' => 'D:20200724162630-05\'00\'',
            'LinkCount'    => 0,
            'uris'         => {},
            'FuzzyMD5'     => '332ED68EE285723FCE457839231B2FEF',
            'ClickArea' => 0,
            'ClickRatio' => '0.00',
        }
    },
    {
        filename => 't/data/Encrypted.pdf',
        expected => {
            'Encrypted' => 1,
            'Protected'    => 0,
            'Version' => '1.4',
            'CreationDate' => 'D:20230106154216+03\'00\'',
            'Creator' => 'wkhtmltopdf 0.12.5',
            'PageCount' => 2,
            'PageArea' => 500990,
            'ImageCount' => 1,
            'ImageArea' => 337055,
            'Title' => '',
            'Producer' => 'Qt 4.8.7',
            'ImageRatio' => '67.28',
            'LinkCount'    => 1,
            'uris' => {
                'https://bit.ly/3PVE5IZ' => 1
            },
            'FuzzyMD5'     => 'B6E6F110F2EE80CDC083FDC496860210',
            'ClickArea' => 347292,
            'ClickRatio' => '69.32',
        }
    },
    {
        filename => 't/data/Encrypted2.pdf',
        expected => {
            'Protected'    => 0,
            'CreationDate' => 'D:20230102234612+00\'00\'',
            'PageCount' => 1,
            'Version' => '1.4',
            'ImageCount' => 1,
            'ImageRatio' => '61.43',
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
            'ClickRatio' => '61.82',
            'ClickArea' => 88642,
        }
    },
    {
        filename => 't/data/Encrypted3.pdf',
        expected => {
            'Protected'    => 0,
            'Producer' => "iText\xAE 5.5.13.3 \xA92000-2022 iText Group NV (AGPL-version)",
            'ImageArea' => 175000,
            'ImageRatio' => '34.93',
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
            'ModDate' => 'D:20230102151215+01\'00\'',
            'ClickRatio' => '35.00',
            'ClickArea' => 175357,
        }
    },
    {
        filename => 't/data/VectorText.pdf',
        expected => {
            'Protected'    => 0,
            'LinkCount' => 2,
            'Title' => '',
            'Encrypted' => 0,
            'PageArea' => 500990,
            'Version' => '1.4',
            'PageCount' => 1,
            'CreationDate' => 'D:20230121040738',
            'ImageCount' => 2,
            'ImageRatio' => '2.34',
            'uris' => {
                'mailto:support@itarian.com' => 1,
                'https://forum.itarian.com/' => 1
            },
            'FuzzyMD5' => '0BDF548E3805B31A05E85B3B71E0B017',
            'ImageArea' => 11700,
            'Creator' => '',
            'Producer' => 'Qt 5.5.1',
            'ClickArea' => 1476,
            'ClickRatio' => '0.29',
        }
    },
    {
        filename => 't/data/Phishing.pdf',
        expected => {
            'Protected'    => 0,
            'Encrypted' => 0,
            'Version' => '1.5',
            'ImageRatio' => '33.08',
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
            'ClickArea' => 166726,
            'ClickRatio' => '34.40',
        }
    },
    {
        filename => 't/data/Phishing2.pdf',
        expected => {
            'Protected'    => 0,
            'Encrypted'    => 0,
            'Version'      => '1.3',
            'ImageRatio' => '100.00',
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
            'ClickArea' => 501160,
            'ClickRatio' => '100.00',
        }
    },
    {
        filename => 't/data/ImageText.pdf',
        expected => {
            'Protected'    => 0,
            'Encrypted' => 0,
            'Version' => '1.7',
            'PageCount' => 1,
            'ImageRatio' => '18.47',
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
            'ClickArea' => 5792,
            'ClickRatio' => '1.16',
        }
    },
    {
        filename => 't/data/CamScanner.pdf',
        expected => {
            'Protected'    => 0,
            'Encrypted' => 0,
            'PageCount' => 1,
            'Producer' => 'intsig.com pdf producer',
            'Author' => 'CamScanner',
            'ImageRatio' => '92.06',
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
            'ClickRatio' => '0.97',
            'ClickArea' => 4835,
        }
    },
    {
        filename => 't/data/Paypal.pdf',
        expected => {
            'Protected'    => 0,
            'PageArea' => 484704,
            'CreationDate' => 'D:20221219182546+05\'30\'',
            'uris' => {},
            'LinkCount' => 0,
            'Version' => '1.7',
            'ImageRatio' => 100,
            'Author' => 'risha',
            'FuzzyMD5' => 'E98DBB88658A8B210BF5D862DD0DE36B',
            'ModDate' => 'D:20221219182546+05\'30\'',
            'ClickArea' => 0,
            'Title' => 'paypal',
            'ImageArea' => 484846,
            'ClickRatio' => '0.00',
            'ImageCount' => 1,
            'Encrypted' => 0,
            'PageCount' => 1,
            'Producer' => 'Microsoft: Print To PDF'
        }
    },
    {
        filename => 't/data/GeekSquad.pdf',
        expected => {
            'Protected'    => 0,
            'LinkCount' => 0,
            'ImageRatio' => '100.00',
            'ClickArea' => 0,
            'PageArea' => 491447,
            'ImageCount' => 1,
            'ClickRatio' => '0.00',
            'FuzzyMD5' => '187108336A1C58FAC57B1825C90B2FDB',
            'PageCount' => 1,
            'Version' => '1.7',
            'uris' => {},
            'Encrypted' => 0,
            'ImageArea' => 491447
        }
    },
    {
        filename => 't/data/Bitcoin.pdf',
        expected => {
            'Protected'    => 0,
            'Version' => '1.3',
            'LinkCount' => 1,
            'Title' => '',
            'Subject' => '',
            'ImageRatio' => '58.93',
            'ImageCount' => 1,
            'ClickRatio' => '59.02',
            'CreationDate' => 'D:20230120165641Z',
            'PageCount' => 7,
            'Creator' => 'Softplicity',
            'ImageArea' => 295218,
            'Producer' => 'Softplicity',
            'Author' => 'Softplicity',
            'Encrypted' => 0,
            'FuzzyMD5' => '72BD561D1B50B2850FEB4FB883D76E6F',
            'uris' => {
                'https://clck.ru/33KW7h' => 1
            },
            'Keywords' => '',
            'ModDate' => 'D:20230120165641+03\'00\'',
            'PageArea' => 500990,
            'ClickArea' => 295697
        }
    },
    {
        filename => 't/data/Password.pdf',
        expected => {
            'Version' => '1.6',
            'uris' => {},
            'Protected' => 1,
            'FuzzyMD5' => 'B04B5F350BCCF114F253147F71007C84',
            'ImageCount' => 0,
            'Encrypted' => 1,
            'PageCount' => 2,
            'ClickRatio' => '0.00',
            'ClickArea' => 0,
            'PageArea' => 530067,
            'ImageArea' => 0,
            'ImageRatio' => '0.00',
            'LinkCount' => 0
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
