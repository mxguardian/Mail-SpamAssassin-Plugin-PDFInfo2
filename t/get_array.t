#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Test::More;
use Mail::SpamAssassin::PDF::Core;
use Data::Dumper;


my @tests = (
    {
        input  => '[/PDF/Text/ImageB/ImageC/ImageI]/Font<<',
        output => [
            '/PDF',
            '/Text',
            '/ImageB',
            '/ImageC',
            '/ImageI'
        ],
    },{
        input  => '[]',
        output => [],
    }
);

plan tests => scalar @tests;

foreach my $test (@tests) {
    my $input = $test->{input};
    my $output = $test->{output};
    open(my $fh, '<', \$input);
    my $core = Mail::SpamAssassin::PDF::Core->new($fh);
    my $result = $core->get_array();
    is_deeply($result, $output, Dumper($result));
}
