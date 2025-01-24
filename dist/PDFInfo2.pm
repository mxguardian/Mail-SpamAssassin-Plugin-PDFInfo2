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

=item Unlike the original plugin, this plugin can parse compressed data streams to analyze images and text

=item It can parse PDF's that are encrypted with a blank password

=item Several of the tests focus exclusively on page 1 of each document. This not only helps with performance but is a countermeasure against content stuffing

=item pdf2_click_ratio - Fires based on how much of page 1 is clickable (as a percentage of total page area)

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

Additionally, if you want to analyze text from PDF's you will need to install L<pdftotext|https://poppler.freedesktop.org/>
and enable it using the L<Mail::SpamAssassin::Plugin::ExtractText|https://spamassassin.apache.org/full/4.0.x/doc/Mail_SpamAssassin_Plugin_ExtractText.html> plugin.

=head1 INSTALLATION

=head3 Manual method

Copy all the files in the C<dist/> directory to your site rules directory (e.g. C</etc/mail/spamassassin>)

=head3 Automatic method

TBD

=head1 SYNOPSIS

  loadplugin     Mail::SpamAssassin::Plugin::PDFInfo2

=head1 EVAL RULES

This plugin defines the following eval rules:

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

  pdf2_is_encrypted_blank_pw()

     body RULENAME eval:pdf2_is_encrypted_blank_pw()

        Fires if any PDF attachment is encrypted with a blank password

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

=head1 TEXT RULES

To match against text extracted from PDF's, use the following syntax:

    pdftext  RULENAME   /regex/
    score    RULENAME   1.0
    describe RULENAME   PDF contains text matching /regex/

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

This plugin creates a new "pdf" URI type. You can detect URI's in PDF's using the L<URIDetail|https://spamassassin.apache.org/full/4.0.x/doc/Mail_SpamAssassin_Plugin_URIDetail.html> plugin. For example:

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
use constant CHAR_DELIM1           => 1;
use constant CHAR_DELIM2           => 2;
use constant CHAR_REGULAR           => 3;

use constant TYPE_NUM     => 0;
use constant TYPE_OP      => 1;
use constant TYPE_STRING  => 2;
use constant TYPE_NAME    => 3;
use constant TYPE_REF     => 4;
use constant TYPE_ARRAY   => 5;
use constant TYPE_DICT    => 6;
use constant TYPE_STREAM  => 7;
use constant TYPE_COMMENT => 8;
use constant TYPE_BOOL    => 9;
use constant TYPE_NULL    => 10;

my %specials = (
    'n' => "\n",
    'r' => "\r",
    't' => "\t",
    'b' => "\b",
    'f' => "\f",
);

my %class_map;
$class_map{chr($_)} = CHAR_REGULAR  for 0x21..0xFF;
$class_map{$_} = CHAR_SPACE         for split //, " \n\r\t\f\x{00}";
$class_map{$_} = CHAR_DELIM1        for split //, '[]()%/';
$class_map{$_} = CHAR_DELIM2        for split //, '<>';

=item new($fh)

Creates a new instance of the object.  $fh is an open file handle to the PDF file or a reference to a scalar containing
the contents of the PDF file.

=cut

sub new {
    my $class = shift;
    my $self = bless {},$class;
    $self->_init(@_);

    # Look for PDF header
    #
    # According to the standard, this should be the first 5 bytes of the file, but some PDFs have extraneous data
    # at the beginning. Acrobat Reader seems to be able to handle this, so we will too.
    my $fh = $self->{fh};
    { local $/ = "%PDF-"; readline($fh); }
    croak("PDF header not found") if eof($fh);

    $self->{starting_offset} = tell($fh) - 5;
    $self->{version} = $self->get_number();
    croak("Invalid version number") unless defined($self->{version});

    return $self;
}

=item clone($fh)

Returns a new instance of the object with the same state as the original, but
using the new file handle. This is useful for parsing objects within objects.

=cut

sub clone {
    my $self = shift;
    my $copy = bless { %$self }, ref $self;
    $copy->_init(@_);
    # Disable encryption for cloned objects. The parent object is already decrypted.
    undef $copy->{crypt};
    return $copy;
}

=item pos($offset)

Sets the file pointer to the specified offset.  If no offset is specified, returns the current offset.

=cut

sub pos {
    my ($self,$offset) = @_;
    defined($offset)
        ? seek($self->{fh},$offset+$self->{starting_offset},0)
        : tell($self->{fh}) - $self->{starting_offset};
}

=item get_number

Reads a number from the file.  A number can be an integer or a real number. Returns undef if no number is found.

=cut

sub get_number {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $offset = $self->pos();
    my $num = $self->get_token();
    return unless defined($num);

    if ( $num !~ /^[0-9+.-]+$/ ) {
        # not a number
        $self->pos($offset);
        return;
    }

    $num += 0;
    return wantarray ? ($num,TYPE_NUM) : $num;
}

=item assert_number($num)

Get the next token from the file and croak if it isn't a number.  If $num is specified, croak if the number doesn't
match $num.

=cut

sub assert_number {
    my ($self,$num) = @_;
    my $fh = $self->{fh};

    my $offset = $self->pos();
    my $token = $self->get_token();
    if (!defined($token) ) {
        # EOF
        croak "Expected number, got EOF";
    }

    if ($token !~ /^[0-9+.-]+$/ ) {
        # not a number
        $self->pos($offset);
        croak "Expected number, got '$token' at offset $offset";
    }

    $token += 0;
    if ( defined($num) && $token != $num ) {
        # not the expected number
        $self->pos($offset);
        croak "Expected number '$num', got '$token' at offset $offset";
    }

}

=item assert_token($literal)

Get the next token from the file and croak if it doesn't match the specified literal.

=cut

sub assert_token {
    my ($self,$literal) = @_;
    my $fh = $self->{fh};

    my $offset = $self->pos();
    my $token = $self->get_token();
    if (!defined($token) ) {
        croak "Expected '$literal', got EOF";
    }
    if ($token ne $literal) {
        $self->pos($offset);
        croak "Expected '$literal', got '$token' at offset $offset";
    }
    1;
}

=item get_token

Get the next token from the file as a string of characters. Will skip leading spaces and comments. Returns undef if
there are no more tokens. Will croak if an invalid character is encountered or if the token is too long.

=cut

sub get_token {
    my ($self) = @_;
    my $fh = $self->{fh};

    # Max token length. This is to prevent reading the entire file into memory if the file is corrupt or if the
    # file pointer is not set correctly.
    my $limit = 256;

    my $token;
    while (defined(my $ch = getc($fh))) {
        my $class = $class_map{$ch};
        unless (defined($class)) {
            seek($fh, -1, 1);
            croak "Invalid character '$ch' at offset " . tell($fh);
        }
        if ( $class == CHAR_SPACE ) {
            if ( defined($token) ) {
                last;
            } else {
                # skip leading whitespace
                next;
            }
        }
        if ( $class == CHAR_DELIM1 ) {
            if ( defined($token) ) {
                seek($fh, -1, 1);
                last;
            } else {
                return $ch;
            }
        }
        if ( $class == CHAR_DELIM2 ) {
            if (defined($token)) {
                seek($fh, -1, 1);
                last;
            } else {
                my $ch2 = getc($fh);
                if (defined($ch2) && $ch2 eq $ch) {
                    return $ch . $ch2;
                } else {
                    seek($fh, -1, 1);
                    return $ch;
                }
            }
        }
        $token .= $ch;
        die "Invalid token length at offset ".tell($fh) if $limit-- == 0;
    }

    return $token;
}

=item get_primitive

Reads a primitive object from the file.  A primitive object can be a number, string, name, array, dictionary,
or reference.

=cut

sub get_primitive {
    my ($self) = @_;
    my $fh = $self->{fh};

NEXT_TOKEN:
    my $token = $self->get_token();
    return unless defined($token);
    if ( $token eq '/' ) {
        return $self->_get_name();
    }
    if ( $token eq '<' ) {
        return $self->_get_hex_string();
    }
    if ( $token eq '(' ) {
        return $self->_get_string();
    }
    if ( $token eq '[' ) {
        return $self->_get_array();
    }
    if ( $token eq '<<' ) {
        return $self->_get_dict();
    }
    if ( $token eq '%' ) {
        # skip comments
        $self->get_line();
        goto NEXT_TOKEN;
    }
    if ( $token =~ /^[0-9]+$/ ) {
        my $offset = $self->pos();
        my $t2 = $self->get_token();
        if ( defined($t2) && $t2 =~ /^[0-9]+$/ ) {
            my $t3 = $self->get_token();
            if ( defined($t3) && $t3 eq 'R') {
                $token = $token . ' ' . $t2 . ' ' . $t3;
                return wantarray ? ($token,TYPE_REF) : $token;
            }
        }
        $self->pos($offset);
        return wantarray ? ($token,TYPE_NUM) : $token;
    }
    if ( $token =~ /^[0-9.+-]+$/ ) {
        return wantarray ? ($token,TYPE_NUM) : $token;
    }
    if ( $token =~ /^true|false$/ ) {
        return wantarray ? ($token,TYPE_BOOL) : $token;
    }
    if ( $token =~ /^null$/ ) {
        return wantarray ? ($token,TYPE_NULL) : $token;
    }

    return wantarray ? ($token,TYPE_OP) : $token;


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

sub get_version {
    my ($self) = @_;
    return $self->{version};
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

    croak "EOF marker not found" unless $tok eq 'startxref';

    my $xref = $self->get_number();
    croak "Invalid startxref" unless defined($xref);

    eval {
        $self->assert_token('%');
        $self->assert_token('%');
        $self->assert_token('EOF');
        1;
    } or do {
        croak "EOF marker not found";
    };

    return $xref;

}

=item get_string

Reads a string from the file.  A string is a sequence of characters enclosed in parentheses.

=cut


sub get_string {
    my ($self) = @_;
    $self->assert_token('(');
    return $self->_get_string();
}

=item get_hex_string

Reads a hex string from the file.  A hex string is a sequence of hexadecimal digits enclosed in angle brackets with
optional whitespace between the digits. If there is an odd number of hex digits, a zero is appended to the string. The
string is then converted to binary and decrypted if necessary. If the string begins with a byte order mark (BOM), it
is converted to UTF-8.

=cut

sub get_hex_string {
    my ($self) = @_;
    $self->assert_token('<');
    return $self->_get_hex_string();
}

=item get_array

Reads an array from the file.  An array is a sequence of objects enclosed in square brackets.

=cut

sub get_array {
    my ($self) = @_;
    $self->assert_token('[');
    return $self->_get_array();
}

=item get_dict

Reads a dictionary from the file.  A dictionary is a sequence of key/value pairs enclosed in double angle brackets.

=cut

sub get_dict {
    my ($self) = @_;
    $self->assert_token('<<');
    return $self->_get_dict();
}

=item get_name

Reads a name from the file.  A name is a sequence of characters beginning with a slash. A name can contain any
character except whitespace and the characters ()<>[]{}/%. Any character except null (character code 0) may be included
in a name by writing its 2-digit hexadecimal code, preceded by the number sign character (#)

=cut

sub get_name {
    my ($self) = @_;
    $self->assert_token('/');
    return $self->_get_name();
}

########################################################################
# Internal methods
########################################################################

sub _init {
    my $self = shift;
    if (ref($_[0]) eq 'SCALAR') {
        # scalar ref, open it as a file
        open(my $fh, '<', $_[0]) or croak "Error opening scalar as file handle: $!";
        binmode($fh);
        $self->{fh} = $fh;
    } elsif (ref($_[0]) eq 'GLOB') {
        $self->{fh} = $_[0];
    } elsif (ref($_[0]) eq '' ) {
        # filename
        open(my $fh, '<', $_[0]) or croak "Error opening file $_[0]: $!";
        binmode($fh);
        $self->{fh} = $fh;
    } else {
        croak "Invalid file handle";
    }
    $self->{pos} = 0;
    $self->{starting_offset} = 0;
}

sub _get_string {
    my ($self) = @_;
    my $fh = $self->{fh};

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

    return wantarray ? ($str,TYPE_STRING) : $str;
}

sub _get_hex_string {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $hex = '';
    while ( defined(my $ch = getc($fh)) ) {
        last if $ch eq '>';
        next if $ch =~ /\s/; # skip whitespace
        croak "Invalid hex string at offset " . tell($fh) unless $ch =~ /[0-9a-fA-F]/;
        $hex .= $ch;
    }
    # pad with a zero if the length is odd
    $hex .= '0' if length($hex) % 2;
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

=item _get_array

Reads an array from the file.  An array is a sequence of objects enclosed in square brackets.  The file pointer is left
at the first character after the array.

=cut

sub _get_array {
    my ($self) = @_;
    my @array;

    while () {
        local $_ = $self->get_primitive();
        croak "Unexpected end of file" unless defined($_);
        last if $_ eq ']';
        push(@array,$_);
    }

    return wantarray ? (\@array,TYPE_ARRAY) : \@array;
}

sub _get_dict {
    my ($self) = @_;
    my $fh = $self->{fh};
    my @array;

    while () {
        local $_ = $self->get_primitive();
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
    # get_line() will handle all of these cases for us

    if ( exists($dict{'/Length'})) {
        # check for stream data following the dictionary
        my $offset = $self->pos();
        while (defined(my $line = $self->get_line())) {
            next if $line =~ /^\s*$/; # skip blank lines
            if ($line =~ /^\s*stream\b/) {
                $dict{_stream_offset} = $self->pos();
                return wantarray ? (\%dict, TYPE_STREAM) : \%dict;
            }
            last;
        }
        # not a stream dictionary
        $self->pos($offset);
    }

    return wantarray ? (\%dict,TYPE_DICT) : \%dict;

}

sub _get_name {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $name = '/';
    while ( defined(my $ch = getc($fh)) ) {
        my $class = $class_map{$ch};
        unless (defined($class)) {
            seek($fh, -1, 1);
            croak "Invalid character '$ch' at offset " . tell($fh);
        }
        last if $class == CHAR_SPACE;
        if ( $class != CHAR_REGULAR ) {
            seek($fh, -1, 1);
            last;
        }
        $name .= $ch;
    }
    $name =~ s/#([0-9a-fA-F]{2})/chr(hex($1))/ge;

    return wantarray ? ($name,TYPE_NAME) : $name;

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
    croak "Stack underflow" unless @{$self->{stack}};
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
    $self;
}

sub get_info {
    my $self = shift;
    return $self->{info};
}

sub parse_begin {
    my ($self,$parser) = @_;

    $self->add_fuzzy('V:'.$parser->{version});

    my %trailer = %{$parser->{trailer}};
    delete $trailer{'/ID'};
    $self->add_fuzzy(\%trailer);
}

sub page_begin {
    my ($self, $page) = @_;

    $self->add_fuzzy($page);

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

    $self->add_fuzzy($image);

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

    $self->add_fuzzy('\URI');

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
    my $line; my $pos = 0;
    while (defined($line = $core->get_line())) {
        next if $line =~ /^\s*$/; # skip blank lines
        last unless $line =~ /^%/;
        # print "> $line\n";
        $md5->add($line);
        $pos += length($line);
    }

    if ( $line =~ /^\s*(\d+) (\d+) (obj\s*)/g ) {
        $core->pos($pos + $+[3]);
        $md5->add("$1 $2 $3"); # include object number
        $core->{crypt}->set_current_object($1,$2) if defined($core->{crypt});
        my $obj = $core->get_primitive();
        my $str = $self->serialize_fuzzy($obj);
        # print "> $str\n";
        $md5->add($str);
    };

    $self->{info}->{MD5Fuzzy2} = uc($md5->hexdigest());


}

sub add_fuzzy {
    my ($self,$obj) = @_;
    my $data = $self->serialize_fuzzy($obj);
    $self->{fuzzy_md5}->add( $data );
    # print "Fuzzy: $data\n";
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
    } elsif ( $obj =~ /^[\d.+-]+$/ ) {
        # number
        return 'N';
    } elsif ( $obj =~ /^D:/ ) {
        # date
        return 'D';
    }

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

    return $content unless defined($content) && length($content);

    eval {

        if ( $self->{V} == 4 || $self->{V} == 5 ) {
            # todo: Implement Crypt Filters besides the standard one
            if ( $self->{CF}->{'/StdCF'}->{'/CFM'} eq '/AESV2' ) {
                my $iv = substr($content,0,16);
                my $m = Crypt::Mode::CBC->new('AES');
                my $key = $self->_compute_key();
                return $m->decrypt(substr($content,16),$key,$iv);
            }
        }
        return Crypt::RC4::RC4($self->_compute_key(), $content);

    } or do {
        my $err = $@;
        $err =~ s/\n//g;
        croak "Error decrypting object $self->{objnum} $self->{gennum}: $err";
    };

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
        $md5->add($self->{ID}) if defined($self->{ID});
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
            $md5->add('sAlT') if $self->{CF}->{'/StdCF'}->{'/CFM'} eq '/AESV2';
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
# use Compress::Zlib;
use Compress::Raw::Zlib qw(Z_OK Z_STREAM_END);

sub new {
    my ($class,$params) = @_;

    my $self = {};

    if ( defined($params) && $params ne 'null' ) {
        $self->{predictor} = $params->{'/Predictor'};
        $self->{columns} = $params->{'/Columns'};
    }

    bless $self, $class;
}

sub decode {
    my ($self,$data) = @_;

    my $i = new Compress::Raw::Zlib::Inflate( -ConsumeInput => 0 );
    my $uncompressed = '';
    my $status = $i->inflate($data,$uncompressed);
    unless ( $status == Z_OK || $status == Z_STREAM_END ) {
        die "Error inflating data: " . $i->msg;
    }
    $data = $uncompressed;
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
package Mail::SpamAssassin::PDF::Filter::LZWDecode;
use strict;
use warnings FATAL => 'all';
use Carp;
use POSIX;

# Code taken from PDF::Builder::Basic::PDF::Filter::LZWDecode

sub new {
    my ($class, $decode_parms) = @_;
    $decode_parms //= {};
    my $self = {
        'DecodeParms' => $decode_parms
    };
    bless $self, $class;
    $self->_reset_code();
    return $self;
}

sub decode {
    my ($self, $data) = @_;
    my ($code, $result);
    my $partial_code = $self->{'partial_code'};
    my $partial_bits = $self->{'partial_bits'};
    my $early_change = $self->{'DecodeParms'}->{'EarlyChange'} // 1;

    $self->{'table'} = [ map { chr } 0 .. $self->{'clear_table'} - 1 ];
    while ($data ne q{}) {
        ($code, $partial_code, $partial_bits) =
            $self->read_dat(\$data, $partial_code, $partial_bits,
                $self->{'code_length'});
        last unless defined $code;
        unless ($early_change) {
            if ($self->{'next_code'} == (1 << $self->{'code_length'})
                and $self->{'code_length'} < 12) {
                $self->{'code_length'}++;
            }
        }
        if      ($code == $self->{'clear_table'}) {
            $self->{'code_length'} = $self->{'initial_code_length'};
            $self->{'next_code'}   = $self->{'eod_marker'} + 1;
            next;
        } elsif ($code == $self->{'eod_marker'}) {
            last;
        } elsif ($code > $self->{'eod_marker'}) {
            $self->{'table'}[$self->{'next_code'}] = $self->{'table'}[$code];
            $self->{'table'}[$self->{'next_code'}] .=
                substr($self->{'table'}[$code + 1], 0, 1);
            $result .= $self->{'table'}[$self->{'next_code'}];
            $self->{'next_code'}++;
        } else {
            $self->{'table'}[$self->{'next_code'}] = $self->{'table'}[$code];
            $result .= $self->{'table'}[$self->{'next_code'}];
            $self->{'next_code'}++;
        }
        if ($early_change) {
            if ($self->{'next_code'} == (1 << $self->{'code_length'})
                and $self->{'code_length'} < 12) {
                $self->{'code_length'}++;
            }
        }
    }
    $self->{'partial_code'} = $partial_code;
    $self->{'partial_bits'} = $partial_bits;
    if ($self->_predictor_type() == 2) {
        return $self->_depredict($result);
    }
    return $result;
}

sub _reset_code {
    my $self = shift;

    $self->{'initial_code_length'} = 9;
    $self->{'max_code_length'}     = 12;
    $self->{'code_length'}         = $self->{'initial_code_length'};
    $self->{'clear_table'}         = 256;
    $self->{'eod_marker'}          = $self->{'clear_table'} + 1;
    $self->{'next_code'}           = $self->{'eod_marker'} + 1;
    $self->{'next_increase'}       = 2**$self->{'code_length'};
    $self->{'at_max_code'}         = 0;
    $self->{'table'} = { map { chr $_ => $_ } 0 .. $self->{'clear_table'} - 1 };
    return;
}

sub _new_code {
    my ($self, $word) = @_;

    if ($self->{'at_max_code'} == 0) {
        $self->{'table'}{$word} = $self->{'next_code'};
        $self->{'next_code'} += 1;
    }

    if ($self->{'next_code'} >= $self->{'next_increase'}) {
        if ($self->{'code_length'} < $self->{'max_code_length'}) {
            $self->{'code_length'}   += 1;
            $self->{'next_increase'} *= 2;
        } else {
            $self->{'at_max_code'} = 1;
        }
    }
    return;
}

sub read_dat {
    my ($self, $data_ref, $partial_code, $partial_bits, $code_length) = @_;
    if (not defined $partial_bits) { $partial_bits = 0; }
    if (not defined $partial_code) { $partial_code = 0; }
    while ($partial_bits < $code_length) {
        return (undef, $partial_code, $partial_bits) unless length($$data_ref);
        $partial_code = ($partial_code << 8) + unpack('C', $$data_ref);
        substr($$data_ref, 0, 1, q{});
        $partial_bits += 8;
    }
    my $code = $partial_code >> ($partial_bits - $code_length);
    $partial_code &= (1 << ($partial_bits - $code_length)) - 1;
    $partial_bits -= $code_length;
    return ($code, $partial_code, $partial_bits);
}

sub _predictor_type {
    my ($self) = @_;
    my $predictor = $self->{'DecodeParms'}->{'Predictor'} // 1;
    if ($predictor == 1 or $predictor == 2) {
        return $predictor;
    } elsif ($predictor == 3) {
        croak 'Floating point TIFF predictor not yet supported';
    } else {
        croak "Invalid predictor: $predictor";
    }
}

sub _depredict {
    my ($self, $data) = @_;
    my $param = $self->{'DecodeParms'} // {};
    my $alpha = $param->{'Alpha'} // 0;
    my $bpc = $param->{'BitsPerComponent'} // 8;
    my $colors  = $param->{'Colors'}  // 1;
    my $columns = $param->{'Columns'} // 1;
    my $rows    = $param->{'Rows'} // 0;

    my $comp = $colors + $alpha;
    my $bpp  = ceil($bpc * $comp / 8);
    my $max  = 256;
    if ($bpc == 8) {
        my @data = unpack('C*', $data);
        for my $j (0 .. $rows - 1) {
            my $count = $bpp * ($j * $columns + 1);
            for my $i ($bpp .. $columns * $bpp - 1) {
                $data[$count] =
                    ($data[$count] + $data[$count - $bpp]) % $max;
                $count++;
            }
        }
        $data = pack('C*', @data);
        return $data;
    }
    return $data;
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
=head1 NAME

Mail::SpamAssassin::PDF::Parser - Parse PDF documents

=head1 SYNOPSIS

    use Mail::SpamAssassin::PDF::Parser;
    my $parser = Mail::SpamAssassin::PDF::Parser->new(timeout => 5);
    $parser->parse(\$data);
    print $parser->version();
    print $parser->info()->{Author};
    print $parser->is_encrypted();
    print $parser->is_protected();

=over

=cut

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

=item new(%opts)

Create a new parser object. Options are:

=over

=item context

A Mail::SpamAssassin::PDF::Context object. This object will be used to
handle callbacks for various PDF objects. See L<Mail::SpamAssassin::PDF::Context>
for more information.

=item timeout

Timeout in seconds. If the PDF document takes longer than this to parse,
the parser will die with an error. This is useful for preventing denial
of service attacks.

=item debug

Set the debugging level. Valid values are 'all', 'trace', 'xref', 'stream',
'tokens', 'page', 'image', 'text', 'uri'

=back

=cut

sub new {
    my ($class,%opts) = @_;

    my $self = bless {
        context      => $opts{context} || Mail::SpamAssassin::PDF::Context::Info->new(),
        timeout      => $opts{timeout},
    }, $class;

    $debug = $opts{debug};

    $self;
}

=item parse($data)

Parse a PDF document. $data can be a filename, a reference to a scalar containing the PDF data, or a file handle.

=cut

sub parse {
    my ($self,$data) = @_;

    # Initialize object
    $self->{object_cache} = {};
    $self->{stream_cache} = {};
    $self->{xref} = {};
    $self->{trailer} = {};
    $self->{pages} = [];
    $self->{is_encrypted} = 0;
    $self->{is_protected} = 0;


    $self->{core} = Mail::SpamAssassin::PDF::Core->new($data);

    # Parse header
    $self->{version} = $self->{core}->get_version();

    local $SIG{ALRM} = sub {die "__TIMEOUT__\n"};
    alarm($self->{timeout}) if (defined($self->{timeout}));

    eval {

        # Parse cross-reference table (and trailer)
        debug('trace',"Calling _parse_xref");
        $self->_parse_xref($self->{core}->get_startxref());
        debug('xref',$self->{xref});
        debug('trailer',$self->{trailer});

        # Parse encryption dictionary
        debug('trace',"Calling _parse_encrypt");
        $self->_parse_encrypt($self->{trailer}->{'/Encrypt'}) if defined($self->{trailer}->{'/Encrypt'});

        # Parse info object
        debug('trace',"Calling _parse_info");
        $self->{trailer}->{'/Info'} = $self->_parse_info($self->{trailer}->{'/Info'});
        debug('info',$self->{trailer}->{'/Info'});
        $self->{trailer}->{'/Root'} = $self->_get_obj($self->{trailer}->{'/Root'});
        debug('root',$self->{trailer}->{'/Root'});

        # Parse catalog
        my $root = $self->{trailer}->{'/Root'};
        if (defined($root->{'/OpenAction'}) && ref($root->{'/OpenAction'}) eq 'HASH') {
            $root->{'/OpenAction'} = $self->_dereference($root->{'/OpenAction'});
            debug('trace',"Calling _parse_action");
            $self->_parse_action($root->{'/OpenAction'});
        }

        if ($self->{context}->can('parse_begin')) {
            debug('trace',"Calling _parse_begin");
            $self->{context}->parse_begin($self);
        }

        # Parse page tree
        debug('trace',"Calling _parse_pages");
        $root->{'/Pages'} = $self->_parse_pages($root->{'/Pages'});

        if ($self->{context}->can('parse_end')) {
            debug('trace',"Calling _parse_end");
            $self->{context}->parse_end($self);
        }

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
    my $token = eval { $core->get_token(); } // '';
    if ( $token ne 'xref' ) {
        # not a cross-reference table. See if it's a cross-reference stream
        eval {
            die if ($token !~ /^\d+$/);
            $core->assert_number();
            $core->assert_token('obj');
            1;
        } or do {
            # not a cross-reference stream either. Try to repair the file
            return $self->_repair_xref($pos);
        };
        debug('xref','Parsing xref stream at offset '.$pos);
        my $xref = $core->get_dict();
        return $self->_parse_xref_stream($xref);
    }
    debug('xref','Parsing xref table at offset '.$pos);

    while () {
        my $start = eval { $core->get_number(); };
        last unless defined($start);
        my $count = $core->get_number();
        debug('xref',"start=$start count=$count");
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
    my ($self,$xref) = @_;

    my $data = $self->_get_stream_data($xref);
    my $width = $xref->{'/W'}->[0] + $xref->{'/W'}->[1] + $xref->{'/W'}->[2];
    my $template = 'H'.($xref->{'/W'}->[0]*2).'H'.($xref->{'/W'}->[1]*2).'H'.($xref->{'/W'}->[2]*2);
    my @index = defined($xref->{'/Index'}) ? @{$xref->{'/Index'}} : (0,$xref->{'/Size'});
    die "Odd number of elements in index while parsing xref stream" if (scalar(@index) % 2 != 0);

    my $o = 0;
    for (my $i=0;$i<scalar(@index);$i+=2) {
        my ($start,$count) = ($index[$i],$index[$i+1]);
        for ( my ($n,$c)=($start,0); $c<$count; $n++,$c++ ) {
            my ($type,@fields) = map { hex($_) } unpack("x$o $template",$data);
            $o+=$width;
            if ( $type == 0 ) {
                next;
            } elsif ( $type == 1 ) {
                my ($offset,$gen) = @fields;
                my $key = "$n $gen R";
                $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
            } elsif ( $type == 2 ) {
                my ($obj,$index) = @fields;
                my $key = "$n 0 R";
                $self->{xref}->{$key} = [ "$obj 0 R", $index ]; # unless defined($self->{xref}->{$key});
            }
        }
    }

    $self->{trailer} = $xref;

    if ( defined($xref->{'/Prev'}) ) {
        $self->_parse_xref($xref->{'/Prev'});
    }

    return 1;

}

# sub _repair_xref()
#
# Try to repair a PDF file that has a corrupt xref table. This generally happens when a PDF has been transmitted
# over a network and the line endings have been converted from DOS to Unix or vice versa. This causes the offsets
# in the xref table to be incorrect. This method will scan the file from beginning to end looking for objects and
# creates the xref table manually. This seems to be how Adobe Reader handles it so we'll do the same.
#
sub _repair_xref {
    my ($self) = @_;
    my $core = $self->{core};
    my @token_buf;
    my @pos_buf;
    my @xref_stream;

    # Scan the file from the beginning looking for objects and add them to the xref table
    $core->pos(0);
    while () {
        my $pos = $core->pos();
        my $token = $core->get_token();
        last unless defined($token);
        if ( $token eq 'obj' ) {
            # found object
            my $ref = join(' ',@token_buf).' R';
            $self->{xref}->{$ref} = $pos_buf[0];
            my $obj = $core->get_primitive();
            if ( ref($obj) eq 'HASH' && defined($obj->{_stream_offset}) ) {
                # Object stream. Skip over stream data
                { local $/ = "\nendstream"; readline $core->{fh}; }

                # Calculate stream length (may be different from Length entry)
                $obj->{_stream_length} = $core->pos() - $obj->{_stream_offset} - 10;

                # Store in cache
                $obj->{_objnum} = $token_buf[0];
                $obj->{_gennum} = $token_buf[1];
                $self->{object_cache}->{$ref} = $obj;

                if ( defined($obj->{'/Type'}) && $obj->{'/Type'} eq '/XRef' ) {
                    # Found xref stream. Process these later
                    push(@xref_stream, $obj);
                }
            }
            @token_buf = ();
            @pos_buf = ();
            next;
        }
        if ( $token eq 'trailer' ) {
            # found trailer
            my $trailer = $core->get_dict();
            $self->{trailer} = {
                %{$trailer},
                %{$self->{trailer}}
            };
            last;
        }

        # keep the last two tokens and their positions in a buffer
        push(@token_buf,$token);
        push(@pos_buf,$pos);
        if (scalar(@token_buf) > 2) {
            shift @token_buf;
            shift @pos_buf;
        }
    }

    die "Trailer not found" unless defined($self->{trailer});

    # Process xref streams in reverse order
    while () {
        my $xref_stream = pop(@xref_stream);
        last unless defined($xref_stream);
        undef $xref_stream->{'/Prev'}; # prevent recursion
        $self->_parse_xref_stream($xref_stream);
    }



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
    debug('crypt',$self->{core}->{crypt});

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
        next unless defined($parent_node->{$_});
        $node->{$_} = $parent_node->{$_} unless defined($node->{$_});
    }

    if ( !defined($node->{'/Type'}) ) {
        # Type is required but sometimes it's missing
        $node->{'/Type'} = defined($node->{'/Kids'}) ? '/Pages' :
                           defined($node->{'/Contents'}) ? '/Page' :
                           die "Page type not found";
    }

    if ( $node->{'/Type'} eq '/Pages' ) {
        $node->{'/Kids'} = $self->_dereference($node->{'/Kids'});
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
        if ( $location =~ /^[a-z]+:/i ) {
            $rect = $self->_dereference($rect);
            $_ = $self->_dereference($_) for (@{$rect});
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
                if (defined($xobj->{'/Matrix'})) {
                    my $matrix = $xobj->{'/Matrix'};
                    $matrix = $self->_dereference($matrix) if ref($matrix) ne 'ARRAY';
                    $context->concat_matrix(@{$matrix});
                }
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
        $stream .= $self->_get_stream_data($obj) . "\n";
    }
    debug('stream',$stream);

    my $core = $self->{core}->clone(\$stream);

    # Process commands
    while () {
        my ($token,$type) = $core->get_primitive();
        last unless defined($token);
        debug('tokens',"$type: $token");
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
            debug('trace',"Getting compressed object $ref");
            $obj = $self->_get_compressed_obj($stream_obj_ref,$index,$ref);
        } else {
            $core->pos($self->{xref}->{$ref});
            eval {
                $core->get_number();
                $core->get_number();
                $core->assert_token('obj');
                $obj = $core->get_primitive();
                1;
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
        die "Error getting stream data for object $ref" unless defined($data);
        my $core = $stream_obj->{core} = $self->{core}->clone(\$data);
        for(my $n = $stream_obj->{'/N'}; $n > 0; $n--) {
            my $key = $core->get_number();
            die "Error getting xref key for object $ref" unless defined($key);
            $stream_obj->{xref}->{$key} = $core->get_number();
        }
        $stream_obj->{pos} = $core->pos();
    }

    $stream_obj->{core}->pos($stream_obj->{pos}+$stream_obj->{xref}->{$obj});
    return $self->{object_cache}->{$ref} = $stream_obj->{core}->get_primitive();
}

sub _get_stream_data {
    my ($self,$stream_obj) = @_;
    local $_ = $self->_dereference($stream_obj);
    unless (defined($_)) {
        die "Error getting stream data. Object not found\n" . Dumper($stream_obj);
    }

    # not a stream object
    unless (ref($_) eq 'HASH' && defined($_->{_stream_offset})) {
        die "Error getting stream data. Object is not a stream\n" . Dumper($stream_obj);
    }

    $stream_obj = $_;
    my $offset = $stream_obj->{_stream_offset};
    my $length = defined($stream_obj->{_stream_length})
        ? $stream_obj->{_stream_length}
        : $self->_dereference($stream_obj->{'/Length'});
    my @filters;
    if ( defined($stream_obj->{'/Filter'}) ) {
        my $filter = $self->_dereference($stream_obj->{'/Filter'});
        @filters = ref($filter) eq 'ARRAY' ? @{$filter} : ( $filter );
    }

    my @decodeParms;
    if (defined($stream_obj->{'/DecodeParms'})) {
        my $decodeParms = $self->_dereference($stream_obj->{'/DecodeParms'});
        @decodeParms = ref($decodeParms) eq 'ARRAY' ? @{$decodeParms} : ($decodeParms);
    }

    # check for cached version
    return $self->{stream_cache}->{$offset} if defined($self->{stream_cache}->{$offset});

    $self->{core}->pos($offset);
    read($self->{core}->{fh},my $stream_data,$length);
    if (defined($self->{core}->{crypt})) {
        $self->{core}->{crypt}->set_current_object($stream_obj->{_objnum}, $stream_obj->{_gennum});
        $stream_data = $self->{core}->{crypt}->decrypt($stream_data);
    }
    $self->{core}->assert_token('endstream');

    for (my $i=0;$i<scalar(@filters);$i++) {
        my $filter = $self->_dereference($filters[$i]);
        my $decodeParms = $self->_dereference($decodeParms[$i]);
        $filter = $abbreviations{$filter} if defined($abbreviations{$filter});
        if ( $filter eq '/FlateDecode' ) {
            my $f = Mail::SpamAssassin::PDF::Filter::FlateDecode->new($decodeParms);
            $stream_data = $f->decode($stream_data);
        } elsif ( $filter eq '/LZWDecode' ) {
            my $f = Mail::SpamAssassin::PDF::Filter::LZWDecode->new($decodeParms);
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

=back

=cut

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

my $VERSION = 0.34;

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
    $self->register_eval_rule ("pdf2_is_encrypted_blank_pw", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf2_is_protected", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);

    # lower priority for add_uri_detail_list to work
    $self->register_method_priority ("parsed_metadata", -1);
    $self->register_method_priority('post_message_parse', -1);

    $self->set_config($mailsaobject->{conf});

    return $self;
}

sub set_config {
    my ($self, $conf) = @_;
    my @cmds;

    push (@cmds, (
        {
            setting => 'pdftext',
            is_priv => 1,
            type => $Mail::SpamAssassin::Conf::CONF_TYPE_STRING,
            code => sub {
                my ($self, $key, $value, $line) = @_;

                if ($value !~ /^(\S+)\s+(.+)$/) {
                    return $Mail::SpamAssassin::Conf::INVALID_VALUE;
                }
                my $name = $1;
                my $pattern = $2;

                my ($re, $err) = compile_regexp($pattern, 1);
                if (!$re) {
                    dbg("Error parsing rule: invalid regexp '$pattern': $err");
                    return $Mail::SpamAssassin::Conf::INVALID_VALUE;
                }

                $conf->{parser}->{conf}->{pdftext_rules}->{$name} = $re;

                # just define the test so that scores and lint works
                $self->{parser}->add_test($name, undef,
                    $Mail::SpamAssassin::Conf::TYPE_EMPTY_TESTS);


            }
        }
    ));

    $conf->{parser}->register_commands(\@cmds);
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
            $pdf->parse(\$data);
            $pdf->{context}->get_info();
        };
        if ( !defined($info) ) {
            log_warn($@);
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
    $pms->{pdfinfo2}->{text} = [];
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

        # Get text (requires ExtractText to have already extracted text from the PDF)
        my $text = $p->rendered() || '';
        for (split(/^/, $text)) {
            chomp;
            next if /^\s*$/;
            push(@{$pms->{pdfinfo2}->{text}}, $_);
        }
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
        $pms->{pdfinfo2}->{totals}->{EncryptedBlankPw} +=
            ($info->{Encrypted} && !$info->{Protected}) ? 1 : 0;

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

    $self->_run_pdftext_rules($pms);
}

sub _run_pdftext_rules {
    my ($self, $pms) = @_;

    my $pdftext_rules = $pms->{conf}->{pdftext_rules};
    return unless defined $pdftext_rules;

    my $text = $pms->{pdfinfo2}->{text};
    return unless defined $text && $text ne '';

    foreach my $name (keys %{$pdftext_rules}) {
        my $re = $pdftext_rules->{$name};
        foreach my $line (@$text) {
            if ($line =~ /$re/p) {
                my $match = defined ${^MATCH} ? ${^MATCH} : '<negative match>';
                log_dbg(qq(ran rule $name ======> got hit "$match"));
                my $score = $pms->{conf}->{scores}->{$name} // 1;
                $pms->got_hit($name,'PDFTEXT: ','ruletype' => 'body', 'score' => $score);
                $pms->{pattern_hits}->{$name} = $match;
                last;
            }
        }
    }

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

sub pdf2_is_encrypted_blank_pw {
    my ($self, $pms, $body) = @_;

    return $pms->{pdfinfo2}->{totals}->{EncryptedBlankPw} ? 1 : 0;
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