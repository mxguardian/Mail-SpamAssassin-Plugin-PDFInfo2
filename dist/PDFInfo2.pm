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

=head1 ACKNOWLEGEMENTS

This plugin is loosely based on Mail::SpamAssassin::Plugin::PDFInfo by Dallas Engelken however it is not a drop-in
replacement as it works completely different. The tag and test names have been chosen so that both plugins can be run
simultaneously, if desired.

Notable improvements:

=over 4

=item It can parse PDF's that are encrypted with a blank password

=item Several of the tests focus exclusively on page 1 of each document. This not only helps with performance but is a countermeasure against content stuffing

=item pdf2_click_ratio - Fires based on how much of page 1 is clickable. Based on preliminary testing, anything over 20% is likely spam, especially if there's only one link and the word count is low.

=back

Encryption routines were made possible by borrowing some code from CAM::PDF by Chris Dolan

Links to the official PDF specification:

=over 1

=item Version 1.6: L<https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.6.pdf>

=item Version 1.7: L<https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf>

=item Version 1.7 Extension Level 3: L<https://web.archive.org/web/20210326023925/https://www.adobe.com/content/dam/acom/en/devnet/acrobat/pdfs/adobe_supplement_iso32000.pdf>

=back

=head1 REQUIREMENTS

This plugin requires the following non-core perl modules:

=over 1

=item Crypt::RC4

=item Crypt::Mode::CBC

=item Convert::Ascii85

=back

=head1 INSTALLATION

=head3 Manual method

Copy all the files in the C<dist/> directory to your site rules directory (e.g. C</etc/mail/spamassassin>)

=head3 Automatic method

TBD

=head1 SYNOPSIS

  loadplugin     Mail::SpamAssassin::Plugin::PDFInfo2

=head1 RULE DEFINITIONS

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

        Note: This plugin does not extract text from PDF's. In order for pdf2_word_count to work the text
        must be extracted by another plugin such as ExtractText.pm

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

        Fires if any PDF attachment has the given attribute and it's value matches the given regular
        expression

  pdf2_is_encrypted()

     body RULENAME eval:pdf2_is_encrypted()

        Fires if any PDF attachment is encrypted

        Note: PDF's can be encrypted with a blank password which allows them to be opened with any standard
        viewer. This plugin attempts to decrypt PDF's with a blank password. However, pdf2_is_encrypted still
        returns true.

  pdf2_is_protected()

     body RULENAME eval:pdf2_is_protected()

        Fires if any PDF attachment is encrypted with a non-blank password

        Note: Although it's not possible to inspect the contents of password-protected PDF's, the following
        tests still provide meaningful data: pdf2_count, pdf2_page_count, pdf2_match_md5,
        pdf2_match_fuzzy_md5, and pdf2_match_details('Version'). All other values will be empty/zero.

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
        max: optional, if specified, images do not consume more than x percent of page 1

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
    _PDF2MD5FUZZY2_   - Fuzzy2 MD5 checksum of PDF(s) - space seperated

Example C<add_header> lines:

    add_header all PDF-Info pdf=_PDF2COUNT_, ver=_PDF2VERSION_, name=_PDF2NAME_
    add_header all PDF-Details producer=_PDF2PRODUCER_, author=_PDF2AUTHOR_, creator=_PDF2CREATOR_, title=_PDF2TITLE_
    add_header all PDF-ImageInfo images=_PDF2IMAGECOUNT_ cimages=_PDF2CIMAGECOUNT_ ratios=_PDF2IMAGERATIO_
    add_header all PDF-LinkInfo links=_PDF2LINKCOUNT_, ratios=_PDF2CLICKRATIO_
    add_header all PDF-Md5 md5=_PDF2MD5_, fuzzy1=_PDF2MD5FUZZY1_


=head1 MD5 CHECKSUMS

To view the MD5 checksums for a message you can run:

    cat msg.eml | spamassassin -D -L |& grep PDF2MD5

The Fuzzy 1 checksum is calculated using tags from every object that is traversed which is essentially pages,
images, and the document trailer. You should expect a match if two PDF's were created by the same author/program
and have the same structure with the same or slightly different content.

The Fuzzy 2 checksum only includes the comment lines at the beginning of the document plus the first object. The
Fuzzy 2 checksum is generally an indicator of what software created the PDF but the contents could be totally
different.

=head1 URI DETAILS

This plugin creates a new "pdf" URI type. You can detect URI's in PDF's using the URIDetail.pm plugin. For example:

    uri-detail RULENAME  type =~ /^pdf$/  raw =~ /^https?:\/\/bit\.ly\//

This will detect a bit.ly link inside a PDF document

=head1 AUTHORS

Kent Oyer <kent@mxguardian.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2023 MXGuardian LLC

This is free software; you can redistribute it and/or modify it under
the terms of the Apache License 2.0. See the LICENSE file included
with this distribution for more information.

This plugin is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

package Mail::SpamAssassin::PDF::Core;
use strict;
use warnings FATAL => 'all';
use Encode qw(from_to decode);
use Carp;
use Data::Dumper;

=head1 NAME

Mail::SpamAssassin::PDF::Core - Core PDF parsing functions

=head1 DESCRIPTION

This module contains the core PDF parsing functions.  It is not intended to be
used directly, but rather to be used by other modules in this distribution.

=head1 METHODS

=over

=cut

use constant CHAR_SPACE             => 0;
use constant CHAR_NUM               => 1;
use constant CHAR_ALPHA             => 2;
use constant CHAR_BEGIN_NAME        => 3;
use constant CHAR_BEGIN_ARRAY       => 4;
use constant CHAR_BEGIN_DICT        => 5;
use constant CHAR_END_ARRAY         => 6;
use constant CHAR_END_DICT          => 7;
use constant CHAR_BEGIN_STRING      => 8;
use constant CHAR_END_STRING        => 9;
use constant CHAR_BEGIN_COMMENT     => 10;

use constant TYPE_NUM     => 0;
use constant TYPE_OP      => 1;
use constant TYPE_STRING  => 2;
use constant TYPE_NAME    => 3;
use constant TYPE_REF     => 4;
use constant TYPE_ARRAY   => 5;
use constant TYPE_DICT    => 6;
use constant TYPE_STREAM  => 7;
use constant TYPE_COMMENT => 8;

my %specials = (
    'n' => "\n",
    'r' => "\r",
    't' => "\t",
    'b' => "\b",
    'f' => "\f",
);

my %class_map;
$class_map{$_} = CHAR_SPACE         for split //, " \n\r\t\f\b";
$class_map{$_} = CHAR_NUM           for split //, '0123456789.+-';
$class_map{$_} = CHAR_ALPHA         for split //, 'abcdefghijklmnopqrstuvwxyz';
$class_map{$_} = CHAR_ALPHA         for split //, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
$class_map{$_} = CHAR_ALPHA         for split //, '*_#"\'';
$class_map{$_} = CHAR_BEGIN_NAME    for split //, '/';
$class_map{$_} = CHAR_BEGIN_ARRAY   for split //, '[';
$class_map{$_} = CHAR_END_ARRAY     for split //, ']';
$class_map{$_} = CHAR_BEGIN_STRING  for split //, '(';
$class_map{$_} = CHAR_END_STRING    for split //, ')';
$class_map{$_} = CHAR_BEGIN_DICT    for split //, '<';
$class_map{$_} = CHAR_END_DICT      for split //, '>';
$class_map{$_} = CHAR_BEGIN_COMMENT for split //, '%';

=item new($fh)

Creates a new instance of the object.  $fh is an open file handle to the PDF file or a reference to a scalar containing
the contents of the PDF file.

=cut

sub new {
    my $class = shift;
    my $self = bless {},$class;
    $self->_init(@_);
    return $self;
}

=item clone($fh)

Returns a new instance of the object with the same state as the original, but
using the new file handle.

=cut

sub clone {
    my $self = shift;
    my $copy = bless { %$self }, ref $self;
    $copy->_init(@_);
    return $copy;
}

sub _init {
    my $self = shift;
    if (ref($_[0]) eq 'SCALAR') {
        # scalar ref, open it as a file
        open(my $fh, '<', $_[0]) or croak "Can't open file: $!";
        binmode($fh);
        $self->{fh} = $fh;
    } else {
        $self->{fh} = $_[0];
    }
}

=item pos($offset)

Sets the file pointer to the specified offset.  If no offset is specified, returns the current offset.

=cut

sub pos {
    my ($self,$offset) = @_;
    defined($offset) ? seek($self->{fh},$offset,0) : tell($self->{fh});
}

=item get_name

Reads a name from the file.  A name is a forward slash followed by a sequence of characters.  The file pointer is left
at the first character after the name.

=cut

sub get_name {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $name = getc($fh);
    unless ($name eq '/') {
        seek($fh, -1, 1);
        croak "Name not found at offset " . tell($fh);
    }

    while (defined(my $ch = getc($fh))) {
        my $class = $class_map{$ch};
        unless (defined($class)) {
            seek($fh, -1, 1);
            croak "unknown char $ch at offset " . tell($fh);
        }
        if ( $class == CHAR_ALPHA || $class == CHAR_NUM ) {
            $name .= $ch;
            next;
        } else {
            seek($fh, -1, 1) unless $class == CHAR_SPACE;
            last;
        }
    }
    return wantarray ? ($name,TYPE_NAME) : $name;
}

=item get_string

Reads a string from the file.  A string is a sequence of characters enclosed in parentheses.  The file pointer is left
at the first character after the string.

=cut

sub get_string {
    my ($self) = @_;
    my $fh = $self->{fh};

    unless (getc($fh) eq '(') {
        seek($fh, -1, 1);
        croak "string not found at offset " . tell($fh);
    }

    my $depth = 1;
    my $str = '';
    my $esc = 0;
    while ($depth > 0) {
        my $ch = getc($fh);
        if ( !defined($ch) ) {
            croak "Unterminated string at offset ".tell($fh);
        }
        if ($esc) {
            if ( defined($specials{$ch}) ) {
                $str .= $specials{$ch};
            } elsif ($ch =~ /[0-7]/) {
                my $oct = $ch;
                $ch = getc($fh);
                if ( $ch =~ /[0-7]/ ) {
                    $oct .= $ch;
                    $ch = getc($fh);
                    if ( $ch =~ /[0-7]/ ) {
                        $oct .= $ch;
                    } else {
                        seek($fh, -1, 1);
                    }
                } else {
                    seek($fh, -1, 1);
                }
                $str .= chr(oct($oct));
            } else {
                $str .= $ch;
            }
            $esc = 0;
        } elsif ($ch eq '\\') {
            $esc = 1;
        } elsif ($ch eq '(') {
            $str .= $ch;
            $depth++;
        } elsif ($ch eq ')') {
            $depth--;
            $str .= $ch if $depth > 0;
        } else {
            $str .= $ch;
        }

    }

    # decrypt
    if ( defined($self->{crypt}) ) {
        $str = $self->{crypt}->decrypt($str);
    }

    # Convert UTF-16 to UTF-8 and remove BOM
    if ( $str =~ s/^\xfe\xff// ) {
        from_to($str,'UTF-16be', 'UTF-8');
    } elsif ( $str =~ s/^\xff\xfe// ) {
        from_to($str,'UTF-16le', 'UTF-8');
    }

    # remove trailing null chars
    $str =~ s/\x00+$//;

    return wantarray ? ($str,TYPE_STRING) : $str;
}

=item get_number

Reads a number from the file.  A number can be an integer or a real number.  The file pointer is left at the first
character after the number. Returns undef if no number is found.

=cut

sub get_number {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $num = '';
    while (defined(my $ch = getc($fh))) {
        my $class = $class_map{$ch};
        unless (defined($class)) {
            seek($fh, -1, 1);
            croak "unknown char $ch at offset " . tell($fh);
        }
        if ( $class == CHAR_NUM) {
            $num .= $ch;
            next;
        } elsif ( length($num) ) {
            seek($fh, -1, 1) unless $class == CHAR_SPACE;
            last;
        } elsif ( $class == CHAR_SPACE) {
            # skip leading spaces
            next;
        } else {
            # not a number
            seek($fh, -1, 1);
            return;
        }
    }
    $num += 0;
    return wantarray ? ($num,TYPE_NUM) : $num;
}

sub assert_number {
    my ($self,$num) = @_;
    my $fh = $self->{fh};

    my $offset = tell($fh);
    my $token = $self->get_token();
    if (!defined($token) ) {
        seek($fh, $offset, 0);
        croak "Expected number, got EOF at offset $offset";
    }
    if ($token !~ /^[0-9+.-]+$/ ) {
        seek($fh, $offset, 0);
        croak "Expected number, got '$token' at offset $offset";
    }
    if ( defined($num) && $token != $num ) {
        seek($fh, $offset, 0);
        croak "Expected number '$num', got '$token' at offset $offset";
    }

}

=item assert_token($literal)

Get the next token from the file and croak if it doesn't match the specified literal.

=cut

sub assert_token {
    my ($self,$literal) = @_;
    my $fh = $self->{fh};

    my $offset = tell($fh);
    my $token = $self->get_token();
    if (!defined($token) ) {
        croak "Expected '$literal', got EOF at offset " . tell($fh);
    }
    if ($token ne $literal) {
        seek($fh, $offset, 0);
        croak "Expected '$literal', got '$token' at offset " . tell($fh);
    }
    1;
}

=item get_token

Get the next token from the file as a string of characters. Will skip leading spaces and comments. Returns undef if
there are no more tokens. Will croak if an invalid character is encountered.

=cut

sub get_token {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $token = undef;
    my $last_class;
    while (defined(my $ch = getc($fh))) {
        my $class = $class_map{$ch};
        unless (defined($class)) {
            seek($fh, -1, 1);
            croak "unknown char $ch at offset " . tell($fh);
        }
        if ( defined($last_class) && ($class != $last_class or $ch eq '/') ) {
            if ($last_class == CHAR_SPACE) {
                # skip leading spaces
                $token = '';
            } else {
                seek($fh, -1, 1) unless $class == CHAR_SPACE;
                last;
            }
        }
        $last_class = $class;
        $token .= $ch;
    }

    return wantarray ? ($token,$last_class) : $token;
}

=item get_hex_string

Reads a hex string from the file.  A hex string is a sequence of hexadecimal digits enclosed in angle brackets with
optional whitespace between the digits. The digits must be an even number of characters.  The file pointer is left at
the first character after the string.

=cut

sub get_hex_string {
    my ($self) = @_;
    my $fh = $self->{fh};

    unless (getc($fh) eq '<') {
        seek($fh, -1, 1);
        croak "hex string not found at offset " . tell($fh);
    }

    my $hex = '';
    while ( defined(my $ch = getc($fh)) ) {
        last if $ch eq '>';
        next if $ch =~ /\s/; # skip whitespace
        croak "Invalid hex string at offset " . tell($fh) unless $ch =~ /[0-9a-fA-F]/;
        $hex .= $ch;
    }
    croak "Odd number of hex digits at offset " . tell($fh) if length($hex) % 2 == 1;
    my $str = pack("H*",$hex);

    # decrypt
    if ( defined($self->{crypt}) ) {
        $str = $self->{crypt}->decrypt($str);
    }

    if ( $str =~ s/^\xfe\xff// ) {
        from_to($str,'UTF-16be', 'UTF-8');
    } elsif ( $str =~ s/^\xff\xfe// ) {
        from_to($str,'UTF-16le', 'UTF-8');
    }
    return  wantarray ? ($str,TYPE_STRING) : $str;
}

=item get_array

Reads an array from the file.  An array is a sequence of objects enclosed in square brackets.  The file pointer is left
at the first character after the array.

=cut

sub get_array {
    my ($self) = @_;
    my $fh = $self->{fh};
    my @array;

    $self->assert_token('[');

    while () {
        ($_) = $self->get_primitive($fh);
        last if $_ eq ']';
        push(@array,$_);
    }

    return wantarray ? (\@array,TYPE_ARRAY) : \@array;
}

=item get_dict

Reads a dictionary from the file.  A dictionary is a sequence of key/value pairs enclosed in double angle brackets.  The
file pointer is left at the first character after the dictionary.

=cut

sub get_dict {
    my ($self) = @_;
    my $fh = $self->{fh};
    my @array;

    $self->assert_token('<<');

    while () {
        $_ = $self->get_primitive();
        croak "Unexpected end of file" unless defined($_);
        last if $_ eq '>>';
        push(@array,$_);
    }

    my %dict = @array;

    # From the docs: "The keyword stream that follows the stream dictionary shall be followed by an end-of-line marker
    #   consisting of either a CARRIAGE RETURN and a LINE FEED or just a LINE FEED, and not by a CARRIAGE
    #   RETURN alone."
    # Unfortunately this isn't always true in real life so we have to allow:
    #   stream\r\n
    #   stream\n
    #   stream\r

    my $offset = tell($fh);
    $_ = $self->get_token();
    if (defined($_) && $_ eq 'stream') {
        for (1..2) {
            my $ch = getc($fh);
            if ( !defined($ch) or $ch eq "\n") {
                last;
            } elsif ( $ch eq "\r" ) {
                next;
            } else {
                seek($fh, -1, 1);
                last;
            }
        }
        $dict{_stream_offset} = tell($fh);
        return wantarray ? (\%dict,TYPE_STREAM) : \%dict;
    } else {
        seek($fh, $offset, 0);
    }

    return wantarray ? (\%dict,TYPE_DICT) : \%dict;

}

=item get_primitive

Reads a primitive object from the file.  A primitive object can be a number, string, name, array, dictionary,
or reference. The file pointer is left at the first character after the object.

=cut

sub get_primitive {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $last_class;
    my $buf = '';
    while (defined(my $ch = getc($fh))) {
        my $class = $class_map{$ch};
        die "unknown char $ch" unless defined($class);
        if ( $class == CHAR_NUM ) {
            return $self->get_num_or_ref($ch);
        }
        if ( defined($last_class) && $class != $last_class ) {
            if ($last_class == CHAR_SPACE ) {
                $buf = '';
            } else {
                seek($fh, -1, 1);
                last;
            }
        }
        if ( $class == CHAR_BEGIN_NAME ) {
            seek($fh, -1, 1);
            return $self->get_name($fh);
        }
        if ( $class == CHAR_BEGIN_DICT ) {
            if (getc($fh) eq $ch) {
                seek($fh, -2, 1);
                return $self->get_dict($fh);
            } else {
                seek($fh, -2, 1);
                return $self->get_hex_string($fh);
            }
        }
        if ( $class == CHAR_BEGIN_ARRAY ) {
            seek($fh, -1, 1);
            return $self->get_array($fh);
        }
        if ( $class == CHAR_BEGIN_STRING ) {
            seek($fh, -1, 1);
            return $self->get_string($fh);
        }
        if ( $class == CHAR_END_ARRAY || $class == CHAR_END_STRING ) {
            return wantarray ? ($ch,$class) : $ch;
        }
        if ( $class == CHAR_END_DICT ) {
            if ( getc($fh) eq $ch ) {
                return wantarray ? ('>>',CHAR_END_DICT) : '>>';
            }
            seek($fh, -1, 1);
            return wantarray ? ($ch,CHAR_END_STRING) : $ch;
        }
        if ( $class == CHAR_BEGIN_COMMENT ) {
            seek($fh, -1, 1);
            return $self->get_comment($fh);
        }
        $buf .= $ch;
        $last_class = $class;
    }

    if (!defined($last_class) || $last_class eq CHAR_SPACE) {
        # EOF
        return (undef,undef);
    } elsif ( $last_class == CHAR_ALPHA ) {
        return wantarray ? ($buf,TYPE_OP) : $buf;
    } else {
        # shouldn't happen
        return wantarray ? ($buf,undef) : $buf;
    }

}

=item get_line

Reads a line from the file.  A line is a sequence of characters terminated by a line feed, a carriage return, or
a carriage return/line feed combo. The returned string will include the newline character(s).  The file pointer is left
at the first character after the line.

=cut

sub get_line {
    my ($self) = @_;
    my $fh = $self->{fh};
    my $line;
    my $limit = 1024;
    while (defined(my $ch = getc($fh)) && $limit--) {
        $line .= $ch;
        if ($ch eq "\n") {
            last;
        } elsif ($ch eq "\r") {
            my $ch2 = getc($fh);
            if (defined($ch2) && $ch2 eq "\n") {
                $line .= $ch2;
                last;
            } else {
                seek($fh, -1, 1);
                return $line;
            }
        }
    }

    return $line;
}

=item get_startxref

Reads the startxref value from the end of the file. Will croak if the startxref value is not found or is invalid.

=cut

sub get_startxref {
    my ($self) = @_;
    my $fh = $self->{fh};

    # read backwards from the end of the file looking for 'startxref'
    my $tok = '';
    my $pos = -1;
    my $limit = 1024;
    while ($limit--) {
        seek($fh,$pos--,2);
        my $ch = getc($fh);
        last unless defined($ch);
        if ( $ch =~ /\s/ ) {
            if ( $tok eq 'startxref' ) {
                seek($fh, 9, 1);
                last;
            }
            $tok = '';
            next;
        }
        $tok = $ch . $tok;
    }

    croak "startxref not found" unless $tok eq 'startxref';

    my $xref = $self->get_number();
    croak "Invalid startxref" unless defined($xref);

    eval {
        $self->assert_token('%%');
        $self->assert_token('EOF');
        1;
    } or do {
        croak "Invalid startxref. EOF marker not found";
    };

    return $xref;

}

=item get_comment

Reads a comment from the file.  A comment is a '%' sign followed by a sequence of characters terminated by a line feed,
a carriage return, or a carriage return/line feed combo. The returned string will include the '%' and newline
character(s).  The file pointer is left at the first character after the comment. Retuns undef if no comment is found.

=cut

sub get_comment {
    my ($self) = @_;
    my $comment = $self->get_line();
    return unless defined $comment;
    if ( substr($comment,0,1) ne '%' ) {
        seek($self->{fh}, -length($comment), 1);
        return;
    }
    return wantarray ? ($comment,TYPE_COMMENT) : $comment;
}

=item get_num_or_ref($fh,$ch)

Reads a number or reference from the file. A number can be an integer or a real number. A reference is two non-negative
integers separated by a space, followed by 'R' (eg. '0 15 R').  The file pointer is left at the first character after
the number or reference.

If $ch is provided, it is used as the first character of the number or reference.  Otherwise, the first character is
read from the file.

=cut

sub get_num_or_ref {
    my ($self,$ch) = @_;
    my $fh = $self->{fh};
    my $state = 0;
    my ($buf,$num,$ref) = ('',undef,'');
    $ch = getc($fh) unless defined($ch);
    my $last_class = $class_map{$ch};
    while () {
        if ( $ch =~ /[+-.]/ ) {
            # real number detected
            if ($state > 0) {
                # we already got the first number so we're done
                last;
            } else {
                # stop after finding the first number
                $state = -1;
            }
        }
        my $class = $class_map{$ch};
        die "unknown char $ch at offset ".(tell($fh)-1) unless defined($class);
        if ( defined($last_class) && ($class != $last_class or $ch eq '/' ) ) {

            if ( $last_class == CHAR_SPACE ) {
                # skip leading spaces
                $buf = '';
            } elsif ( $last_class == CHAR_NUM ) {
                if ($class != CHAR_SPACE) {
                    # number followed by non-space so we're done
                    $num = $buf unless defined($num);
                    seek($fh, -1, 1);
                    last;
                } elsif ($state == -1) {
                    # found a real number so we're done
                    $num = $buf;
                    last;
                } elsif ($state == 0) {
                    # save the first number and keep looking
                    $num = $buf;
                    $buf = '';
                    $state = 1;
                } elsif ($state == 1) {
                    # found the second number so keep looking
                    $state = 2;
                }
                else {
                    last;
                }
            } elsif ( $last_class == CHAR_ALPHA ) {
                if ( $state == 2 && $buf eq 'R' ) {
                    seek($fh, -1, 1);
                    return wantarray ? ($ref,'ref') : $ref;
                } else {
                    # two numbers but no 'R'
                    last;
                }
            } else {
                last;
            }

        }
        $last_class = $class;
        $buf .= $ch;
        $ref .= $ch;
        last unless defined($ch = getc($fh));
    }
    if ( $state == 2 && $buf eq 'R' ) {
        return wantarray ? ($ref,TYPE_REF) : $ref;
    }

    seek($fh, -length($ref)+length($num), 1);
    return wantarray ? ($num,TYPE_NUM) : $num;
}

sub unquote_name {
    my $value = shift;
    $value =~ s/#([\da-f]{2})/chr(hex($1))/ige;
    return $value;
}

=back

=cut

1;
package Mail::SpamAssassin::PDF::Context;
use strict;
use warnings FATAL => 'all';
use Storable qw(dclone);
use Data::Dumper;
use Carp;

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    $self->reset_state();
    $self;
}

sub reset_state {
    my $self = shift;

    # Graphics state
    $self->{gs} = {
        ctm => [ 1, 0, 0, 1, 0, 0 ], # Current Transformation Matrix
        pos => [ 0, 0 ]
    };

    $self->{stack} = [];
}

sub save_state {
    my $self = shift;
    push(@{$self->{stack}},dclone $self->{gs});
}

sub restore_state {
    my $self = shift;
    $self->{gs} = pop(@{$self->{stack}});
}

#
# This function performs matrix multiplication
# The operands are two 6-element arrays representing the following two 3x3 matrices
#
#   m0  m1  0           n0  n1  0
#   m2  m3  0     X     n2  n3  0
#   m4  m5  1           n4  n5  1
#
sub concat_matrix {
    my ($self,@m) = @_;

    my $n = $self->{gs}->{ctm};

    $self->{gs}->{ctm} = [
        $m[0]*$n->[0] + $m[1]*$n->[2],
        $m[0]*$n->[1] + $m[1]*$n->[3],
        $m[2]*$n->[0] + $m[3]*$n->[2],
        $m[2]*$n->[1] + $m[3]*$n->[3],
        $m[4]*$n->[0] + $m[5]*$n->[2] + $n->[4],
        $m[4]*$n->[1] + $m[5]*$n->[3] + $n->[5]
    ];
}

#
# transform one or more points from user space to device space.
#
# This function performs matrix multiplication between a 1x3 matrix and a 3x3 matrix
#
#                       n0  n1  0
#   m0  m1  1     X     n2  n3  0
#                       n4  n5  1
#
# The result is a 1x3 matrix, of which only the first two values are returned.
# If multiple pairs are provided, multiple pairs are returned.
#
sub transform {
    my $self = shift;
    my $n = $self->{gs}->{ctm};

    my @out;
    while (@_) {
        my($m0,$m1)=(shift,shift);
        push(
            @out,
            $m0*$n->[0] + $m1*$n->[2] + 1*$n->[4],
            $m0*$n->[1] + $m1*$n->[3] + 1*$n->[5]
        );
    }
    return @out;
}

1;
package Mail::SpamAssassin::PDF::Context::Info;
use strict;
use warnings FATAL => 'all';
use Digest::MD5 qw(md5_hex);
use Encode qw(decode);
use Data::Dumper;

our @ISA = qw(Mail::SpamAssassin::PDF::Context);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{info} = {
        ImageCount => 0,
        ColorImageCount => 0,
        PageCount  => 0,
        PageArea   => 0,
        ImageArea  => 0,
        ClickArea  => 0,
        LinkCount  => 0,
        uris       => {}
    };
    $self->{fuzzy_md5} = Digest::MD5->new();
    $self->{fuzzy_md5_data} = '';
    $self;
}

sub get_info {
    my $self = shift;
    return $self->{info};
}

sub parse_begin {
    my ($self,$parser) = @_;

    my $fuzzy_data = $self->serialize_fuzzy($parser->{trailer});
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

}

sub page_begin {
    my ($self, $page) = @_;

    my $fuzzy_data = $self->serialize_fuzzy($page);
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

    $self->{info}->{PageCount}++;

    return 0 unless $page->{page_number} == 1;

    # Calculate page area in user space
    $self->{info}->{PageArea} +=
        ($page->{'/MediaBox'}->[2] - $page->{'/MediaBox'}->[0]) *
        ($page->{'/MediaBox'}->[3] - $page->{'/MediaBox'}->[1]);

    return 1;
}

sub draw_image {
    my ($self,$image,$page) = @_;

    my $is_color = 1;
    $is_color = 0 if defined($image->{'/ColorSpace'}) && $image->{'/ColorSpace'} =~ /gray/i;
    $is_color = 0 if defined($image->{'/BitsPerComponent'}) && $image->{'/BitsPerComponent'} == 1;

    my $fuzzy_data = $self->serialize_fuzzy($image);
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

    $self->{info}->{ImageCount}++;
    $self->{info}->{ColorImageCount}++ if $is_color;

    # Calculate image area in user space
    my $ctm = $self->{gs}->{ctm};
    if ( $ctm->[1] == 0 && $ctm->[2] == 0 ) {
        $self->{info}->{ImageArea} += $ctm->[0] * $ctm->[3];
    } else {
        # Image is rotated, skewed, etc. More complicated
        # The following should be accurate for rotated images but just an approximation for other transformations
        my ($x1,$y1,$x2,$y2) = $self->transform(0,0,1,1);
        $self->{info}->{ImageArea} += abs($x2-$x1) * abs($y2-$y1);
    }

}

sub uri {
    my ($self,$location,$rect,$page) = @_;

    my $fuzzy_data = '/URI';
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

    $self->{info}->{uris}->{$location} = 1;
    $self->{info}->{LinkCount}++;

    if ( defined($rect) ) {
        my ($x1,$y1,$x2,$y2) = @{$rect};
        if ( defined($page->{'/MediaBox'}) ) {
            # clip rectangle to media box
            $x1 = _max($page->{'/MediaBox'}->[0],_min($page->{'/MediaBox'}->[2],$x1));
            $x2 = _max($page->{'/MediaBox'}->[0],_min($page->{'/MediaBox'}->[2],$x2));
            $y1 = _max($page->{'/MediaBox'}->[1],_min($page->{'/MediaBox'}->[3],$y1));
            $y2 = _max($page->{'/MediaBox'}->[1],_min($page->{'/MediaBox'}->[3],$y2));
        }
        $self->{info}->{ClickArea} += abs(($x2-$x1) * ($y2-$y1));
    }
}

sub parse_end {
    my ($self,$parser) = @_;

    $self->{info}->{ImageArea} = _round($self->{info}->{ImageArea},0);
    $self->{info}->{PageArea} = _round($self->{info}->{PageArea},0);
    $self->{info}->{ClickArea} = _round($self->{info}->{ClickArea},0);

    if ( $self->{info}->{PageArea} > 0 ) {
        $self->{info}->{ImageRatio} = _min(100,_round($self->{info}->{ImageArea} / $self->{info}->{PageArea} * 100,2));
        $self->{info}->{ClickRatio} = _min(100,_round($self->{info}->{ClickArea} / $self->{info}->{PageArea} * 100,2));
    } else {
        $self->{info}->{ImageRatio} = 0;
        $self->{info}->{ClickRatio} = 0;
    }

    if ( !$parser->is_protected() ) {
        for (keys %{$parser->{trailer}->{'/Info'}}) {
            my $key = $_;
            $key =~ s/^\///; # Trim leading slash
            $self->{info}->{$key} = $parser->{trailer}->{'/Info'}->{$_};
        }
    }

    $self->{info}->{Encrypted} = $parser->is_encrypted();
    $self->{info}->{Protected} = $parser->is_protected();
    $self->{info}->{Version} = $parser->{version};

    # Compute MD5
    my $md5 = Digest::MD5->new();
    my $core = $parser->{core};
    $core->pos(0);
    $md5->addfile($core->{fh});
    $self->{info}->{MD5} = uc($md5->hexdigest());

    # Compute MD5 Fuzzy1
    $self->{info}->{MD5Fuzzy1} = uc($self->{fuzzy_md5}->hexdigest());

    # Compute MD5 Fuzzy2
    # Start at beginning, get comments + first object
    $md5->reset();
    $core->pos(0);
    my $line;
    while (defined($line = $core->get_line())) {
        next if $line =~ /^\s*$/; # skip blank lines
        last unless $line =~ /^%/;
        # print "> $line\n";
        $md5->add($line);
    }

    if ( $line =~ /^\s*(\d+ \d+ obj\s*)/g ) {
        # print "> $1\n";
        $md5->add($1); # include object number
        my $obj = $parser->{core}->get_primitive();
        my $str = $self->serialize_fuzzy($obj);
        # print "> $str\n";
        $md5->add($str);
    };

    $self->{info}->{MD5Fuzzy2} = uc($md5->hexdigest());


}

sub serialize_fuzzy {
    my ($self,$obj) = @_;

    if ( !defined($obj) ) {
        # undef
        return 'U';
    } elsif ( ref($obj) eq 'ARRAY' ) {
        # recurse into arrays
        my $str = '';
        $str .= $self->serialize_fuzzy($_) for @$obj;
        return $str;
    } elsif ( ref($obj) eq 'HASH' ) {
        # recurse into dictionaries
        my $str = '';
        foreach (sort keys %$obj) {
            next unless /^\//;
            $str .= $_ . $self->serialize_fuzzy( $obj->{$_} );
        }
        return $str;
    } elsif ( $obj =~ /^\d+ \d+ R$/ )  {
        # object reference
        return 'R';
    } elsif ( $obj =~ /^[\d.+-]+$/ ) {
        # number
        return 'N';
    } elsif ( $obj =~ /^D:/ ) {
        # date
        return 'D';
    }

    # replace binary data with the letter 'B'
    eval {
        my $tmp = $obj;
        decode('utf-8-strict',$tmp,Encode::FB_CROAK);
    } or return 'B';

    # include data as-is
    return $obj;

}

sub _round {
    my ($num,$prec) = @_;
    sprintf("%.${prec}f",$num);
}

sub _min {
    my ($x,$y) = @_;
    $x < $y ? $x : $y;
}

sub _max {
    my ($x,$y) = @_;
    $x > $y ? $x : $y;
}

1;
package Mail::SpamAssassin::PDF::Filter::Decrypt;
use strict;
use warnings FATAL => 'all';
use Digest::MD5;
use Crypt::RC4;
use Crypt::Mode::CBC;
use Digest::SHA;
use Carp;
use Data::Dumper;

=head1 ACKNOWLEDGEMENTS

Portions borrowed from CAM::PDF

=cut

my $padding = pack 'C*',
    0x28, 0xbf, 0x4e, 0x5e,
    0x4e, 0x75, 0x8a, 0x41,
    0x64, 0x00, 0x4e, 0x56,
    0xff, 0xfa, 0x01, 0x08,
    0x2e, 0x2e, 0x00, 0xb6,
    0xd0, 0x68, 0x3e, 0x80,
    0x2f, 0x0c, 0xa9, 0xfe,
    0x64, 0x53, 0x69, 0x7a;

sub new {
    my ($class,$encrypt,$doc_id) = @_;

    my $v = $encrypt->{'/V'} || 0;
    my $length = $encrypt->{'/Length'} || 40;

    unless ( $v == 1 || $v == 2 || $v == 4 || $v == 5 ) {
        die "Encryption algorithm $v not implemented";
    }

    my $self = bless {
        R         => $encrypt->{'/R'},
        O         => $encrypt->{'/O'},
        U         => $encrypt->{'/U'},
        P         => $encrypt->{'/P'},
        CF        => $encrypt->{'/CF'},
        V         => $v,
        ID        => $doc_id,
        keylength => ($v == 1 ? 40 : $length),
    }, $class;

    if ( $v == 5 ) {
        $self->{OE} = $encrypt->{'/OE'};
        $self->{UE} = $encrypt->{'/UE'};
    }

    my $password = '';

    if ( !$self->_check_user_password($password) ) {
        croak "Document is password-protected.";
    }

    $self;
}

sub set_current_object {
    my $self = shift;
    $self->{objnum} = shift;
    $self->{gennum} = shift;
}

sub decrypt {
    my ($self,$content) = @_;

    if ( $self->{V} == 4 || $self->{V} == 5 ) {
        # todo: Implement Crypt Filters
        my $iv = substr($content,0,16);
        my $m = Crypt::Mode::CBC->new('AES');
        my $key = $self->{V} == 4 ? $self->_compute_key() : $self->{code};
        return $m->decrypt(substr($content,16),$key,$iv);
    }
    return Crypt::RC4::RC4($self->_compute_key(), $content);

}

#
# Algorithm 3.6 Authenticating the user password
#
sub _check_user_password {
    my ($self,$pass) = @_;
    my ($key,$hash);

    # step 1  Perform all but the last step of Algorithm 3.4 (Revision 2) or Algorithm 3.5 (Revision 3) using the supplied password string.
    if ( $self->{R} == 2 ) {

        # step 1 Create an encryption key based on the user password string, as described in Algorithm 3.2
        $key = $self->_generate_key($pass);

        # step 2 Encrypt the 32-byte padding string using an RC4 encryption function
        $hash = Crypt::RC4::RC4($key,$padding);

        # If the result of step 1 is equal to the value of the encryption dictionary’s U entry
        # (comparing on the first 16 bytes in the case of Revision 3), the password supplied
        # is the correct user password.
        if ( $hash eq $self->{U} ) {
            # Password is valid. Save key for later
            $self->{code} = $key;
            return 1;
        }

    } elsif ( $self->{R} == 3 || $self->{R} == 4 ) {

        #
        # Algorithm 3.5 Computing the encryption dictionary’s U (user password) value (Revision 3)
        #

        # step 1 Create an encryption key based on the user password string, as described in Algorithm 3.2
        $key = $self->_generate_key($pass);

        # step 2 Initialize the MD5 hash function and pass the 32-byte padding string as input to this function
        my $md5 = Digest::MD5->new();
        $md5->add($padding);

        # step 3 Pass the first element of the file’s file identifier array to the hash function
        # and finish the hash.
        $md5->add($self->{ID});
        $hash = $md5->digest();

        # step 4  Encrypt the 16-byte result of the hash, using an RC4 encryption function with the
        # encryption key from step 1
        $hash = Crypt::RC4::RC4($key,$hash);

        # step 5 Do the following 19 times: Take the output from the previous invocation of the
        # RC4 function and pass it as input to a new invocation of the function; use an encryption key generated by
        # taking each byte of the original encryption key (obtained in step 1) and performing an XOR (exclusive or)
        # operation between that byte and the single-byte value of the iteration counter (from 1 to 19).
        my $size = $self->{keylength} >> 3;
        for my $i (1..19) {
            my $xor = chr($i) x $size;
            $hash = Crypt::RC4::RC4($key ^ $xor,$hash);
        }

        # If the result of step 1 is equal to the value of the encryption dictionary’s U entry
        # (comparing on the first 16 bytes in the case of Revision 3), the password supplied
        # is the correct user password.
        if ( $hash eq substr($self->{U},0,16) ) {
            # Password is valid. Save key for later
            $self->{code} = $key;
            return 1;
        }
    } elsif ( $self->{R} == 5 ) {

        # calculate the SHA-256 hash of the password + the User Validation Salt
        my $sha = Digest::SHA->new(256);
        $sha->add($pass);
        $sha->add(substr($self->{U},32,8));
        my $hash = $sha->digest();

        # validate password
        if ($hash ne substr($self->{U}, 0, 32)) {
            return 0;
        }

        # calculate the SHA-256 hash of the password + the User Key Salt (the intermediate key)
        $sha->reset();
        $sha->add($pass);
        $sha->add(substr($self->{U},40,8));
        my $temp_key = $sha->digest();

        # decrypt the File Encryption Key using the intermediate key
        my $m = Crypt::Mode::CBC->new('AES', 0);
        my $iv = "\0" x 16;
        $self->{code} = $m->decrypt($self->{UE},$temp_key,$iv);
        return 1;

    } else {
        croak "Revision $self->{R} not implemented";
    }

    return 0;
}


#
# Algorithm 3.2 Computing an encryption key
#
sub _generate_key {
    my ($self,$pass) = @_;

    # step 1 Pad or truncate the password string to exactly 32 bytes
    $pass = substr($pass.$padding,0,32);

    # step 2 Initialize the MD5 hash function and pass the result of step 1 as input
    my $md5 = Digest::MD5->new;
    $md5->add($pass);

    # step 3 Pass the value of the encryption dictionary’s O entry to the MD5 hash function
    $md5->add($self->{'O'});

    # step 4 Treat the value of the P entry as an unsigned 4-byte integer and pass these bytes to
    # the MD5 hash function, low-order byte first.
    $md5->add(pack('V',$self->{'P'}+0));

    # step 5 Pass the first element of the file’s file identifier array
    $md5->add($self->{ID}) if defined($self->{ID});

    # step 6 (Revision 3 only) If document metadata is not being encrypted, pass 4 bytes with
    # the value 0xFFFFFFFF to the MD5 hash function
    # $md5->add(pack('V',0xFFFFFFFF));

    # step 7 Finish the hash
    my $hash = $md5->digest();

    # step 8 (Revision 3 only) Do the following 50 times: Take the output from the previous
    # MD5 hash and pass it as input into a new MD5 hash.
    if ( $self->{R} >= 3 ) {
        $hash = Digest::MD5::md5($hash) for (1..50);
    }

    # step 9 Set the encryption key to the first n bytes of the output from the final MD5 hash,
    substr($hash,0,$self->{keylength} >> 3)

}

sub _compute_key {
    my ($self) = @_;

    my $id = $self->{objnum} . '_' .$self->{gennum};
    if (!exists $self->{keycache}->{$id}) {
        my $objstr = pack('V', $self->{objnum});
        my $genstr = pack('V', $self->{gennum});

        my $md5 = Digest::MD5->new();
        $md5->add($self->{code});
        $md5->add(substr($objstr, 0, 3).substr($genstr, 0, 2));
        if ( $self->{V} == 4  || $self->{V} == 5 ) {
            $md5->add('sAlT');
        }
        my $hash = $md5->digest();

        my $size = ($self->{keylength} >> 3) + 5;
        $size = 16 if ($size > 16);
        $self->{keycache}->{$id} = substr($hash, 0, $size);
    }
    return $self->{keycache}->{$id};
}

sub _hex {
    my $val = shift;
    return join q{}, map {sprintf '%08x', $_} unpack 'N*', $val;
}

1;

package Mail::SpamAssassin::PDF::Filter::FlateDecode;
use strict;
use warnings FATAL => 'all';
use Compress::Zlib;

sub new {
    my ($class,$params) = @_;

    my $self = {};

    if ( defined($params) ) {
        $self->{predictor} = $params->{'/Predictor'};
        $self->{columns} = $params->{'/Columns'};
    }

    bless $self, $class;
}

sub decode {
    my ($self,$data) = @_;

    $data = uncompress($data);
    return $data unless defined($self->{predictor});

    my $out;
    if ( $self->{predictor} == 1 ) {
        return $data;
    } elsif ( $self->{predictor} == 2 ) {
        die "TIFF Predictor not implemented";
    } elsif ( $self->{predictor} >= 10 ) {

        # PNG Predictor https://www.rfc-editor.org/rfc/rfc2083#section-6
        my $columns = $self->{columns} + 1;
        my $length = length($data);

        my @prior = (0) x ($columns-1);
        for( my $i=0; $i<$length; $i+=$columns ) {
            my @out;
            my ($alg,@row) = unpack("x$i C$columns",$data);

            if ( $alg == 2 ) {
                # PNG "Up" Predictor
                push(@out,($row[$_]+$prior[$_]) & 0xff) for (0..$#row)
            } else {
                die "PNG algorithm $alg not implemented";
            }

            $out .= pack('C*',@out);
            # printf "i=$i prior=%s row=%s out=%s\n",join(',',@prior),join(',',@row),join(',',@out);

            @prior = @out;
        }

    } else {
        die "Unknown predictor $self->{predictor}";
    }

    return $out;

}

1;
package Mail::SpamAssassin::PDF::Filter::ASCII85Decode;
use strict;
use warnings FATAL => 'all';
use Convert::Ascii85;

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub decode {
    my ($self, $data) = @_;
    Convert::Ascii85::decode($data);
}

1;
package Mail::SpamAssassin::PDF::Parser;
use strict;
use warnings FATAL => 'all';
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Carp;

my $debug;  # debugging level

my %abbreviations = (
    '/BPC'  => '/BitsPerComponent',
    '/CS'   => '/ColorSpace',
    '/D'    => '/Decode',
    '/DP'   => '/DecodeParms',
    '/F'    => '/Filter',
    '/H'    => '/Height',
    '/IM'   => '/ImageMask',
    '/I'    => '/Interpolate',
    '/W'    => '/Width',
    '/G'    => '/DeviceGray',
    '/RGB'  => '/DeviceRGB',
    '/CMYK' => '/DeviceCMYK',
    '/AHx'  => '/ASCIIHexDecode',
    '/A85'  => '/ASCII85Decode',
    '/LZW'  => '/LZWDecode',
    '/Fl'   => '/FlateDecode',
    '/RL'   => '/RunLengthDecode',
    '/CCF'  => '/CCITTFaxDecode',
    '/DCT'  => '/DCTDecode'
);

sub new {
    my ($class,%opts) = @_;

    my $self = bless {
        xref         => {},
        trailer      => {},
        pages        => [],
        is_encrypted => 0,
        is_protected => 0,

        context      => $opts{context} || Mail::SpamAssassin::PDF::Context::Info->new(),

        object_cache => {},
        stream_cache => {},

        timeout      => $opts{timeout},
    }, $class;

    $debug = $opts{debug};

    $self;
}

sub parse {
    my ($self,$data) = @_;

    $self->{core} = Mail::SpamAssassin::PDF::Core->new(\$data);

    # Parse header
    $self->{core}->get_line() =~ /^%PDF\-(\d\.\d)/ or croak("PDF magic header not found");
    $self->{version} = $1;

    local $SIG{ALRM} = sub {die "__TIMEOUT__\n"};
    alarm($self->{timeout}) if (defined($self->{timeout}));

    eval {

        # Parse cross-reference table (and trailer)
        $self->_parse_xref($self->{core}->get_startxref());

        # Parse encryption dictionary
        $self->_parse_encrypt($self->{trailer}->{'/Encrypt'}) if defined($self->{trailer}->{'/Encrypt'});

        # Parse info object
        $self->{trailer}->{'/Info'} = $self->_parse_info($self->{trailer}->{'/Info'});
        $self->{trailer}->{'/Root'} = $self->_get_obj($self->{trailer}->{'/Root'});

        # Parse catalog
        my $root = $self->{trailer}->{'/Root'};
        if (defined($root->{'/OpenAction'}) && ref($root->{'/OpenAction'}) eq 'HASH') {
            $self->_parse_action($root->{'/OpenAction'});
        }

        $self->{context}->parse_begin($self) if $self->{context}->can('parse_begin');

        # Parse page tree
        $root->{'/Pages'} = $self->_parse_pages($root->{'/Pages'});

        $self->{context}->parse_end($self) if $self->{context}->can('parse_end');

        1;
    } or do {
        if ( $@ eq "__TIMEOUT__\n" ) {
            croak "Timeout limit exceeded";
        }
        alarm(0);
        die $@;
    };

    alarm(0);

}

sub version {
    shift->{version};
}

sub info {
    shift->{trailer}->{'/Info'};
}

sub is_encrypted {
    shift->{is_encrypted};
}

sub is_protected {
    shift->{is_protected};
}

###################
# Private methods
###################
sub _parse_xref {
    my ($self,$pos) = @_;
    my $core = $self->{core};

    $core->pos($pos);
    my ($token,$type) = $core->get_token();
    if ( $token ne 'xref' ) {
        # not a cross-reference table. May be a cross-reference stream
        if ( $type != Mail::SpamAssassin::PDF::Core::CHAR_NUM ) {
            die "xref not found at offset $pos";
        }
        $core->assert_number();
        $core->assert_token('obj');
        return $self->_parse_xref_stream();
    }

    while () {
        my $start = eval { $core->get_number(); };
        last unless defined($start);
        my $count = $core->get_number();
        for (my ($i,$n)=($start,0);$n<$count;$i++,$n++) {
            my $offset = $core->get_number();
            my $gen = $core->get_number();
            my $type = $core->get_primitive();
            next unless $type eq 'n';
            my $key = "$i $gen R";
            $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
        }
    }

    $core->assert_token('trailer');

    my $trailer = $core->get_dict();
    $self->{trailer} = {
        %{$trailer},
        %{$self->{trailer}}
    };

    if ( defined($trailer->{'/Prev'}) ) {
        return $self->_parse_xref($trailer->{'/Prev'});
    }

    return 1;

}

sub _parse_xref_stream {
    my ($self) = @_;

    my $xref = $self->{core}->get_dict();
    my ($start,$count) = (0,$xref->{'/Size'});
    if ( defined($xref->{'/Index'}) ) {
        $start = $xref->{'/Index'}->[0];
        $count = $xref->{'/Index'}->[1];
    }
    my $width = $xref->{'/W'}->[0] + $xref->{'/W'}->[1] + $xref->{'/W'}->[2];
    my $template = 'H'.($xref->{'/W'}->[0]*2).'H'.($xref->{'/W'}->[1]*2).'H'.($xref->{'/W'}->[2]*2);

    my $data = $self->_get_stream_data($xref);

    for ( my ($i,$n,$o)=($start,0,0); $n<$count; $i++,$n++,$o+=$width ) {
        my ($type,@fields) = map { hex($_) } unpack("x$o $template",$data);
        if ( $type == 0 ) {
            next;
        } elsif ( $type == 1 ) {
            my ($offset,$gen) = @fields;
            my $key = "$i $gen R";
            $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
        } elsif ( $type == 2 ) {
            my ($obj,$index) = @fields;
            my $key = "$i 0 R";
            $self->{xref}->{$key} = [ "$obj 0 R", $index ] unless defined($self->{xref}->{$key});
        }
    }

    $self->{trailer} = $xref;

    if ( defined($xref->{'/Prev'}) ) {
        $self->_parse_xref($xref->{'/Prev'});
    }

    return 1;

}

sub _parse_encrypt {
    my ($self,$encrypt) = @_;
    $encrypt = $self->_dereference($encrypt);
    return unless defined($encrypt);

    if ( $encrypt->{'/Filter'} ne '/Standard' ) {
        die "Encryption filter $encrypt->{'/Filter'} not implemented";
    }

    $self->{core}->{crypt} = eval {
        Mail::SpamAssassin::PDF::Filter::Decrypt->new($encrypt,$self->{trailer}->{'/ID'}->[0]);
    };
    if ( !defined($self->{core}->{crypt}) ) {
        die $@ unless $@ =~ /password/;
        $self->{is_protected} = 1;
    }
    $self->{is_encrypted} = 1;

}

sub _parse_info {
    my ($self,$info) = @_;
    $info = $self->_dereference($info);
    return unless defined($info);

    foreach (keys %{$info}) {
        $info->{$_} = $self->_dereference($info->{$_});
    }

    return $info;
}

sub _parse_pages {
    my ($self,$node,$parent_node) = @_;
    $node = $self->_dereference($node);
    return unless defined($node);

    # inherit properties
    $parent_node = {} unless defined($parent_node);
    for (qw(/MediaBox /Resources) ) {
        $node->{$_} = $parent_node->{$_} unless defined($node->{$_});
    }

    if ( $node->{'/Type'} eq '/Pages' ) {
        $self->_parse_pages($_, $node) for (@{$node->{'/Kids'}});
    } elsif ( $node->{'/Type'} eq '/Page' ) {
        $node->{'/MediaBox'} = $self->_dereference($node->{'/MediaBox'});
        my $process_page = 1;
        push @{$self->{pages}}, $node;
        $node->{page_number} = scalar(@{$self->{pages}});

        # call page begin handler
        $process_page = $self->{context}->page_begin($node) if $self->{context}->can('page_begin');

        if ( $process_page ) {
            $self->_parse_annotations($node->{'/Annots'},$node) if (defined($node->{'/Annots'}));
            $node->{'/Resources'} = $self->_parse_resources($node->{'/Resources'}) if (defined($node->{'/Resources'}));
            $self->_parse_contents($node->{'/Contents'},$node) if (defined($node->{'/Contents'}));

            # call page end handler
            $self->{context}->page_end($node) if $self->{context}->can('page_end');
        }

    } else {
        die "Unexpected page type";
    }

    return $node;

}

sub _parse_annotations {
    my ($self,$annots,$page) = @_;
    $annots = $self->_dereference($annots);
    return unless defined($annots);

    for my $ref (@$annots) {
        my $annot = $self->_dereference($ref);
        if ( defined($annot->{'/Subtype'}) && $annot->{'/Subtype'} eq '/Link' && defined($annot->{'/A'}) ) {
            $self->_parse_action($annot->{'/A'},$annot->{'/Rect'},$page);
        }
    }

}

sub _parse_action {
    my ($self,$action,$rect,$page) = @_;
    $action = $self->_dereference($action);
    return unless defined($action);

    if ( $action->{'/S'} eq '/URI' ) {
        my $location = $action->{'/URI'};
        if ( $location =~ /^\w+:/ ) {
            $self->{context}->uri($location,$rect,$page) if $self->{context}->can('uri');
        }
    }

    if ( defined($action->{'/Next'}) ) {
        # can be array or dict
        if ( ref($action->{'/Next'}) eq 'ARRAY' ) {
            $self->_parse_action($_) for @{$action->{'/Next'}};
        } else {
            $self->_parse_action($action->{'/Next'});
        }
    }

}

sub _parse_resources {
    my ($self,$resources) = @_;
    $resources = $self->_dereference($resources);
    return unless defined($resources);

    $resources->{'/XObject'} = $self->_parse_xobject($resources->{'/XObject'}) if (defined($resources->{'/XObject'}));
    return $resources;
}

sub _parse_xobject {
    my ($self,$xobject) = @_;
    $xobject = $self->_dereference($xobject);
    return unless defined($xobject);

    for my $name (keys %$xobject) {
        my $ref = $xobject->{$name};
        my $obj = $xobject->{$name} = $self->_dereference($ref);
        if ( $obj->{'/Subtype'} eq '/Image' ) {
            $obj->{'/ColorSpace'} = $self->_dereference($obj->{'/ColorSpace'});
        } elsif ( $obj->{'/Subtype'} eq '/Form' ) {
            $obj->{'/Resources'} = $self->_parse_resources($obj->{'/Resources'}) if (defined($obj->{'/Resources'}));
        }
    }
    return $xobject;
}

sub _parse_contents {
    my ($self,$contents,$page,$resources) = @_;
    return if $self->is_protected();

    $resources = $self->_dereference($resources) || $page->{'/Resources'};

    #@type Mail::SpamAssassin::PDF::Context
    my $context = $self->{context};
    my @params;

    # Build a dispatch table
    my %dispatch = (
        q  => sub { $context->save_state() },
        Q  => sub { $context->restore_state() },
        cm => sub { $context->concat_matrix(@_) },
        Do => sub {
            my $xobj = $resources->{'/XObject'}->{$_[0]};
            die "XObject $_[0] not found: " unless (defined($xobj));
            $xobj->{_name} = $_[0];
            if ( $xobj->{'/Subtype'} eq '/Image' ) {
                $context->draw_image($xobj,$page) if $self->{context}->can('draw_image');
            } elsif ( $xobj->{'/Subtype'} eq '/Form' ) {
                $context->save_state();
                $context->concat_matrix(@{$xobj->{'/Matrix'}}) if defined($xobj->{'/Matrix'});
                $self->_parse_contents($xobj, $page, $xobj->{'/Resources'});
                $context->restore_state();
            }
        }
    );

    if ( $context->isa('Mail::SpamAssassin::PDF::Context::Image') ) {
        $dispatch{re} = sub { $context->rectangle(@_) };
        $dispatch{m}  = sub { $context->path_move(@_) };
        $dispatch{l}  = sub { $context->path_line(@_) };
        $dispatch{h}  = sub { $context->path_close() };
        $dispatch{n}  = sub { $context->path_end() };
        $dispatch{c}  = sub { $context->path_curve(@_) };
        $dispatch{v}  = sub {
            splice @_,0,0,undef,undef;
            $context->path_curve(@_)
        };
        $dispatch{y}  = sub {
            splice @_,2,0,undef,undef;
            $context->path_curve(@_);
        };
        $dispatch{s}  = sub {
            $context->path_close();
            $context->path_draw(1,0);
        };
        $dispatch{S}    = sub { $context->path_draw(1,0) };
        $dispatch{f}    = sub { $context->path_draw(0,'nonzero') };
        $dispatch{'f*'} = sub { $context->path_draw(0,'evenodd') };
        $dispatch{B}    = sub { $context->path_draw(1,'nonzero') };
        $dispatch{'B*'} = sub { $context->path_draw(1,'evenodd') };
    }

    if ( $context->isa('Mail::SpamAssassin::PDF::Context::Text') ) {
        $dispatch{Tf} = sub {
            my $font = $self->_dereference($resources->{'/Font'}->{$_[0]});
            my $cmap = Mail::SpamAssassin::PDF::Filter::CharMap->new();
            if (defined($font->{'/ToUnicode'})) {
                $cmap->parse_stream($self->_get_stream_data($font->{'/ToUnicode'}));
            }
            $context->text_font($font, $cmap);
        };
        $dispatch{Tj} = sub { $context->text(@_) };
        $dispatch{Td} = sub { $context->text_newline(@_) };
        $dispatch{TD} = sub { $context->text_newline(@_) };
        $dispatch{'T*'} = sub { $context->text_newline(@_) };
    }

    # Contents can be one of the following:
    # 1. Reference to a content stream i.e. "35 0 R"
    # 2. An array of content stream references i.e. [ "35 0 R", "36 0 R" ]
    # 3. A reference to an array of content streams i.e. "6 0 R" which points to [ "35 0 R", "36 0 R" ]
    # Convert all of the above to an array ref:
    if (ref($contents) ne 'ARRAY') {
        # reference to something
        my $obj = $self->_get_obj($contents);
        if ( ref($obj) eq 'ARRAY' ) {
            # reference to an array (#3)
            $contents = $obj;
        } else {
            # reference to a content stream (#1)
            $contents = [ $contents ];
        }
    }

    # Concatenate content streams
    my $stream = '';
    for my $obj ( @$contents ) {
        $stream .= $self->_get_stream_data($obj);
    }
    debug('stream',$stream);

    my $core = $self->{core}->clone(\$stream);

    # Process commands
    while () {
        my ($token,$type) = $core->get_primitive();
        last unless defined($token);
        # print "$type: $token\n";
        next if $type == Mail::SpamAssassin::PDF::Core::TYPE_COMMENT;
        if ( $type != Mail::SpamAssassin::PDF::Core::TYPE_OP ) {
            push(@params,$token);
            next;
        }
        if ( $token eq 'BI' ) {
            my $image = $self->_parse_inline_image($core);
            $context->draw_image($image,$page) if $self->{context}->can('draw_image');
            next;
        }
        if ( defined($dispatch{$token}) ) {
            $dispatch{$token}->(@params);
        }
        @params = ();
    }

}

sub _parse_inline_image {
    my ($self,$core) = @_;

    my @array;
    while () {
        my $token = $core->get_primitive();
        last if $token eq 'ID';
        $token = $abbreviations{$token} if defined($abbreviations{$token});
        push(@array,$token);
    }
    my %image = @array;

    # skip over image data
    local $/ = "\nEI";
    readline $core->{fh};

    return \%image;
}

sub _get_obj {
    my ($self,$ref) = @_;
    my $core = $self->{core};

    # return undef for non-existent objects
    return undef unless defined($ref) && defined($self->{xref}->{$ref});

    if ( !defined($self->{object_cache}->{$ref}) ) {
        my ($objnum,$gennum) = $ref =~ /^(\d+) (\d+) R$/;
        if (defined($core->{crypt})) {
            $core->{crypt}->set_current_object($objnum, $gennum);
        }

        my $obj;
        if ( ref($self->{xref}->{$ref}) eq 'ARRAY' ) {
            my ($stream_obj_ref,$index) = @{$self->{xref}->{$ref}};
            $obj = $self->_get_compressed_obj($stream_obj_ref,$index,$ref);
        } else {
            $core->pos($self->{xref}->{$ref});
            eval {
                $core->get_number();
                $core->get_number();
                $core->assert_token('obj');
                $obj = $core->get_primitive();
            } or die "Error getting object $ref: $@";
        }
        if ( ref($obj) eq 'HASH' and defined($obj->{_stream_offset}) ) {
            # stream object. Store object number for decryption later
            $obj->{_objnum} = $objnum;
            $obj->{_gennum} = $gennum;
        }
        $self->{object_cache}->{$ref} = $obj;
    }

    return $self->{object_cache}->{$ref};
}

sub _dereference {
    my ($self,$obj) = @_;
    while ( defined($obj) && !ref($obj) && $obj =~ /^\d+ \d+ R$/ ) {
        $obj = $self->_get_obj($obj);
    }
    return $obj;
}

sub _get_compressed_obj {
    my ($self,$stream_obj_ref,$index,$ref) = @_;

    $ref =~ /^(\d+)/ or die "invalid object reference";
    my $obj = $1;

    my $stream_obj = $self->_get_obj($stream_obj_ref);

    if ( !defined($stream_obj->{core}) ) {
        my $data = $self->_get_stream_data($stream_obj);
        my $core = $stream_obj->{core} = $self->{core}->clone(\$data);
        my @array;
        while ( defined($_ = $core->get_number()) ) {
            push(@array,$_);
        }
        $stream_obj->{xref} = { @array };
        $stream_obj->{pos} = $core->pos();
    }

    $stream_obj->{core}->pos($stream_obj->{pos}+$stream_obj->{xref}->{$obj});
    return $self->{object_cache}->{$ref} = $stream_obj->{core}->get_primitive();
}

sub _get_stream_data {
    my ($self,$stream_obj) = @_;
    $stream_obj = $self->_dereference($stream_obj);
    return unless defined($stream_obj);

    # not a stream object
    return undef unless ref($stream_obj) eq 'HASH' && defined($stream_obj->{_stream_offset});

    my $offset = $stream_obj->{_stream_offset};
    my $length = $self->_dereference($stream_obj->{'/Length'});
    my @filters = !defined($stream_obj->{'/Filter'}) ? ()
        : ref($stream_obj->{'/Filter'}) eq 'ARRAY' ? @{$stream_obj->{'/Filter'}}
        : ( $stream_obj->{'/Filter'} );

    # check for cached version
    return $self->{stream_cache}->{$offset} if defined($self->{stream_cache}->{$offset});

    $self->{core}->pos($offset);
    read($self->{core}->{fh},my $stream_data,$length);
    if (defined($self->{core}->{crypt})) {
        $self->{core}->{crypt}->set_current_object($stream_obj->{_objnum}, $stream_obj->{_gennum});
        $stream_data = $self->{core}->{crypt}->decrypt($stream_data);
    }
    $self->{core}->assert_token('endstream');

    foreach my $filter (@filters) {
        if ( $filter eq '/FlateDecode' ) {
            my $f = Mail::SpamAssassin::PDF::Filter::FlateDecode->new($stream_obj->{'/DecodeParms'});
            $stream_data = $f->decode($stream_data);
        } elsif ( $filter eq '/ASCII85Decode' ) {
            my $f = Mail::SpamAssassin::PDF::Filter::ASCII85Decode->new();
            $stream_data = $f->decode($stream_data);
        } else {
            die "Filter $filter not implemented";
        }
    }

    return $self->{stream_cache}->{$offset} = $stream_data;

}

sub debug {
    my $level = shift;
    return if !defined($debug);
    if ( $debug eq $level || $debug eq 'all' ) {
        for (@_) {
            print STDERR (ref($_) ? Dumper($_) : $_),"\n";
        }
    }
}


1;


package Mail::SpamAssassin::Plugin::PDFInfo2;

use Mail::SpamAssassin::Plugin;
use Mail::SpamAssassin::Logger ();
use Mail::SpamAssassin::Util qw(compile_regexp);
use strict;
use warnings;
use re 'taint';
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

my $VERSION = 0.21;

our @ISA = qw(Mail::SpamAssassin::Plugin);

sub log_dbg  { Mail::SpamAssassin::Logger::dbg ("pdfinfo2: @_"); }
sub log_warn { Mail::SpamAssassin::Logger::log_message('warn', "pdfinfo2: @_"); }

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
    $self->register_method_priority('post_message_parse', -1);

    return $self;
}

sub post_message_parse {
    my ($self, $opts) = @_;

    my $msg = $opts->{'message'};
    my $errors = 0;

    $msg->{pdfparts} = [];
    foreach my $p ($msg->find_parts(qr/./,1)) {
        my $type = $p->{type} || '';
        my $name = $p->{name} || '';

        next unless $type =~ qr/\/pdf$/ or $name =~ /\.pdf$/i;

        log_dbg("found part, type=$type file=$name");
        push(@{$msg->{pdfparts}},$p);

        # Get raw PDF data
        my $data = $p->decode();
        next unless $data;

        # Parse PDF
        my $pdf = Mail::SpamAssassin::PDF::Parser->new(timeout => 5);
        my $info = eval {
            $pdf->parse($data);
            $pdf->{context}->get_info();
        };
        if ( !defined($info) ) {
            log_warn("Error parsing pdf: $@");
            $errors++;
            next;
        }

        $p->{pdfinfo2} = $info;

    }
    $msg->put_metadata('X-PDFInfo2-Errors',$errors);

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

    foreach my $p (@{ $pms->{msg}->{pdfparts} }) {

        my $name = $p->{name} || '';
        _set_tag($pms, 'PDF2NAME', $name);
        $pms->{pdfinfo2}->{totals}->{FileCount}++;

        my $info = $p->{pdfinfo2};
        next unless defined $info;

        # Add URI's
        foreach my $location ( keys %{ $info->{uris} }) {
            log_dbg("found URI: $location");
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

        _set_tag($pms, 'PDF2PRODUCER', $info->{Producer});
        _set_tag($pms, 'PDF2AUTHOR', $info->{Author});
        _set_tag($pms, 'PDF2CREATOR', $info->{Creator});
        _set_tag($pms, 'PDF2TITLE', $info->{Title});
        _set_tag($pms, 'PDF2IMAGERATIO', $info->{ImageRatio});
        _set_tag($pms, 'PDF2CLICKRATIO', $info->{ClickRatio});
        _set_tag($pms, 'PDF2VERSION', $info->{Version} );

        $pms->{pdfinfo2}->{md5}->{$info->{MD5}} = 1;
        $pms->{pdfinfo2}->{fuzzy_md5}->{$info->{MD5Fuzzy1}} = 1;
        $pms->{pdfinfo2}->{fuzzy_md5}->{$info->{MD5Fuzzy2}} = 1;
        _set_tag($pms, 'PDF2MD5', $info->{MD5});
        _set_tag($pms, 'PDF2MD5FUZZY1', $info->{MD5Fuzzy1});
        _set_tag($pms, 'PDF2MD5FUZZY2', $info->{MD5Fuzzy2});

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
    log_dbg("set_tag called for $tag: $value");

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
            log_dbg("pdf2_match_details $detail ($regex) match: $_");
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