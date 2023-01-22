#!/usr/bin/perl
use lib './lib';
use strict;
use warnings FATAL => 'all';
use Mail::SpamAssassin::PDF::Parser;
use Mail::SpamAssassin::PDF::Context::Info;
use Data::Dumper;
use Getopt::Std;
use Pod::Usage;

=head1 SYNOPSIS

 dump.pl <PDF_FILE>

 Options
   -o   <OBJECT_NUMBER>     Dump object dictionary
   -s   <OBJECT_NUMBER>     Dump object stream
   -g   <PATTERN>           Dump all objects containing <PATTERN>
   -f                       Dump fuzzy checksum

 If called without any options, dumps the trailer dictionary

=cut

my %opts;
getopts('Ffg:o:s:',\%opts);

my ($file) = @ARGV;
pod2usage() unless defined $file;

open my $fh, '<', $file or die "Error opening $file: $!";
local $/ = undef;
my $data = <$fh>;
close $fh;

my $context = Mail::SpamAssassin::PDF::Context::Info->new();

my $pdf = Mail::SpamAssassin::PDF::Parser->new(
    context         => $context
);

$pdf->parse($data);

if ( defined $opts{o} ) {
    my $ref = $opts{o};
    $ref = "$ref 0 R";
    print Dumper($pdf->_get_obj($ref));
} elsif ( defined $opts{s} ) {
    my $ref = $opts{s};
    $ref = "$ref 0 R";
    print Dumper($pdf->_get_stream_data($ref));
} elsif ( defined $opts{g} ) {
    for my $ref (keys %{ $pdf->{xref} }) {
        my $obj = $pdf->_get_obj($ref);
        my $str = Dumper($obj);
        print "$ref\n$str\n" if $str =~ qr/$opts{g}/;
    }
} elsif ( defined($opts{f}) ) {
    my $info = $context->get_info();
    print $info->{FuzzyMD5}," $file\n";
} elsif ( defined($opts{F}) ) {
    my $info = $context->get_info();
    print $info->{FuzzyMD5Data},"\n";
} else  {
    print Dumper($pdf->{trailer});
}

