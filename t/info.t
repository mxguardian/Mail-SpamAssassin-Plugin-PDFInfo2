use strict;
use warnings;
use Test::More;
use Mail::SpamAssassin::PDF::Parser;
use Mail::SpamAssassin::PDF::Context::Info;
use Data::Dumper;

my @tests = (
    {
        filename => 't/ham/North Gaston HS flyer.pdf',
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
            'ColorImageCount'   => 2,
            'Title'        => '',
            'ImageRatio' => '2.95',
            'LinkCount'    => 0,
            'uris'         => {},
            'MD5Fuzzy1'     => 'BDA32D707C66A329F1B37BDC238C0DE2',
            'MD5Fuzzy2'     => 'F46774C7543A737E0E9C84749FE5C128',
            'ClickArea' => 0,
            'ClickRatio' => '0.00',
        }
    },
    {
        filename => 't/ham/how_to_manage_club_members_en.pdf',
        expected   => {
            'Encrypted' => 0,
            'Protected'    => 0,
            'Version' => '1.5',
            'Producer' => 'Foxit PhantomPDF Printer Version 9.1.0.0531',
            'ImageCount' => 12,
            'ColorImageCount' => 12,
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
            'MD5Fuzzy1'     => '332ED68EE285723FCE457839231B2FEF',
            'MD5Fuzzy2'     => '018D84F8D04C075D5D65D33BA9B554D7',
            'ClickArea' => 0,
            'ClickRatio' => '0.00',
        }
    },
    {
        filename => 't/spam/Encrypted.pdf',
        expected => {
            'Encrypted' => 1,
            'Protected'    => 0,
            'Version' => '1.4',
            'CreationDate' => 'D:20230106154216+03\'00\'',
            'Creator' => 'wkhtmltopdf 0.12.5',
            'PageCount' => 2,
            'PageArea' => 500990,
            'ImageCount' => 1,
            'ColorImageCount' => 1,
            'ImageArea' => 337055,
            'Title' => '',
            'Producer' => 'Qt 4.8.7',
            'ImageRatio' => '67.28',
            'LinkCount'    => 1,
            'uris' => {
                'https://bit.ly/3PVE5IZ' => 1
            },
            'MD5Fuzzy1'     => 'B6E6F110F2EE80CDC083FDC496860210',
            'MD5Fuzzy2'     => '16B2275186DAF8F7C815C9990F35AA02',
            'ClickArea' => 347292,
            'ClickRatio' => '69.32',
        }
    },
    {
        filename => 't/spam/Encrypted2.pdf',
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
            'ColorImageCount' => 1,
            'MD5Fuzzy1' => 'AC884B5E28A1E6CF784820C4BBF561F2',
            'MD5Fuzzy2' => '6710236FFB511D3C75515BCCB896ADE9',
            'ModDate' => 'D:20230102151215+01\'00\'',
            'ClickRatio' => '35.00',
            'ClickArea' => 175357,
        }
    },
    {
        filename => 't/ham/VectorText.pdf',
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
            'ColorImageCount' => 2,
            'ImageRatio' => '2.34',
            'uris' => {
                'mailto:support@itarian.com' => 1,
                'https://forum.itarian.com/' => 1
            },
            'MD5Fuzzy1' => '0BDF548E3805B31A05E85B3B71E0B017',
            'MD5Fuzzy2' => 'E760C82A449E199AADADDCCDF587DBC4',
            'ImageArea' => 11700,
            'Creator' => '',
            'Producer' => 'Qt 5.5.1',
            'ClickArea' => 1476,
            'ClickRatio' => '0.29',
        }
    },
    {
        filename => 't/spam/Phishing.pdf',
        expected => {
            'Protected'    => 0,
            'Encrypted' => 0,
            'Version' => '1.5',
            'ImageRatio' => '33.08',
            'ModDate' => 'D:20221206220444-08\'00\'',
            'ImageCount' => 1,
            'ColorImageCount' => 1,
            'ImageArea' => 160359,
            'PageArea' => 484704,
            'CreationDate' => 'D:20221206220444-08\'00\'',
            'PageCount' => 1,
            'Author' => 'jjj',
            'LinkCount'    => 1,
            'uris' => {
                'https://s.id/1tzdg' => 1
            },
            'MD5Fuzzy1'     => '481E37EC16FF667D3512C20E7184DC0A',
            'MD5Fuzzy2'     => 'E44DD6F91A3112162A5B2781CD90FF6D',
            'ClickArea' => 166726,
            'ClickRatio' => '34.40',
        }
    },
    {
        filename => 't/spam/Phishing2.pdf',
        expected => {
            'Protected'    => 0,
            'Encrypted'    => 0,
            'Version'      => '1.3',
            'ImageRatio' => '100.00',
            'ImageCount'   => 1,
            'ColorImageCount'   => 1,
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
            'MD5Fuzzy1'     => 'F6483B538F996BF452681FBB5B153691',
            'MD5Fuzzy2'     => 'D5B616162FDD93043F006EABFF6CEC0C',
            'ClickArea' => 501160,
            'ClickRatio' => '100.00',
        }
    },
    {
        filename => 't/ham/ImageText.pdf',
        expected => {
            'Protected'    => 0,
            'Encrypted' => 0,
            'Version' => '1.7',
            'PageCount' => 1,
            'ImageRatio' => '18.47',
            'Author' => 'Tom Orkney',
            'CreationDate' => 'D:20221221152022+00\'00\'',
            'ImageCount' => 111,
            'ColorImageCount' => 2,
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
            'MD5Fuzzy1'     => '506CC279ED3A27A3F84992DD9CDF7DD0',
            'MD5Fuzzy2'     => '365239E089D8EA8D4E3363FE997B89DD',
            'ClickArea' => 5792,
            'ClickRatio' => '1.16',
        }
    },
    {
        filename => 't/ham/CamScanner.pdf',
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
            'ColorImageCount' => 2,
            'ImageArea' => 461221,
            'Keywords' => '',
            'ModDate' => '',
            'LinkCount'    => 1,
            'uris' => {
                'https://digital-camscanner.onelink.me/P3GL/w1r4frhy' => 1
            },
            'MD5Fuzzy1'     => '13CF979A8E09F71E6DBD53931A58B444',
            'MD5Fuzzy2'     => '7FD24F84B2099FEFE94D8A2075DF0AD1',
            'ClickRatio' => '0.97',
            'ClickArea' => 4835,
        }
    },
    {
        filename => 't/spam/Paypal.pdf',
        expected => {
            'Protected'    => 0,
            'PageArea' => 484704,
            'CreationDate' => 'D:20221219182546+05\'30\'',
            'uris' => {},
            'LinkCount' => 0,
            'Version' => '1.7',
            'ImageRatio' => 100,
            'Author' => 'risha',
            'MD5Fuzzy1' => 'E98DBB88658A8B210BF5D862DD0DE36B',
            'MD5Fuzzy2' => '7F0918AFB5B2468A6A1D0B24277AEB1D',
            'ModDate' => 'D:20221219182546+05\'30\'',
            'ClickArea' => 0,
            'Title' => 'paypal',
            'ImageArea' => 484846,
            'ClickRatio' => '0.00',
            'ImageCount' => 1,
            'ColorImageCount' => 1,
            'Encrypted' => 0,
            'PageCount' => 1,
            'Producer' => 'Microsoft: Print To PDF'
        }
    },
    {
        filename => 't/spam/GeekSquad.pdf',
        expected => {
            'Protected'    => 0,
            'LinkCount' => 0,
            'ImageRatio' => '100.00',
            'ClickArea' => 0,
            'PageArea' => 491447,
            'ImageCount' => 1,
            'ColorImageCount' => 1,
            'ClickRatio' => '0.00',
            'MD5Fuzzy1' => '187108336A1C58FAC57B1825C90B2FDB',
            'MD5Fuzzy2' => 'BEF020293FA706764379B50430C21BD2',
            'PageCount' => 1,
            'Version' => '1.7',
            'uris' => {},
            'Encrypted' => 0,
            'ImageArea' => 491447
        }
    },
    {
        filename => 't/spam/Bitcoin.pdf',
        expected => {
            'Protected'    => 0,
            'Version' => '1.3',
            'LinkCount' => 1,
            'Title' => '',
            'Subject' => '',
            'ImageRatio' => '58.93',
            'ImageCount' => 1,
            'ColorImageCount' => 1,
            'ClickRatio' => '59.02',
            'CreationDate' => 'D:20230120165641Z',
            'PageCount' => 7,
            'Creator' => 'Softplicity',
            'ImageArea' => 295218,
            'Producer' => 'Softplicity',
            'Author' => 'Softplicity',
            'Encrypted' => 0,
            'MD5Fuzzy1' => '72BD561D1B50B2850FEB4FB883D76E6F',
            'MD5Fuzzy2' => '410087A0E28A3963ED7E810700376416',
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
        filename => 't/ham/Password.pdf',
        expected => {
            'Version' => '1.6',
            'uris' => {},
            'Protected' => 1,
            'MD5Fuzzy1' => 'B04B5F350BCCF114F253147F71007C84',
            'MD5Fuzzy2' => '7F24742E76DEB241E26987C1D100268C',
            'ImageCount' => 0,
            'ColorImageCount' => 0,
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
    {
        filename => 't/ham/Fax.pdf',
        expected => {
            'CreationDate' => 'D:20230122031715',
            'ClickRatio' => '0.00',
            'MD5Fuzzy1' => '73384CF7BA37649DA549F8947AAF4E50',
            'MD5Fuzzy2' => '94BC3C8D574B716A31980CE0D2C658E7',
            'ImageCount' => 1,
            'PageArea' => 473169,
            'Encrypted' => 0,
            'ImageRatio' => '100.00',
            'ClickArea' => 0,
            'ModDate' => 'D:20230122031715',
            'LinkCount' => 0,
            'Protected' => 0,
            'PageCount' => 1,
            'uris' => {},
            'Producer' => 'ImageMagick 6.7.8-9 2014-06-10 Q16 http://www.imagemagick.org',
            'Version' => '1.3',
            'ColorImageCount' => 0,
            'ImageArea' => 473169        }
    },
    {
        filename => 't/ham/Form.pdf',
        expected => {
            'PageArea'        => 501157,
            'ClickArea'       => 0,
            'CreationDate'    => 'D:20220929143131+03\'00\'',
            'Encrypted'       => 0,
            'Producer'        => 'Adobe PDF Library 16.0.7',
            'LinkCount'       => 0,
            'ClickRatio'      => '0.00',
            'ModDate'         => 'D:20220929143132+03\'00\'',
            'MD5Fuzzy2'       => 'A5082B56AE4451A7781239AE1C2582AF',
            'ImageCount'      => 6,
            'MD5Fuzzy1'       => '6CF53975E44B6DC6FE4D44CFFC781FE9',
            'ImageRatio'      => '22.47',
            'Version'         => '1.4',
            'ColorImageCount' => 6,
            'PageCount'       => 1,
            'Creator'         => 'Adobe InDesign 17.3 (Macintosh)',
            'ImageArea'       => 112586,
            'Trapped'         => '/False',
            'Protected'       => 0,
            'uris'            => {}
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
