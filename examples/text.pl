#!/usr/bin/perl
use lib './lib';
use strict;
use warnings FATAL => 'all';
use Mail::SpamAssassin::PDF::Parser;
use Mail::SpamAssassin::PDF::Context::Text;
use Data::Dumper;
use Getopt::Std;
use Pod::Usage;

=head1 SYNOPSIS

 text.pl <PDF_FILE>

 Dumps text from a PDF file

=cut

my %opts;
getopts('g:o:s:',\%opts);

my ($file) = @ARGV;
pod2usage() unless defined $file;

binmode STDOUT, ":utf8";

open my $fh, '<', $file or die;
local $/ = undef;
my $data = <$fh>;
close $fh;

my $context = Mail::SpamAssassin::PDF::Context::Text->new();

my $pdf = Mail::SpamAssassin::PDF::Parser->new(
    context         => $context
);

$pdf->parse($data);

print $context->{text},"\n";
