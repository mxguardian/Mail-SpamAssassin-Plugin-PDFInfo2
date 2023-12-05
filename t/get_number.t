#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Test::More;
use Mail::SpamAssassin::PDF::Core;
use Data::Dumper;


my @tests = (
    {
        input  => '248 0 obj',
        output => 248,
        pos    => 4,
    },{
        input  => '5/Pages 2 0 R',
        output => 5,
        pos    => 1,
    },{
        input  => '0000010',
        output => 10,
        pos    => 7,
    },{
        input  => '-5.0>>',
        output => -5,
        pos    => 4,
    },{
        input  => '.0625]',
        output => 0.0625,
        pos    => 5,
    }
);

plan tests => scalar @tests * 2;

foreach my $test (@tests) {
    my $input = $test->{input};
    my $output = $test->{output};
    open(my $fh, '<', \$input);
    my $core = Mail::SpamAssassin::PDF::Core->new($fh);
    my $result = $core->get_number();
    is($result, $output, "parse_object_number($input) == $output");
    is($core->pos, $test->{pos}, "pos == $test->{pos}");
}
