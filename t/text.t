#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Test::More;
use Mail::SpamAssassin;

my $spamassassin = Mail::SpamAssassin->new(
    {
        dont_copy_prefs    => 1,
        local_tests_only   => 1,
        use_bayes          => 0,
        use_razor2         => 0,
        use_pyzor          => 0,
        use_dcc            => 0,
        use_auto_whitelist => 0,
        debug              => '0',
        pre_config_text        => <<'EOF'
            loadplugin Mail::SpamAssassin::Plugin::PDFInfo2

            pdftext  PDFINFO2_ENC  /encrypted message/i

EOF
            ,
    }
);

my @files = (
    {
        'name'       => 't/spam/msg1.eml',
        'hits'       => {
            'PDFINFO2_ENC' => 1,
        },
        'pattern_hits' => {
            'PDFINFO2_ENC' => 'encrypted message',
        }
    },
);

plan tests => scalar @files * 2;

# test each file
foreach my $file (@files) {
    print "Testing $file->{name}\n";
    my $path = $file->{name};
    open my $fh, '<', $path or die "Can't open $path: $!";
    my $msg = $spamassassin->parse($fh);
    my $pms = $spamassassin->check($msg);
    close $fh;

    my $hits = $pms->get_names_of_tests_hit_with_scores_hash();
    my $pattern_hits = $pms->{pattern_hits};

    # remove all but PDFINFO2 tests
    foreach my $test (keys %$hits) {
        delete $hits->{$test} unless $test =~ /PDFINFO2/;
    }
    foreach my $test (keys %$pattern_hits) {
        delete $pattern_hits->{$test} unless $test =~ /PDFINFO2/;
    }
    is_deeply($hits, $file->{hits}, $file->{name});
    is_deeply($pattern_hits, $file->{pattern_hits}, $file->{name});
}

