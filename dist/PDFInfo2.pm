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

=head1 INSTALLATION

=head3 Manual method

Copy all the files in the C<dist/> directory to your site rules directory (e.g. C</etc/mail/spamassassin>)

=head3 Automatic method

TBD

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
        tests may still yield valuable data: pdf2_count, pdf2_page_count, pdf2_match_md5,
        pdf2_match_fuzzy_md5, and pdf2_match_details('Version')

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

Example C<add_header> lines:

    add_header all PDF-Info pdf=_PDF2COUNT_, ver=_PDF2VERSION_, name=_PDF2NAME_
    add_header all PDF-Details producer=_PDF2PRODUCER_, author=_PDF2AUTHOR_, creator=_PDF2CREATOR_, title=_PDF2TITLE_
    add_header all PDF-ImageInfo images=_PDF2IMAGECOUNT_ cimages=_PDF2CIMAGECOUNT_ ratios=_PDF2IMAGERATIO_
    add_header all PDF-LinkInfo links=_PDF2LINKCOUNT_, ratios=_PDF2CLICKRATIO_
    add_header all PDF-Md5 md5=_PDF2MD5_, fuzzy1=_PDF2MD5FUZZY1_


=head1 URI DETAILS

This plugin creates a new "pdf" URI type. You can detect URI's in PDF's using the URIDetail.pm plugin. For example:

    uri-detail RULENAME  type =~ /^pdf$/  raw =~ /^https?:\/\/bit\.ly\//

This will detect a bit.ly link inside a PDF document

=cut

package Mail::SpamAssassin::PDF::Core;
use strict;
use warnings FATAL => 'all';
use Encode qw(from_to decode);
use Carp;
use Data::Dumper;

=head1 ACKNOWLEDGEMENTS

Portions borrowed from CAM::PDF

=cut

sub new {
    my ($class) = @_;
    bless {},$class;
}

sub get_string {
    my ($self,$ptr) = @_;

    my $offset = pos($$ptr);
    $$ptr =~ /\G\s*\(/g or croak "string not found at offset $offset";

    my $depth = 1;
    my $str = '';
    while ($depth > 0) {
        if ($$ptr =~ m/ \G ([^()]*) ([()]) /cgxms) {
            my $data = $1;
            my $delim = $2;
            $str .= $data;

            # Make sure this is not an escaped paren, OR a real paren
            # preceded by an escaped backslash!
            if ($data =~ m/ (\\+) \z/xms && 1 == (length $1) % 2) {
                $str .= $delim;
            } elsif ($delim eq '(') {
                $str .= $delim;
                $depth++;
            } elsif (--$depth > 0) {
                $str .= $delim;
            }
        } else {
            croak "Unterminated string at offset $offset";
        }
    }

    # convert escape sequences
    my %quoted = ("n" => "\n", "r" => "\r",
        "t" => "\t", "b" => "\b",
        "f" => "\f", "\\" => "\\",
        "(" => "(", ")" => ")");
    $str =~ s/\\([nrtbf\\()]|[0-7]{1,3})/
        defined ($quoted{$1}) ? $quoted{$1} : chr(oct($1))/gex;

    # decrypt
    if ( defined($self->{crypt}) ) {
        $str = $self->{crypt}->decrypt($str);
    }

    # Convert to UTF-8 and remove BOM
    if ( $str =~ s/^\xfe\xff// ) {
        from_to($str,'UTF-16be', 'UTF-8');
    } elsif ( $str =~ s/^\xff\xfe// ) {
        from_to($str,'UTF-16le', 'UTF-8');
    }

    # remove trailing null chars
    $str =~ s/\x00+$//;

    return wantarray ? ($str,'string') : $str;
}

sub get_hex_string {
    my ($self,$ptr) = @_;

    $$ptr =~ /\G\s*<([0-9A-Fa-f]*?)>/g or die "Invalid hex string at offset ".pos($$ptr);
    my $hex = $1;
    $hex =~ s/\s+//gxms;
    $hex .= '0' if (length($hex) % 2 == 1);
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
    return wantarray ? ($str,'string') : $str;
}

sub get_array {
    my ($self,$ptr) = @_;
    my @array;

    $$ptr =~ /\G\s*\[/g or die "array not found at offset ".pos($$ptr);

    while () {
        ($_) = $self->get_primitive($ptr);
        last if $_ eq ']';
        push(@array,$_);
    }

    return wantarray ? (\@array,'array') : \@array;
}

sub get_dict {
    my ($self,$ptr) = @_;

    my @array;

    $$ptr =~ /\G\s*<</g or croak "dict not found at offset ".pos($$ptr);

    while () {
        ($_) = $self->get_primitive($ptr);
        croak "Unexpected end of file" unless defined($_);
        last if $_ eq '>>';
        push(@array,$_);
    }

    my %dict = @array;

    if ( $$ptr =~ /\G\s*stream\r?\n/ ) {
        $dict{_stream_offset} = $+[0];
    }

    return wantarray ? (\%dict,'dict') : \%dict;

}

sub get_primitive {
    my ($self,$ptr) = @_;

    return undef unless defined($$ptr);

    local $_;

    while () {
        if ( $$ptr =~ /\G\s*<</ ) {
            return $self->get_dict($ptr);
        }
        if ( $$ptr =~ /\G\s*\(/ ) {
            return $self->get_string($ptr);
        }
        if ( $$ptr =~ /\G\s*</ ) {
            return $self->get_hex_string($ptr);
        }
        if ( $$ptr =~ /\G\s*\[/ ) {
            return $self->get_array($ptr);
        }
        if ( $$ptr =~ /\G\s*(\/[^\/%\(\)\[\]<>{}\s]*)/gc ) {
            return wantarray ? ($1,'name') : $1;
        }
        if ( $$ptr =~ /\G\s*(\d+\s\d+\sR\b)/gc ) {
            return wantarray ? ($1,'ref') : $1;
        }
        if ( $$ptr =~ /\G\s*([-+]?\d+(?:\.\d+)?|[-+]?\.\d+)/gc ) {
            return wantarray ? ($1,'number') : $1;
        }
        if ( $$ptr =~ /\G\s*(true|false)/gc ) {
            return wantarray ? ($1,'bool') : $1;
        }
        if ( $$ptr =~ /\G\s*(null)/gc ) {
            return wantarray ? ($1,'null') : $1;
        }
        if ( $$ptr =~ /\G\s*([^\/%\(\)\[\]<>{}\s]+)/gc ) {
            return wantarray ? ($1,'operator') : $1;
        }
        if ( $$ptr =~ /\G\s*(\]|>>)/gc ) {
            return wantarray ? ($1,'end_bracket') : $1;
        }
        if ( $$ptr =~ /\G\s*\%[^\n]*\n/gc ) {
            # Comment
            next;
        }
        if ( $$ptr =~ /\G\s*$/ ) {
            # EOF
            return;
        }

        # print substr($$ptr,pos($$ptr)-10,10)."|".substr($$ptr,pos($$ptr),20),"\n";
        croak "Unknown primitive at offset ".pos($$ptr);

    }

}

sub unquote_name {
    my $value = shift;
    $value =~ s/#([\da-f]{2})/chr(hex($1))/ige;
    return $value;
}

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
use Digest::MD5;
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

    # print Dumper($image); exit;

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
    my ($self,$location,$rect) = @_;

    my $fuzzy_data = '/URI';
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

    $self->{info}->{uris}->{$location} = 1;
    $self->{info}->{LinkCount}++;

    if ( defined($rect) ) {
        $self->{info}->{ClickArea} += abs(($rect->[2]-$rect->[0]) * ($rect->[3]-$rect->[1]));
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
    $self->{info}->{FuzzyMD5} = uc($self->{fuzzy_md5}->hexdigest());
    # $self->{info}->{FuzzyMD5Data} = $self->{fuzzy_md5_data};

}

sub serialize_fuzzy {
    my ($self,$obj) = @_;

    if ( !defined($obj) ) {
        return 'U';
    } elsif ( ref($obj) eq 'ARRAY' ) {
        my $str = '';
        $str .= $self->serialize_fuzzy($_) for @$obj;
        return $str;
    } elsif ( ref($obj) eq 'HASH' ) {
        my $str = '';
        foreach (sort keys %$obj) {
            next unless /^\//;
            $str .= $_ . $self->serialize_fuzzy( $obj->{$_} );
        }
        return $str;
    } elsif ( $obj =~ /^\d+ \d+ R$/ )  {
        return 'R';
    } elsif ( $obj =~ /^[\d.+-]+$/ ) {
        return 'N';
    } elsif ( $obj =~ /^D:/ ) {
        return 'D';
    }

    eval {
        my $tmp = $obj;
        decode('utf-8-strict',$tmp,Encode::FB_CROAK);
    } or return 'B';

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

1;
package Mail::SpamAssassin::PDF::Filter::Decrypt;
use strict;
use warnings FATAL => 'all';
use Digest::MD5;
use Crypt::RC4;
use Crypt::Mode::CBC;
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

    unless ( $v == 1 || $v == 2 || $v == 4 ) {
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

    if ( $self->{V} == 4 ) {
        # todo: Implement Crypt Filters
        my $iv = substr($content,0,16);
        my $m = Crypt::Mode::CBC->new('AES');
        return $m->decrypt(substr($content,16),$self->_compute_key(),$iv);
    }
    return Crypt::RC4::RC4($self->_compute_key(), $content);

}

#
# Algorithm 3.6 Authenticating the user password
#
sub _check_user_password {
    my ($self,$pass) = @_;

    # step 1  Perform all but the last step of Algorithm 3.4 (Revision 2) or Algorithm 3.5 (Revision 3) using the supplied password string.
    if ( $self->{R} >= 3 ) {

        #
        # Algorithm 3.5 Computing the encryption dictionary’s U (user password) value (Revision 3)
        #

        # step 1 Create an encryption key based on the user password string, as described in Algorithm 3.2
        my $key = $self->_generate_key($pass);

        # step 2 Initialize the MD5 hash function and pass the 32-byte padding string as input to this function
        my $md5 = Digest::MD5->new();
        $md5->add($padding);

        # step 3 Pass the first element of the file’s file identifier array to the hash function
        # and finish the hash.
        $md5->add($self->{ID});
        my $hash = $md5->digest();

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
    $md5->add($self->{ID});

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
        if ( $self->{V} == 4 ) {
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
    if ( $self->{predictor} == 2 ) {
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
package Mail::SpamAssassin::PDF::Parser;
use strict;
use warnings FATAL => 'all';
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Carp;

my $debug;  # debugging level

sub new {
    my ($class,%opts) = @_;

    my $self = bless {
        xref         => {},
        trailer      => {},
        pages        => [],
        is_encrypted => 0,
        is_protected => 0,

        core         => Mail::SpamAssassin::PDF::Core->new(),
        context      => $opts{context} || Mail::SpamAssassin::PDF::Context::Info->new(),

        object_cache => {},
        stream_cache => {},
    }, $class;

    $debug = $opts{debug};

    $self;
}

sub parse {
    my ($self,$data) = @_;

    $data =~ /^%PDF\-(\d\.\d)/ or croak("PDF magic header not found");

    $self->{version} = $1;
    $self->{data} = $data;

    # Parse cross-reference table (and trailer)
    $self->{data} =~ /(\d+)\s+\%\%EOF\s*$/ or croak "EOF marker not found";
    $self->_parse_xref($1);

    # Parse encryption dictionary
    $self->_parse_encrypt($self->{trailer}->{'/Encrypt'}) if defined($self->{trailer}->{'/Encrypt'});

    # Parse info object
    $self->{trailer}->{'/Info'} = $self->_get_obj($self->{trailer}->{'/Info'});
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

    pos($self->{data}) = $pos;

    if ( $self->{data} =~ /\G\s*\d+ \d+ obj\s+/) {
        return $self->_parse_xref_stream($+[0]);
    }
    $self->{data} =~ /\G\s*xref\s+/g or die "xref not found at position $pos";

    while ($self->{data} =~ /\G(\d+) (\d+)\s+/) {
        pos($self->{data}) = $+[0]; # advance the pointer
        my ($start,$count) = ($1,$2);
        for (my ($i,$n)=($start,0);$n<$count;$i++,$n++) {
            $self->{data} =~ /\G(\d+) (\d+) (f|n)\s+/g or die "Invalid xref entry";
            next unless $3 eq 'n';
            my ($offset,$gen) = ($1+0,$2+0);
            my $key = "$i $gen R";
            $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
        }
    }

    $self->{data} =~ /\G\s*trailer\s+/g or die "trailer not found";

    my $trailer = $self->{core}->get_dict(\$self->{data});
    $self->{trailer} = {
        %{$trailer},
        %{$self->{trailer}}
    };

    if ( defined($trailer->{'/Prev'}) ) {
        $self->_parse_xref($trailer->{'/Prev'});
    }

}

sub _parse_xref_stream {
    my ($self,$pos) = @_;

    pos($self->{data}) = $pos;

    my $xref = $self->{core}->get_dict(\$self->{data});
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
        my $process_page = 1;
        push @{$self->{pages}}, $node;
        $node->{page_number} = scalar(@{$self->{pages}});

        # call page begin handler
        $process_page = $self->{context}->page_begin($node) if $self->{context}->can('page_begin');

        if ( $process_page ) {
            $self->_parse_annotations($node->{'/Annots'}) if (defined($node->{'/Annots'}));
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
    my ($self,$annots) = @_;
    $annots = $self->_dereference($annots);
    return unless defined($annots);

    for my $ref (@$annots) {
        my $annot = $self->_get_obj($ref);
        if ( defined($annot->{'/Subtype'}) && $annot->{'/Subtype'} eq '/Link' && defined($annot->{'/A'}) ) {
            $self->_parse_action($annot->{'/A'},$annot->{'/Rect'});
        }
    }

}

sub _parse_action {
    my ($self,$action,$rect) = @_;
    $action = $self->_dereference($action);
    return unless defined($action);

    if ( $action->{'/S'} eq '/URI' ) {
        my $location = $action->{'/URI'};
        if ( $location =~ /^\w+:/ ) {
            $self->{context}->uri($location,$rect) if $self->{context}->can('uri');
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
        my $obj = $xobject->{$name} = $self->_get_obj($ref);
        if ( $obj->{'/Subtype'} eq '/Image' ) {
            $obj->{'/ColorSpace'} = $self->_dereference($obj->{'/ColorSpace'});
        } elsif ( $obj->{'/Subtype'} eq '/Form' ) {
            $obj->{'/Resources'} = $self->_parse_resources($obj->{'/Resources'}) if (defined($obj->{'/Resources'}));
        }
    }
    return $xobject;
}

sub _parse_contents {
    my ($self,$contents,$page) = @_;
    return if $self->is_protected();

    $contents = [ $contents ] if (ref($contents) ne 'ARRAY');

    #@type Mail::SpamAssassin::PDF::Context
    my $context = $self->{context};
    my $core = Mail::SpamAssassin::PDF::Core->new;
    my @params;

    # Build a dispatch table
    my %dispatch = (
        q  => sub { $context->save_state() },
        Q  => sub { $context->restore_state() },
        cm => sub { $context->concat_matrix(@_) },
        Do => sub {
            my $xobj = $page->{'/Resources'}->{'/XObject'}->{$_[0]};
            $xobj->{_name} = $_[0];
            if ( $xobj->{'/Subtype'} eq '/Image' ) {
                $context->draw_image($xobj,$page) if $self->{context}->can('draw_image');
            } elsif ( $xobj->{'/Subtype'} eq '/Form' ) {
                $context->save_state();
                $context->concat_matrix(@{$xobj->{'/Matrix'}});
                $self->_parse_contents($xobj, $page);
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
            my $font = $self->_dereference($page->{'/Resources'}->{'/Font'}->{$_[0]});
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

    # Process commands
    for my $obj ( @$contents ) {
        my $stream = $self->_get_stream_data($obj);
        while () {
            my ($token,$type) = $core->get_primitive(\$stream);
            last unless defined($token);
            if ( $type ne 'operator' ) {
                push(@params,$token);
                next;
            }
            if ( defined($dispatch{$token}) ) {
                $dispatch{$token}->(@params);
            }
            @params = ();
        }
    }

}

sub _get_obj {
    my ($self,$ref) = @_;

    # return undef for non-existent objects
    return undef unless defined($ref) && defined($self->{xref}->{$ref});

    # return cached object if possible
    return $self->{object_cache}->{$ref} if defined($self->{object_cache}->{$ref});

    if (defined($self->{core}->{crypt})) {
        my ($objnum,$gennum) = $ref =~ /^(\d+) (\d+) R$/;
        $self->{core}->{crypt}->set_current_object($objnum, $gennum);
    }

    if ( ref($self->{xref}->{$ref}) eq 'ARRAY' ) {
        my ($stream_obj_ref,$index) = @{$self->{xref}->{$ref}};
        $self->{object_cache}->{$ref} = $self->_get_compressed_obj($stream_obj_ref,$index,$ref);
    } else {
        pos($self->{data}) = $self->{xref}->{$ref};
        $self->{data} =~ /\G\s*\d+ \d+ obj\s*/g or die "object $ref not found";
        eval {
            $self->{object_cache}->{$ref} = $self->{core}->get_primitive(\$self->{data});
        } or die "Error getting object $ref: $@";
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
    my $data = $self->_get_stream_data($stream_obj);

    if ( !defined($stream_obj->{pos}) ) {
        while ( $data =~ /\G\s*(\d+) (\d+)\s+/ ) {
            $stream_obj->{xref}->{$1} = $2;
            pos($data) = $+[0];
        }
        $stream_obj->{pos} = pos($data);
    }

    pos($data) = $stream_obj->{pos} + $stream_obj->{xref}->{$obj};
    return $self->{object_cache}->{$ref} = $self->{core}->get_primitive(\$data);
}

sub _get_stream_data {
    my ($self,$stream_obj) = @_;
    $stream_obj = $self->_dereference($stream_obj);
    return unless defined($stream_obj);

    # not a stream object
    return undef unless ref($stream_obj) eq 'HASH' && defined($stream_obj->{_stream_offset});

    my $offset = $stream_obj->{_stream_offset};
    my $length = $self->_dereference($stream_obj->{'/Length'});
    my $filter = $stream_obj->{'/Filter'} || '';

    # check for cached version
    return $self->{stream_cache}->{$offset} if defined($self->{stream_cache}->{$offset});

    my $stream_data = substr($self->{data},$offset,$length);
    if (defined($self->{core}->{crypt})) {
        $stream_data = $self->{core}->{crypt}->decrypt($stream_data);
    }

    if ( $filter eq '/FlateDecode' ) {
        my $f = Mail::SpamAssassin::PDF::Filter::FlateDecode->new($stream_obj->{'/DecodeParms'});
        $self->{stream_cache}->{$offset} = $f->decode(
            $stream_data
        );
    } else {
        $self->{stream_cache}->{$offset} = $stream_data;
    }

    return $self->{stream_cache}->{$offset};

}

sub debug {
    my $level = shift;
    return if !defined($debug);
    if ( $debug eq $level || $debug eq 'all' ) {
        for (@_) {
            print STDOUT (ref($_) ? Dumper($_) : $_),"\n";
        }
    }
}


1;


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