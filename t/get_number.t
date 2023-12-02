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
    },{
        input  => '0000010',
        output => 10,
    },{
        input  => '-5.0',
        output => -5,
    },{
        input  => '.0625',
        output => 0.0625,
    }
);

plan tests => scalar @tests;

foreach my $test (@tests) {
    my $input = $test->{input};
    my $output = $test->{output};
    open(my $fh, '<', \$input);
    my $core = Mail::SpamAssassin::PDF::Core->new($fh);
    my $result = $core->get_number();
    is($result, $output, "parse_object_number($input) == $output");
}
