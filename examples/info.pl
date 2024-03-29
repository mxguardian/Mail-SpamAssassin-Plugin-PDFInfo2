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

 info.pl [OPTIONS] <PDF_FILE>

 Dumps info about a PDF file

 Options
   -f   <field>   Output the specified field value

=cut

my %opts;
getopts('f:d:',\%opts);
my $field = $opts{'f'};
my $debug = $opts{'d'};

pod2usage() unless scalar(@ARGV);

$Data::Dumper::Sortkeys = 1;

while (my $file = shift) {
    open my $fh, '<', $file or die "$!";
    local $/ = undef;
    my $data = <$fh>;
    close $fh;

    my $context = Mail::SpamAssassin::PDF::Context::Info->new();

    my $pdf = Mail::SpamAssassin::PDF::Parser->new(
        context         => $context,
        timeout         => 5,
        debug           => $debug,
    );

    eval {
        $pdf->parse(\$data);
        1;
    } or do {
        die "Error parsing $file: $@";
    };
    my $info = $pdf->{context}->get_info;

    print "PDF Version ".$pdf->version()."\n";
    if ( defined($field) ) {
        printf("%s: %s\n",$info->{$field} || '',$file);
    } else {
        print Dumper($info);
    }

}
