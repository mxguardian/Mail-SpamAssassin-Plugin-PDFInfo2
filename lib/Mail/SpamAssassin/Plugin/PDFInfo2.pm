# <@LICENSE>
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to you under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

=head1 NAME

Mail::SpamAssassin::Plugin::PDFInfo2 - PDFInfo2 Plugin for SpamAssassin

=head1 SYNOPSIS

  loadplugin     Mail::SpamAssassin::Plugin::PDFInfo2

=head1 DESCRIPTION

This plugin helps detect spam using attached PDF files

=cut

# -------------------------------------------------------

package Mail::SpamAssassin::Plugin::PDFInfo2;

use Mail::SpamAssassin::Plugin;
use Mail::SpamAssassin::Logger;
use Mail::SpamAssassin::Util qw(compile_regexp);
use strict;
use warnings;
use re 'taint';
use Digest::MD5 qw(md5_hex);

our @ISA = qw(Mail::SpamAssassin::Plugin);

# constructor: register the eval rule
sub new {
    my $class = shift;
    my $mailsaobject = shift;

    # some boilerplate...
    $class = ref($class) || $class;
    my $self = $class->SUPER::new($mailsaobject);
    bless ($self, $class);

    $self->register_eval_rule ("pdf_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf_image_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    # $self->register_eval_rule ("pdf_pixel_coverage", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    # $self->register_eval_rule ("pdf_image_size_exact", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    # $self->register_eval_rule ("pdf_image_size_range", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf_named", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf_name_regex", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    # $self->register_eval_rule ("pdf_image_to_text_ratio", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf_match_md5", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    # $self->register_eval_rule ("pdf_match_fuzzy_md5", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf_match_details", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf_is_encrypted", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    # $self->register_eval_rule ("pdf_is_empty_body", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);

    # lower priority for add_uri_detail_list to work
    $self->register_method_priority ("parsed_metadata", -1);

    return $self;
}

sub parsed_metadata {
    my ($self, $opts) = @_;

    my $pms = $opts->{permsgstatus};

    # initialize
    $pms->{pdfinfo}->{totals}->{ImageCount} = 0;
    $pms->{pdfinfo}->{files} = {};

    my @parts = $pms->{msg}->find_parts(qr@^(image|application)/(pdf|octet\-stream)$@, 1);
    my $part_count = scalar @parts;

    dbg("pdfinfo: Identified $part_count possible mime parts that need checked for PDF content");

    foreach my $p (@parts) {
        my $type = $p->{type} || '';
        my $name = $p->{name} || '';

        dbg("pdfinfo: found part, type=$type file=$name");

        # filename must end with .pdf, or application type can be pdf
        # sometimes windows muas will wrap a pdf up inside a .dat file
        # v0.8 - Added .fdf phoney PDF detection
        next unless ($name =~ /\.[fp]df$/i || $type =~ m@/pdf$@);

        _set_tag($pms, 'PDFNAME', $name);

        # Get raw PDF data
        my $data = $p->decode();
        next unless $data;

        $pms->{pdfinfo}->{md5}->{uc(md5_hex($data))} = 1;
        $pms->{pdfinfo}->{totals}->{FileCount}++;

        # Parse PDF
        my $pdf = Mail::SpamAssassin::PDF::Parser->new(
            context  => Mail::SpamAssassin::PDF::Context::Info->new
        );
        my $info = eval {
            $pdf->parse($data);
            $pdf->{context}->get_info();
        };
        if ( !defined($info) ) {
            dbg("pdfinfo: Error parsing pdf: $@");
            next;
        }

        $pms->{pdfinfo}->{files}->{$name} = $info;
        $pms->{pdfinfo}->{totals}->{ImageCount} += $info->{ImageCount};
        $pms->{pdfinfo}->{totals}->{PageCount} += $info->{PageCount};
        $pms->{pdfinfo}->{totals}->{ImageArea} += $info->{ImageArea};
        $pms->{pdfinfo}->{totals}->{PageArea} += $info->{PageArea};
        $pms->{pdfinfo}->{totals}->{Encrypted} += $info->{Encrypted};

        _set_tag($pms, 'PDFVERSION', $pdf->version );

    }

    _set_tag($pms, 'PDFCOUNT', $pms->{pdfinfo}->{totals}->{FileCount} );
    _set_tag($pms, 'PDFIMGCOUNT', $pms->{pdfinfo}->{totals}->{ImageCount});
}

sub _set_tag {
    my ($pms, $tag, $value) = @_;

    return unless defined $value && $value ne '';
    dbg("pdfinfo: set_tag called for $tag: $value");

    if (exists $pms->{tag_data}->{$tag}) {
        # Limit to some sane length
        if (length($pms->{tag_data}->{$tag}) < 2048) {
            $pms->{tag_data}->{$tag} .= ' '.$value;  # append value
        }
    }
    else {
        $pms->{tag_data}->{$tag} = $value;
    }
}

sub pdf_named {
    my ($self, $pms, $body, $name) = @_;

    return 0 unless defined $name;

    return 1 if exists $pms->{pdfinfo}->{files}->{$name};
    return 0;
}

sub pdf_name_regex {
    my ($self, $pms, $body, $regex) = @_;

    return 0 unless defined $regex;
    return 0 unless exists $pms->{pdfinfo}->{files};

    my ($rec, $err) = compile_regexp($regex, 2);
    if (!$rec) {
        my $rulename = $pms->get_current_eval_rule_name();
        warn "pdfinfo: invalid regexp for $rulename '$regex': $err";
        return 0;
    }

    foreach my $name (keys %{$pms->{pdfinfo}->{files}}) {
        if ($name =~ $rec) {
            dbg("pdfinfo: pdf_name_regex hit on $name");
            return 1;
        }
    }

    return 0;
}

sub pdf_is_encrypted {
    my ($self, $pms, $body) = @_;

    return $pms->{pdfinfo}->{totals}->{Encrypted} ? 1 : 0;
}

sub pdf_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo}->{totals}->{FileCount});
}

sub pdf_image_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo}->{totals}->{ImageCount});
}

# sub pdf_pixel_coverage {
#     my ($self,$pms,$body,$min,$max) = @_;
#
#     return _result_check($min, $max, $pms->{pdfinfo}->{pc_pdf});
# }
#
# sub pdf_image_to_text_ratio {
#     my ($self, $pms, $body, $min, $max) = @_;
#
#     return 0 unless defined $max;
#     return 0 unless $pms->{pdfinfo}->{pc_pdf};
#
#     # depending on how you call this eval (body vs rawbody),
#     # the $textlen will differ.
#     my $textlen = length(join('', @$body));
#     return 0 unless $textlen;
#
#     my $ratio = $textlen / $pms->{pdfinfo}->{pc_pdf};
#     dbg("pdfinfo: image ratio=$ratio, min=$min max=$max");
#
#     return _result_check($min, $max, $ratio, 1);
# }
#
# sub pdf_is_empty_body {
#     my ($self, $pms, $body, $min) = @_;
#
#     return 0 unless $pms->{pdfinfo}->{count_pdf};
#     $min ||= 0;  # default to 0 bytes
#
#     my $bytes = 0;
#     my $idx = 0;
#     foreach my $line (@$body) {
#         next if $idx++ == 0; # skip subject line
#         next unless $line =~ /\S/;
#         $bytes += length($line);
#         # no hit if minimum already exceeded
#         return 0 if $bytes > $min;
#     }
#
#     dbg("pdfinfo: pdf_is_empty_body matched ($bytes <= $min)");
#     return 1;
# }
#
# sub pdf_image_size_exact {
#     my ($self, $pms, $body, $height, $width) = @_;
#
#     return 0 unless defined $width;
#
#     return 1 if exists $pms->{pdfinfo}->{dems_pdf}->{"${height}x${width}"};
#     return 0;
# }
#
# sub pdf_image_size_range {
#     my ($self, $pms, $body, $minh, $minw, $maxh, $maxw) = @_;
#
#     return 0 unless defined $minw;
#     return 0 unless exists $pms->{pdfinfo}->{dems_pdf};
#
#     foreach my $dem (keys %{$pms->{pdfinfo}->{dems_pdf}}) {
#         my ($h, $w) = split(/x/, $dem);
#         next if ($h < $minh);  # height less than min height
#         next if ($w < $minw);  # width less than min width
#         next if (defined $maxh && $h > $maxh);  # height more than max height
#         next if (defined $maxw && $w > $maxw);  # width more than max width
#         # if we make it here, we have a match
#         return 1;
#     }
#
#     return 0;
# }

sub pdf_match_md5 {
    my ($self, $pms, $body, $md5) = @_;

    return 0 unless defined $md5;

    return 1 if exists $pms->{pdfinfo}->{md5}->{uc $md5};
    return 0;
}

# sub pdf_match_fuzzy_md5 {
#     my ($self, $pms, $body, $md5) = @_;
#
#     return 0 unless defined $md5;
#
#     return 1 if exists $pms->{pdfinfo}->{fuzzy_md5}->{uc $md5};
#     return 0;
# }

sub pdf_match_details {
    my ($self, $pms, $body, $detail, $regex) = @_;

    return 0 unless defined $regex;
    return 0 unless exists $pms->{pdfinfo}->{files};

    my ($re, $err) = compile_regexp($regex, 2);
    if (!$re) {
        my $rulename = $pms->get_current_eval_rule_name();
        warn "pdfinfo: invalid regexp for $rulename '$regex': $err";
        return 0;
    }

    foreach (keys %{$pms->{pdfinfo}->{files}}) {
        my $value = $pms->{pdfinfo}->{files}->{$_}->{$detail};
        if ( defined($value) && $value =~ $re ) {
            dbg("pdfinfo: pdf_match_details $detail ($regex) match: $_");
            return 1;
        }
    }

    return 0;
}

sub _result_check {
    my ($min, $max, $value, $nomaxequal) = @_;
    return 0 unless defined $min && defined $value;
    return 0 if $value < $min;
    return 0 if defined $max && $value > $max;
    return 0 if defined $nomaxequal && $nomaxequal && $value == $max;
    return 1;
}

1;