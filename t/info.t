use strict;
use warnings;
use lib 'lib';
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
            'MD5Fuzzy1'     => '6C574387FBEBF413086ACEC582DD21C0',
            'MD5Fuzzy2'     => 'F46774C7543A737E0E9C84749FE5C128',
            'MD5'           => '246273E865CEC832E2AE2FCFCC200F8B',
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
            'MD5Fuzzy1'     => '720C12D06C451220E0795D983871B69B',
            'MD5Fuzzy2'     => '0A10656AC74511C092E1477FE64624CE',
            'MD5'           => 'A38AC5E2012AF7F93024567250BE0AE9',
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
            'MD5Fuzzy1'     => '091360FF25D11402732D3AE73CD69ABE',
            'MD5Fuzzy2'     => '6DCFC7D7D7F32600919ECC3D4E9989E5',
            'MD5'           => '1D91627518DAA81A72A451056F8F653A',
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
            'MD5Fuzzy1' => 'E6CA65D24C5295FABCC8BEF26B47EF8A',
            'MD5Fuzzy2' => '6710236FFB511D3C75515BCCB896ADE9',
            'MD5'           => 'B88C417A783E1EFEFC27D3B8065746EA',
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
            'MD5Fuzzy1' => '19B7F3D135D40CC85A67D33A03D855D5',
            'MD5Fuzzy2' => 'C871FBB29516689D31F03680E4299EE0',
            'MD5'           => '5DEEC7325AD7F1147280B675F0F2ECC1',
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
            'MD5Fuzzy1'     => '603B294359431A37B28B9EF4687F4900',
            'MD5Fuzzy2'     => '2FFA6EBAED03DC2C23C4FD83302DBD86',
            'MD5'           => 'B5DEE9C79BAC4B2990A54FF8C31E8FCD',
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
            'MD5Fuzzy1'     => '7310A63712E9625A3BB1712DB50EC216',
            'MD5Fuzzy2'     => 'C59AADD4F84BC710538E6A1AA101C82E',
            'MD5'           => 'DC4851593138C810BA5FD93C47523D51',
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
            'MD5Fuzzy1'     => '242287E687D1BFFEDE87F2F01B924EE6',
            'MD5Fuzzy2'     => '8A0525EFDA72CE0958A6CED96068E914',
            'MD5'           => 'FF705E05533CF8C98D1623D213FCB4FE',
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
            'MD5Fuzzy1'     => '19EC5441E49CCB19A274D0F6D7DA6917',
            'MD5Fuzzy2'     => '4D68DC0B165E61FA6130DB0E9E0B397B',
            'MD5'           => 'A206B0ACDE4E212E8A1F699A9E87DD36',
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
            'MD5Fuzzy1' => '76830C9B6314529F523BFDE4D1D02B62',
            'MD5Fuzzy2' => '7F0918AFB5B2468A6A1D0B24277AEB1D',
            'MD5'           => 'B3BF38C48788A8AA6E4F37190852F40E',
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
            'MD5Fuzzy1' => '331F5750A86F5D2D4CD545C95B2023BC',
            'MD5Fuzzy2' => 'AB11DA814FE4B937E6029C1B92F8701B',
            'MD5'           => '9BFC3C4764E15629859C991C262529FA',
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
            'MD5Fuzzy1' => '15E413D1ED4D805A5D555BAE65E9397B',
            'MD5Fuzzy2' => 'E09E2EFE49E304C821107B13FC23B9BD',
            'MD5'           => '67A83A54661B5714A7D5D7EA1DAFD0FF',
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
        filename => 't/spam/Bitcoin2.pdf',
        expected => {
            'Author' => 'Watson',
            'ClickArea' => 419832,
            'ClickRatio' => '82.62',
            'ColorImageCount' => 1,
            'CreationDate' => 'D:20200425064028+03\'00\'',
            'Creator' => 'Telerik Reporting 5.9.3',
            'Encrypted' => 0,
            'ImageArea' => 397747,
            'ImageCount' => 1,
            'ImageRatio' => '78.27',
            'LinkCount' => 14,
            'MD5' => '4D2FD875F85BA63F368AEE434A715630',
            'MD5Fuzzy1' => 'F666E47F4FC721746FE85A9F779DF888',
            'MD5Fuzzy2' => '2761D2E9FE9FC358238D8D0071223FFF',
            'PageArea' => 508176,
            'PageCount' => 4,
            'Producer' => 'LibreOffice 8.13',
            'Protected' => 0,
            'Subject' => 'angry',
            'Title' => 'five',
            'Version' => '1.4',
            'uris' => {
                'https://app.rarible.com/#5exzrm8f8fpuq90j6lp6v' => 1,
                'https://avellinotoday.it/#dgv3is797sr1t48tr101' => 1,
                'https://dpmms.cam.ac.uk/#honqzkb' => 1,
                'https://esrc.ac.uk/#c8rdoiml' => 1,
                'https://grelsin.blogspot.com/#qudjig0jnlqwc9fxyf' => 1,
                'https://livius.org/#cddx' => 1,
                'https://nikytap.de/04yb/#81zo' => 1
            }
        }
    },
    {
        filename => 't/ham/Password.pdf',
        expected => {
            'Version' => '1.6',
            'uris' => {},
            'Protected' => 1,
            'MD5Fuzzy1' => '3711EEFE2D9276D4A2FB9F648BD37C8C',
            'MD5Fuzzy2' => '7F24742E76DEB241E26987C1D100268C',
            'MD5'           => '30694E15C217049D641BA7E2FAE57BD6',
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
            'MD5Fuzzy1' => '02CCECD8D1DF9554023A5F950A20B4BD',
            'MD5Fuzzy2' => '0C17A51E93C2589D176AD8D555AA27C9',
            'MD5'           => 'ECC774C73DBB4A3D629BCD83893BF105',
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
            'MD5'           => '2EA71DA1458593ED757FE436D6A28C86',
            'ImageCount'      => 6,
            'MD5Fuzzy1'       => '75FEC79AD186BCE71D81CF7E3601E67E',
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
    {
        filename => 't/ham/BlankID.pdf',
        expected => {
            'MD5' => '9C9EF3C30ACBD137B23E4FC3C053CD38',
            'LinkCount' => 0,
            'Version' => '1.7',
            'ColorImageCount' => 1,
            'CreationDate' => '1/25/2023 04:39:15',
            'Author' => 'Registered to: FNB     ',
            'ImageCount' => 1,
            'ClickArea' => 0,
            'uris' => {},
            'ImageRatio' => '3.17',
            'MD5Fuzzy2' => '878E5C71CCD65354FA9CCB99D17D76C3',
            'Creator' => 'OpenText Exstream Version 16.6.40 64-bit',
            'PageCount' => 8,
            'ClickRatio' => '0.00',
            'ImageArea' => 15906,
            'MD5Fuzzy1' => 'B48305D4D17932D40BD707B7F56AB030',
            'Encrypted' => 1,
            'Protected' => 0,
            'PageArea' => 500990,
            'Title' => 'TDPP'
        }
    },
    {
        filename => 't/ham/ASCII85Decode.pdf',
        expected => {
            'ColorImageCount' => 0,
            'PageCount' => 1,
            'ImageCount' => 0,
            'ClickArea' => 0,
            'ClickRatio' => '0.00',
            'Encrypted' => 0,
            'Type' => '/Info',
            'ImageRatio' => '0.00',
            'uris' => {},
            'ImageArea' => 0,
            'MD5' => 'A0E0342DCBF55A374DE9AA1CC30CBC7E',
            'LinkCount' => 0,
            'PageArea' => 484704,
            'MD5Fuzzy1' => '4337A69A949DC137A9DD31E0C998C63E',
            'Producer' => 'FOP 0.20.4',
            'MD5Fuzzy2' => '3BF2940A3D61EE262C15DBE4C5966541',
            'Protected' => 0,
            'Version' => '1.4'
        }
    },
    {
        filename => 't/ham/Covid19NoticeFNF.pdf',
        expected => {
            'MD5' => '2B8E71DA6F1315444EB77C812796C200',
            'PageCount' => 2,
            'Creator' => 'Adobe InDesign 17.0 (Windows)',
            'ClickRatio' => '0.00',
            'ImageArea' => 88938,
            'CreationDate' => 'D:20220407151732-04\'00\'',
            'ModDate' => 'D:20220408074935-07\'00\'',
            'ClickArea' => 0,
            'ImageRatio' => '18.35',
            'uris' => {},
            'Trapped' => '/False',
            'Version' => '1.6',
            'ColorImageCount' => 1,
            'MD5Fuzzy1' => '977E590076127533A5233D4CBDC3AFF7',
            'Producer' => 'Adobe PDF Library 16.0.3',
            'Encrypted' => 0,
            'ImageCount' => 1,
            'LinkCount' => 0,
            'PageArea' => 484704,
            'MD5Fuzzy2' => 'C506E8DFDD529A6619E5DB8A414F5DE4',
            'Protected' => 0
        }
    },
    {
        filename => 't/ham/IndirectMediaBox.pdf',
        expected => {
            'PageArea' => 484704,
            'Creator' => 'Crystal Reports',
            'ImageArea' => 8318,
            'Encrypted' => 0,
            'ImageRatio' => '1.72',
            'Producer' => 'Powered By Crystal',
            'MD5' => '80AC7DF3D0EEAA04768DFCF5F082FE87',
            'ImageCount' => 1,
            'uris' => {},
            'LinkCount' => 0,
            'MD5Fuzzy2' => '164E71F0CF84EECE07183BC4F638CC01',
            'Protected' => 0,
            'Version' => '1.7',
            'ClickRatio' => '0.00',
            'ColorImageCount' => 1,
            'ClickArea' => 0,
            'MD5Fuzzy1' => '7A041928149DAAFCC1E460345B44A445',
            'PageCount' => 1
        }
    },
    {
        filename => 't/spam/InlineImages.pdf',
        expected => {
            'PageCount' => 1,
            'ClickRatio' => '0.00',
            'ClickArea' => 0,
            'ColorImageCount' => 14,
            'Creator' => 'PScript5.dll Version 5.2.2',
            'Producer' => 'GPL Ghostscript 8.64',
            'uris' => {},
            'Author' => 'user',
            'ImageCount' => 14,
            'MD5Fuzzy1' => '7BD1974A738ADE21492D192ACCA317C5',
            'Protected' => 0,
            'CreationDate' => 'D:20221228084556+02\'00\'',
            'Encrypted' => 0,
            'LinkCount' => 0,
            'ImageRatio' => '86.02',
            'Version' => '1.3',
            'Title' => 'Microsoft Word - Euro-Million Lottery.doc',
            'ImageArea' => 416927,
            'ModDate' => 'D:20221228084556+02\'00\'',
            'MD5Fuzzy2' => '5F87E80B7B0CBFEB9CFB6DB9554EFB44',
            'MD5' => '67235006AE5E672C1EB4660ACB532041',
            'PageArea' => 484704
        }
    },
);

plan tests => scalar(@tests);

for my $test (@tests) {
    my $context = Mail::SpamAssassin::PDF::Context::Info->new();
    my $pdf = Mail::SpamAssassin::PDF::Parser->new(
        context => $context
    );

    my $data = get_file_contents($test->{filename});
    $pdf->parse(\$data);
    is_deeply $context->get_info(), $test->{expected}, $test->{filename};

}


sub get_file_contents {
    my $file = shift;
    open my $fh, '<', $file or die "Can't open $file: $!";
    local $/ = undef;
    my $data = <$fh>;
    close $fh;
    return $data;
}
