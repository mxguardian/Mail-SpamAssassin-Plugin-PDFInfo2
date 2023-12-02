#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Test::More;
use Mail::SpamAssassin::PDF::Core;
use Data::Dumper;

my @tests = (
    {
        input  => 'obj',
        token  => 'obj',
        output => 1,
        pos    => 3,
    },{
        input => '  obj  ',
        token => 'obj',
        output => 1,
        pos    => 5,
    },{
        input => "\nobj\n",
        token => 'obj',
        output => 1,
        pos    => 4,
    },{
        input => "noobj",
        token => 'obj',
        output => undef,
        pos    => 0,
    },{
        input => "<</Columns 5/Predictor 12>>",
        token => '<<',
        output => 1,
        pos    => 2,
    }
);

plan tests => scalar @tests * 2;

foreach my $test (@tests) {
    my $input = $test->{input};
    my $output = $test->{output};
    my $token = $test->{token};
    open(my $fh, '<', \$input);
    my $core = Mail::SpamAssassin::PDF::Core->new($fh);
    my $result = eval { $core->assert_token($token); 1;};
    is($result, $output, "assert_token($input)");
    is($core->pos, $test->{pos}, "pos($input) = ".$core->pos);
}
