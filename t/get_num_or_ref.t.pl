#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Test::More;
use Mail::SpamAssassin::PDF::Core;
use Data::Dumper;


my @tests = (
    {
        input  => '0 15 R',
        output => '0 15 R',
        pos    => 6,
    },{
        input => '6.24 6.24 re',
        output => '6.24',
        pos    => 5,
    },{
        input => '159 0 R/Size',
        output => '159 0 R',
        pos    => 7,
    },{
        input => '2 15 R<</Type /Page>>',
        output => '2 15 R',
        pos    => 6,
    },{
        input => '230 0 R>>>>/Rotate 0',
        output => '230 0 R',
        pos    => 7,
    },{
        input  => '5/Predictor 12>>',
        output => '5',
        pos    => 1,
    },{
        input  => '5 4/Predictor 12>>',
        output => '5',
        pos    => 1,
    },{
        input => '2 15 RRR',
        output => '2',
        pos    => 1,
    },{
        input => '0 0 cm',
        output => '0',
        pos    => 1,
    },{
        input => '18.5 588.2445 cm',
        output => '18.5',
        pos    => 5,
    },{
        input => "0 -374.966 l\nS",
        output => '0',
        pos    => 2,
    },{
        input => "-295.604 404.6 m",
        output => '-295.604',
        pos    => 9,
    },{
        input => "18 583.95 301.5 22.65 re",
        output => '18',
        pos    => 3,
    },{
        input => "2.3 4.5 R 18 583.95 301.5 22.65 re",
        output => '2.3',
        pos    => 4,
    }
);

plan tests => scalar @tests * 2;

foreach my $test (@tests) {
    my $input = $test->{input};
    my $output = $test->{output};
    open(my $fh, '<', \$input);
    my $ch = getc($fh);
    my $core = Mail::SpamAssassin::PDF::Core->new($fh);
    my $result = $core->_get_num_or_ref($ch);
    is($result, $output, "_get_num_or_ref($input) == $output");
    is($core->pos, $test->{pos}, "_get_num_or_ref($input)->pos == $test->{pos}");
    close($fh);
}
