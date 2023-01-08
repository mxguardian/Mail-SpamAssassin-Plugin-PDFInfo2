use strict;
use warnings;
use Test::More;
use PDF::Info qw(parse_file);

my @tests = (
    {
        file     => 't/data/12.pdf',
        expected => {
            md5     => '06CA50B57CF466F4FAA5DE1707A86BEA',
            fuzzy   => '50DFD785B3213BDE5BD4EDE8A6A44858',
            links   => 0,
            uris    => {},
            pages   => 1,
            words   => 0,
            images  => 4
        }
    },
    {
        file     => 't/data/22.pdf',
        expected => {
            md5     => '9BFC3C4764E15629859C991C262529FA',
            fuzzy   => 'D04DAF28C51B3B24072061B447CCF4B5',
            links   => 0,
            uris    => {},
            pages   => 1,
            words   => 0,
            images  => 1
        }
    },
    {
        file     => 't/data/Doc2 (1).pdf',
        expected => {
            md5     => 'B5DEE9C79BAC4B2990A54FF8C31E8FCD',
            fuzzy   => 'D8C354008226937192D16694C628A661',
            links   => 1,
            uris    => {
                'https://s.id/1tzdg' => 1,
            },
            pages   => 1,
            words   => 0,
            images  => 1
        }
    },
    {
        file     => 't/data/Profile_with_photo_and_videos_from_Gianna-4267fZmSNyvIvbc.pdf',
        expected => {
            md5     => '',
            fuzzy   => '5C254325B77DBFA463CA975AAD79DD2D',
            links   => 1,
            uris    => {
                'https://bit.ly/3PVE5IZ' => 1,
            },
            pages   => 2,
            words   => 0,
            images  => 1
        }
    },
);

plan tests => scalar(@tests);

foreach my $test (@tests) {
    is_deeply parse_file($test->{file}), $test->{expected}, $test->{file};
}
