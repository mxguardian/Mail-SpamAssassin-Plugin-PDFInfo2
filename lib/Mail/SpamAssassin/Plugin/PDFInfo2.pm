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

Mail::SpamAssassin::Plugin::PDFInfo2 - Improved PDF Plugin for SpamAssassin

=head1 AUTHORS

Kent Oyer (kent@mxguardian.net)

=head1 ACKNOWLEGEMENTS

This plugin is loosely based on Mail::SpamAssassin::Plugin::PDFInfo by Dallas Engelken however it is not a drop-in
replacement as it works completely different. The tag and test names have been chosen so that both plugins can be run
simultaneously, if desired.

Encryption routines were made possible by borrowing some code from CAM::PDF by Chris Dolan

=head1 SYNOPSIS

  loadplugin     Mail::SpamAssassin::Plugin::PDFInfo2

=head1 REQUIREMENTS

This plugin requires the following non-core perl modules:

=over 1

=item Crypt::RC4

=item Crypt::Mode::CBC

=back

=head1 USAGE

  pdf2_count()

     body RULENAME  eval:pdf2_count(<min>,[max])
        min: required, message contains at least x PDF attachments
        max: optional, if specified, must not contain more than x PDF attachments

  pdf2_page_count()

     body RULENAME  eval:pdf2_page_count(<min>,[max])
        min: required, message contains at least x pages in PDF attachments.
        max: optional, if specified, must not contain more than x PDF pages

  pdf2_link_count()

     body RULENAME  eval:pdf2_link_count(<min>,[max])
        min: required, message contains at least x links in PDF attachments.
        max: optional, if specified, must not contain more than x PDF links

        Note: Multiple links to the same URL are counted multiple times

  pdf2_word_count()

     body RULENAME  eval:pdf2_page_count(<min>,[max])
        min: required, message contains at least x words in PDF attachments.
        max: optional, if specified, must not contain more than x PDF words

        Note: This plugin does not extract text from PDF's. In order for pdf2_word_count to work the text must
        be extracted by another plugin such as ExtractText.pm

  pdf2_match_md5()

     body RULENAME  eval:pdf2_match_md5(<string>)
        string: 32-byte md5 hex

        Fires if any PDF attachment matches the given MD5 checksum

  pdf2_match_fuzzy_md5()

     body RULENAME  eval:pdf2_match_fuzzy_md5(<string>)
        string: 32-byte md5 hex string

        Fires if any PDF attachment matches the given fuzzy MD5 checksum

  pdf2_match_details()

     body RULENAME  eval:pdf2_match_details(<detail>,<regex>);
        detail: Any standard PDF attribute: Author, Creator, Producer, Title, CreationDate, ModDate, etc..
        regex: regular expression

        Fires if any PDF attachment has the given attribute and it's value matches the given regular expression

  pdf2_is_encrypted()

     body RULENAME eval:pdf2_is_encrypted()

        Fires if any PDF attachment is encrypted

        Note: PDF's can be encrypted with a blank password which allows them to be opened with any standard viewer.
        This plugin attempts to decrypt PDF's with a blank password. However, pdf2_is_encrypted still returns true.

  pdf2_is_protected()

     body RULENAME eval:pdf2_is_protected()

        Fires if any PDF attachment is encrypted with a non-blank password

        Note: Although it's not possible to inspect the contents of password-protected PDF's, the following tests
        may still yield valuable data: pdf2_count, pdf2_page_count, pdf2_match_md5, pdf2_match_fuzzy_md5, and
        pdf2_match_details('Version')

The following rules only inspect the first page of each document

  pdf2_image_count()

     body RULENAME  eval:pdf2_image_count(<min>,[max])
        min: required, message contains at least x images on page 1 (all attachments combined).
        max: optional, if specified, must not contain more than x images on page 1

  pdf2_color_image_count()

     body RULENAME  eval:pdf2_color_image_count(<min>,[max])
        min: required, message contains at least x color images on page 1 (all attachments combined).
        max: optional, if specified, must not contain more than x color images on page 1

  pdf2_image_ratio()

     body RULENAME  eval:pdf2_image_ratio(<min>,[max])
        min: required, images consume at least x percent of page 1 on any PDF attachment
        max: optional, if specified, images do not consume more than x percent of page 1 on any PDF attachment

        Note: Percent values range from 0-100

  pdf2_click_ratio()

     body RULENAME  eval:pdf2_click_ratio(<min>,[max])
        min: required, at least x percent of page 1 is clickable on any PDF attachment
        max: optional, if specified, not more than x percent of page 1 is clickable on any PDF attachment

        Note: Percent values range from 0-100

=head1 TAGS

The following tags can be defined in an C<add_header> line:

    _PDF22COUNT_      - total number of pdf mime parts in the email
    _PDF2PAGECOUNT_   - total number of pages in all pdf attachments
    _PDF2WORDCOUNT_   - total number of words in all pdf attachments
    _PDF2LINKCOUNT_   - total number of links in all pdf attachments
    _PDF2IMAGECOUNT_  - total number of images found on page 1 inside all pdf attachments
    _PDF2CIMAGECOUNT_ - total number of color images found on page 1 inside all pdf attachments
    _PDF2VERSION_     - PDF Version, space seperated if there are > 1 pdf attachments
    _PDF2IMAGERATIO_  - Percent of first page that is consumed by images - per attachment, space separated
    _PDF2CLICKRATIO_  - Percent of first page that is clickable - per attachment, space separated
    _PDF2NAME_        - Filenames as found in the mime headers of PDF parts
    _PDF2PRODUCER_    - Producer/Application that created the PDF(s)
    _PDF2AUTHOR_      - Author of the PDF
    _PDF2CREATOR_     - Creator/Program that created the PDF(s)
    _PDF2TITLE_       - Title of the PDF File, if available
    _PDF2MD5_         - MD5 checksum of PDF(s) - space seperated
    _PDF2MD5FUZZY1_   - Fuzzy1 MD5 checksum of PDF(s) - space seperated

Example C<add_header> lines:

    add_header all PDF-Info pdf=_PDF2COUNT_, ver=_PDF2VERSION_, name=_PDF2NAME_
    add_header all PDF-Details producer=_PDF2PRODUCER_, author=_PDF2AUTHOR_, creator=_PDF2CREATOR_, title=_PDF2TITLE_
    add_header all PDF-ImageInfo images=_PDF2IMAGECOUNT_ cimages=_PDF2CIMAGECOUNT_ ratios=_PDF2IMAGERATIO_
    add_header all PDF-LinkInfo links=_PDF2LINKCOUNT_, ratios=_PDF2CLICKRATIO_
    add_header all PDF-Md5 md5=_PDF2MD5_, fuzzy1=_PDF2MD5FUZZY1_


=head1 URI DETAILS

This plugin creates a new "pdf" URI type. You can detect URI's in PDF's using the URIDetail.pm plugin. For example:

    uri-detail RULENAME  raw =~ /^https?:\/\/bit\.ly\// type =~ /^pdf$/

This will detect a PDF that contains a bit.ly link.

=cut

package Mail::SpamAssassin::Plugin::PDFInfo2;

use Mail::SpamAssassin::Plugin;
use Mail::SpamAssassin::Logger;
use Mail::SpamAssassin::Util qw(compile_regexp);
use strict;
use warnings;
use re 'taint';
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

my $VERSION = 0.9;

our @ISA = qw(Mail::SpamAssassin::Plugin);

# constructor: register the eval rule
sub new {
    my $class = shift;
    my $mailsaobject = shift;

    # some boilerplate...
    $class = ref($class) || $class;
    my $self = $class->SUPER::new($mailsaobject);
    bless ($self, $class);

    $self->register_eval_rule ("pdf2_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_image_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_color_image_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_link_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_word_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_page_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_image_ratio", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_click_ratio", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_match_md5", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_match_fuzzy_md5", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_match_details", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_is_encrypted", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_is_protected", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);

    # lower priority for add_uri_detail_list to work
    $self->register_method_priority ("parsed_metadata", -1);

    return $self;
}

sub parsed_metadata {
    my ($self, $opts) = @_;

    my $pms = $opts->{permsgstatus};

    # initialize
    $pms->{pdfinfo2}->{files} = {};
    $pms->{pdfinfo2}->{totals} = {
        FileCount       => 0,
        ImageCount      => 0,
        ColorImageCount => 0,
        LinkCount       => 0,
        PageCount       => 0,
        WordCount       => 0
    };

    foreach my $p ($pms->{msg}->find_parts(qr/./,1)) {
        my $type = $p->{type} || '';
        my $name = $p->{name} || '';

        next unless $type =~ qr/\/pdf$/ or $name =~ /\.pdf$/i;

        dbg("pdfinfo2: found part, type=$type file=$name");

        _set_tag($pms, 'PDF2NAME', $name);
        $pms->{pdfinfo2}->{totals}->{FileCount}++;

        # Get raw PDF data
        my $data = $p->decode();
        next unless $data;

        my $md5 = uc(md5_hex($data));

        # Parse PDF
        my $pdf = Mail::SpamAssassin::PDF::Parser->new();
        my $info = eval {
            $pdf->parse($data);
            $pdf->{context}->get_info();
        };
        if ( !defined($info) ) {
            dbg("pdfinfo2: Error parsing pdf: $@");
            next;
        }

        # Add URI's
        foreach my $location ( keys %{ $info->{uris} }) {
            dbg("pdfinfo2: found URI: $location");
            $pms->add_uri_detail_list($location,{ pdf => 1 },'PDFInfo2');
        }

        # Get word count (requires ExtractText to have already extracted text from the PDF)
        my $text = $p->rendered() || '';
        $info->{WordCount} = scalar(split(/\s+/, $text));


        $pms->{pdfinfo2}->{files}->{$name} = $info;
        $pms->{pdfinfo2}->{totals}->{ImageCount} += $info->{ImageCount};
        $pms->{pdfinfo2}->{totals}->{ColorImageCount} += $info->{ColorImageCount};
        $pms->{pdfinfo2}->{totals}->{PageCount} += $info->{PageCount};
        $pms->{pdfinfo2}->{totals}->{LinkCount} += $info->{LinkCount};
        $pms->{pdfinfo2}->{totals}->{WordCount} += $info->{WordCount};
        $pms->{pdfinfo2}->{totals}->{ImageArea} += $info->{ImageArea};
        $pms->{pdfinfo2}->{totals}->{PageArea} += $info->{PageArea};
        $pms->{pdfinfo2}->{totals}->{Encrypted} += $info->{Encrypted};
        $pms->{pdfinfo2}->{totals}->{Protected} += $info->{Protected};
        $pms->{pdfinfo2}->{md5}->{$md5} = 1;

        _set_tag($pms, 'PDF2PRODUCER', $info->{Producer});
        _set_tag($pms, 'PDF2AUTHOR', $info->{Author});
        _set_tag($pms, 'PDF2CREATOR', $info->{Creator});
        _set_tag($pms, 'PDF2TITLE', $info->{Title});
        _set_tag($pms, 'PDF2IMAGERATIO', $info->{ImageRatio});
        _set_tag($pms, 'PDF2CLICKRATIO', $info->{ImageRatio});
        _set_tag($pms, 'PDF2VERSION', $pdf->version );

        $pms->{pdfinfo2}->{md5}->{$md5} = 1;
        $pms->{pdfinfo2}->{fuzzy_md5}->{$info->{FuzzyMD5}} = 1;
        _set_tag($pms, 'PDF2MD5', $md5);
        _set_tag($pms, 'PDF2MD5FUZZY1', $info->{FuzzyMD5});

    }

    _set_tag($pms, 'PDF2COUNT', $pms->{pdfinfo2}->{totals}->{FileCount} );
    _set_tag($pms, 'PDF2IMAGECOUNT', $pms->{pdfinfo2}->{totals}->{ImageCount});
    _set_tag($pms, 'PDF2CIMAGECOUNT', $pms->{pdfinfo2}->{totals}->{ColorImageCount});
    _set_tag($pms, 'PDF2WORDCOUNT', $pms->{pdfinfo2}->{totals}->{WordCount});
    _set_tag($pms, 'PDF2PAGECOUNT', $pms->{pdfinfo2}->{totals}->{PageCount});
    _set_tag($pms, 'PDF2LINKCOUNT', $pms->{pdfinfo2}->{totals}->{LinkCount});
}

sub _set_tag {
    my ($pms, $tag, $value) = @_;

    return unless defined $value && $value ne '';
    dbg("pdfinfo2: set_tag called for $tag: $value");

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

sub pdf2_is_encrypted {
    my ($self, $pms, $body) = @_;

    return $pms->{pdfinfo2}->{totals}->{Encrypted} ? 1 : 0;
}

sub pdf2_is_protected {
    my ($self, $pms, $body) = @_;

    return $pms->{pdfinfo2}->{totals}->{Protected} ? 1 : 0;
}

sub pdf2_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo2}->{totals}->{FileCount});
}

sub pdf2_image_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo2}->{totals}->{ImageCount});
}

sub pdf2_color_image_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo2}->{totals}->{ColorImageCount});
}

sub pdf2_image_ratio {
    my ($self, $pms, $body, $min, $max) = @_;

    foreach (keys %{$pms->{pdfinfo2}->{files}}) {
        return 1 if _result_check($min, $max, $pms->{pdfinfo2}->{files}->{$_}->{ImageRatio});
    }
    return 0;
}

sub pdf2_click_ratio {
    my ($self, $pms, $body, $min, $max) = @_;

    foreach (keys %{$pms->{pdfinfo2}->{files}}) {
        return 1 if _result_check($min, $max, $pms->{pdfinfo2}->{files}->{$_}->{ClickRatio});
    }
    return 0;
}

sub pdf2_match_md5 {
    my ($self, $pms, $body, $md5) = @_;

    return 0 unless defined $md5;

    return 1 if exists $pms->{pdfinfo2}->{md5}->{uc $md5};
    return 0;
}

sub pdf2_match_fuzzy_md5 {
    my ($self, $pms, $body, $md5) = @_;

    return 0 unless defined $md5;
    return 1 if exists $pms->{pdfinfo2}->{fuzzy_md5}->{uc $md5};
    return 0;
}

sub pdf2_link_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo2}->{totals}->{LinkCount});
}

sub pdf2_word_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo2}->{totals}->{WordCount});
}

sub pdf2_page_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo2}->{totals}->{PageCount});
}

sub pdf2_match_details {
    my ($self, $pms, $body, $detail, $regex) = @_;

    return 0 unless defined $regex;
    return 0 unless exists $pms->{pdfinfo2}->{files};

    my ($re, $err) = compile_regexp($regex, 2);
    if (!$re) {
        my $rulename = $pms->get_current_eval_rule_name();
        warn "pdfinfo2: invalid regexp for $rulename '$regex': $err";
        return 0;
    }

    foreach (keys %{$pms->{pdfinfo2}->{files}}) {
        my $value = $pms->{pdfinfo2}->{files}->{$_}->{$detail};
        if ( defined($value) && $value =~ $re ) {
            dbg("pdfinfo2: pdf2_match_details $detail ($regex) match: $_");
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