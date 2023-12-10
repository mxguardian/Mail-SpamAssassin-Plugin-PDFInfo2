#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Test::More;
use Mail::SpamAssassin::PDF::Core;
use Data::Dumper;

my @tests = (
    {
        input  => '<feff0066006900760065>',
        output => 'five',
    },{
        input  => '(P.O.\222s and check request forms accepted)',
        output => "P.O.\x{92}s and check request forms accepted",
    },{
        input  => '(or \(2 inches tall x 5.25 inches wide\))',
        output => 'or (2 inches tall x 5.25 inches wide)',
    },{
        input  => '(Please fax completed form to (407) 555-0111)',
        output => 'Please fax completed form to (407) 555-0111',
    },{
        input  => '()',
        output => '',
    }
 );

plan tests => scalar @tests;

foreach my $test (@tests) {
    my $input = $test->{input};
    my $output = $test->{output};
    open(my $fh, '<', \$input);
    my $core = Mail::SpamAssassin::PDF::Core->new($fh);
    my $result = $core->get_primitive();
    is_deeply($result, $output, $input);
}
