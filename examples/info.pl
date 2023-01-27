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

 info.pl <PDF_FILE>

 Dumps info about a PDF file

=cut

my %opts;
getopts('g:o:s:',\%opts);

my ($file) = @ARGV;
pod2usage() unless defined $file;

open my $fh, '<', $file or die "$!";
local $/ = undef;
my $data = <$fh>;
close $fh;

my $context = Mail::SpamAssassin::PDF::Context::Info->new();

my $pdf = Mail::SpamAssassin::PDF::Parser->new(
    context         => $context
);

$pdf->parse($data);
my $info = $pdf->{context}->get_info;

print Dumper($info);
