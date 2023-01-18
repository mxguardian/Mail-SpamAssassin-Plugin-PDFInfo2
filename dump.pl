#!/usr/bin/perl
use lib './lib';
use strict;
use warnings FATAL => 'all';
use PDF::Parser;
use PDF::Context::Info;
use Data::Dumper;
use Getopt::Std;
use Pod::Usage;

my %opts;
getopts('g:o:s:t',\%opts);

my ($file) = @ARGV;
pod2usage() unless defined $file;

open my $fh, '<', $file or die;
local $/ = undef;
my $data = <$fh>;
close $fh;

my $context = PDF::Context::Info->new();

my $pdf = PDF::Parser->new(
    context         => $context
);

$pdf->parse($data);

if ( defined $opts{o} ) {
    my $ref = $opts{o};
    $ref = "$ref 0 R";
    print Dumper($pdf->_get_obj($ref));
}

if ( defined $opts{s} ) {
    my $ref = $opts{s};
    $ref = "$ref 0 R";
    print Dumper($pdf->_get_stream_data($ref));
}

if ( defined $opts{t} ) {
    print Dumper($pdf->{trailer});
}

if ( defined $opts{g} ) {
    for my $ref (keys %{ $pdf->{xref} }) {
        my $obj = $pdf->_get_obj($ref);
        my $str = Dumper($obj);
        print "$ref\n$str\n" if $str =~ qr/$opts{g}/;
    }
}

