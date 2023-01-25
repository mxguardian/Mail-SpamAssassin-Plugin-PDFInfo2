#!/usr/bin/perl
use lib './lib';
use strict;
use warnings FATAL => 'all';
use Mail::SpamAssassin::PDF::Parser;
use Mail::SpamAssassin::PDF::Context::Image;
use Data::Dumper;
use Getopt::Std;
use Pod::Usage;

=head1 SYNOPSIS

 images.pl <PDF_FILE>

 Creates a representational image for each page of a PDF.

 See Mail::SpamAssassin::PDF::Context::Image for more details

=cut

my %opts;
getopts('g:o:s:',\%opts);

my ($file) = @ARGV;
pod2usage() unless defined $file;

open my $fh, '<', $file or die;
local $/ = undef;
my $data = <$fh>;
close $fh;

my $context = Mail::SpamAssassin::PDF::Context::Image->new();

my $pdf = Mail::SpamAssassin::PDF::Parser->new(
    context         => $context
);

$pdf->parse($data);
