#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use lib 'lib';
use Mail::SpamAssassin::PDF::Core;

# autoflush
$| = 1;

my $file = $ARGV[0];
open(my $fh, '<', $file) or die "Could not open file '$file' $!";

# my $data = do { local $/; <$fh> };
# close($fh);
# open($fh, '<', \$data);

my $core = Mail::SpamAssassin::PDF::Core->new($fh);

my $count=0;
my $start = time();
while () {
    $count++;
    # if ( $count % 256 == 0 ) {
    #     my $elapsed = time() - $start;
    #     my $rate = $elapsed ? $count / $elapsed : 0;
    #     printf STDERR "\r%d %.2f/s", $count, $rate;
    # }
    my ($token, $type) = $core->get_primitive();
    last unless defined($token);
    $token = Dumper($token) if ref($token);
    printf(">> %7s: %s\n",$type,$token);
}

# my $elapsed = time() - $start;
# my $rate = $elapsed ? $count / $elapsed : 0;
# printf STDERR "\r%d %.2f/s", $count, $rate;

