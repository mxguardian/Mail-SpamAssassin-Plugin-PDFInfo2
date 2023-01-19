package Mail::SpamAssassin::PDF::Core;
use strict;
use warnings FATAL => 'all';
use Encode qw(from_to decode);
use Carp;
use Data::Dumper;

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
    # print Dumper(\@array);

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
        # $$ptr =~ /\G\s*( \/[^\/%\(\)\[\]<>{}\s]* | <{1,2} | >> | \[ | \] | \( | \d+\s\d+\sR\b | [-+]?\d+(?:\.\d+)? | [-+]?\.\d+ | true | false | null | \%[^\n]*\n | [^\/%\(\)\[\]<>{}\s]+ | $ )/x or do {
        #     print substr($$ptr,pos($$ptr)-10,10)."|".substr($$ptr,pos($$ptr),20),"\n";
        #     croak "Unknown primitive at offset ".pos($$ptr);
        # };
        # print "> $1\n";
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
            return wantarray ? (undef,undef) : undef;
        }

        print substr($$ptr,pos($$ptr)-10,10)."|".substr($$ptr,pos($$ptr),20),"\n";
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
use Data::Dumper;

our @ISA = qw(Mail::SpamAssassin::PDF::Context);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{info} = {
        ImageCount => 0,
        PageCount  => 0,
        PageArea   => 0,
        ImageArea  => 0,
        LinkCount  => 0,
        uris       => {}
    };
    $self;
}

sub get_info {
    my $self = shift;
    return $self->{info};
}

sub page_begin {
    my ($self, $page) = @_;

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

    $self->{info}->{ImageCount}++;

    # print $image->{_name},"\n";

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
    my ($self,$location) = @_;

    $self->{info}->{uris}->{$location} = 1;
    $self->{info}->{LinkCount}++;

}

sub parse_complete {
    my ($self,$parser) = @_;

    $self->{info}->{ImageArea} = sprintf(
        "%.0f",
        $self->{info}->{ImageArea}
    );

    $self->{info}->{PageArea} = sprintf(
        "%.0f",
        $self->{info}->{PageArea}
    );

    $self->{info}->{ImageDensity} = sprintf(
        "%.2f",
        $self->{info}->{ImageArea} / $self->{info}->{PageArea} * 100
    );

    for (keys %{$parser->{trailer}->{'/Info'}}) {
        my $key = $_;
        $key =~ s/^\///; # Trim leading slash
        $self->{info}->{$key} = $parser->{trailer}->{'/Info'}->{$_};
    }

    $self->{info}->{Encrypted} = defined($parser->{trailer}->{'/Encrypt'}) ? 1 : 0;
    $self->{info}->{Version} = $parser->{version};

}


1;
package Mail::SpamAssassin::PDF::Filter::Decrypt;
use strict;
use warnings FATAL => 'all';
use Digest::MD5;
use Crypt::RC4;
use Carp;
use Data::Dumper;

=head1 SYNOPSIS

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

    # print Dumper($encrypt->{'/U'},length($encrypt->{'/U'}));

    my $v = $encrypt->{'/V'} || 0;
    my $length = $encrypt->{'/Length'} || 40;

    unless ( $v == 1 || $v == 2 ) {
        die "Encryption algorithm $v not implemented";
    }

    my $self = bless {
        R         => $encrypt->{'/R'},
        O         => substr( $encrypt->{'/O'} . $padding, 0, 32),
        U         => substr( $encrypt->{'/U'} . $padding, 0, 32),
        P         => $encrypt->{'/P'},
        keylength => ($v == 1 ? 40 : $length),
    }, $class;

    my $opassword = undef;
    my $upassword = undef;
    if ($self->_check_opass($opassword, $upassword)) {
        $self->{code} = $self->_compute_hash($doc_id, $opassword);
    } elsif ($self->_check_upass($doc_id, $upassword)) {
        $self->{code} = $self->_compute_hash($doc_id, $upassword);
    } else {
        croak "Document is password-protected. Unable to decrypt data.";
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

    return Crypt::RC4::RC4($self->_compute_key(), $content);

}

sub _compute_key
{
    my $self   = shift;
    my $objnum = $self->{objnum};
    my $gennum = $self->{gennum};

    my $id = $objnum . '_' .$gennum;
    if (!exists $self->{keycache}->{$id})
    {
        my $objstr = pack 'V', $objnum;
        my $genstr = pack 'V', $gennum;

        my $objpadding = substr $objstr, 0, 3;
        my $genpadding = substr $genstr, 0, 2;

        my $hash = Digest::MD5::md5($self->{code} . $objpadding . $genpadding);

        # size(bytes) = nbits/8 + 3 for objnum + 2 for gennum; max of 16;  PDF ref 1.5 pp 94-95
        my $size = ($self->{keylength} >> 3) + 5;
        if ($size > 16) {
            $size = 16;
        }
        $self->{keycache}->{$id} = substr $hash, 0, $size;
    }
    return $self->{keycache}->{$id};
}

sub _do_iter_crypt {
    my $self = shift;
    my $code = shift;
    my $pass = shift;
    my $backward = shift;

    if ($self->{R} == 3) {
        my @steps = 0..19;
        if ($backward) {
            @steps = reverse @steps;
        }
        my $size = $self->{keylength} >> 3;
        for my $iter (@steps) {
            my $xor = chr($iter) x $size;
            my $itercode = $code ^ $xor;
            $pass = Crypt::RC4::RC4($itercode, $pass);
        }
    } else {
        $pass = Crypt::RC4::RC4($code, $pass);
    }
    return $pass;
}

sub _check_opass
{
    my $self    = shift;
    my $opass   = shift;
    my $upass   = shift;

    my $crypto = $self->_compute_o($opass, $upass, 1);

    # printf "O: %s\n%s\n vs.\n%s\n", defined $opass ? $opass : '(undef)', _hex($crypto), _hex($self->{O});

    return $crypto eq $self->{O};
}

sub _check_upass
{
    my $self    = shift;
    my $doc_id  = shift;
    my $upass   = shift;

    my $cryptu = $self->_compute_u($doc_id, $upass);

    # printf "U: %s\n%s\n vs.\n%s\n", defined $upass ? $upass : '(undef)', _hex($cryptu), _hex($self->{U});

    return $cryptu eq $self->{U};
}

sub _compute_hash
{
    my $self = shift;
    my $doc_id  = shift;
    my $pass = shift;

    #print "_compute_hash for password $pass, P: $self->{P}, ID: $doc_id, O: $self->{O}\n" if ($pass);

    $pass = $self->_format_pass($pass);

    my $p = pack 'L', $self->{P}+0;
    my $bytes = unpack 'b32', $p;
    if (1 == substr $bytes, 0, 1)
    {
        # big endian, so byte swap
        $p = (substr $p,3,1).(substr $p,2,1).(substr $p,1,1).(substr $p,0,1);
    }

    my $id = substr $doc_id, 0, 16;

    my $input = $pass . $self->{O} . $p . $id;

    if ($self->{R} == 3) {
        # I don't know how to decide this.  Maybe not applicable with Standard filter?
        #if document metadata is not encrypted
        # input .= pack 'L', 0xFFFFFFFF;
    }

    my $hash = Digest::MD5::md5($input);

    if ($self->{R} == 3)
    {
        for my $iter (1..50) {
            $hash = Digest::MD5::md5($hash);
        }
    }

    # desired number of bytes for the key
    # for V==1, size == 5
    # for V==2, 5 < size < 16
    my $size = $self->{keylength} >> 3;
    return substr $hash, 0, $size;
}

sub _compute_u
{
    my $self   = shift;
    my $doc_id = shift;
    my $upass  = shift;

    my $hash = $self->_compute_hash($doc_id, $upass);
    if ($self->{R} == 3) {
        my $id = substr $doc_id, 0, 16;
        my $input = $padding . $id;
        my $code = Digest::MD5::md5($input);
        $code = substr $code, 0, 16;
        return $self->_do_iter_crypt($hash, $code) . substr $padding, 0, 16;
    } else {
        return Crypt::RC4::RC4($hash, $padding);
    }
}

sub _compute_o
{
    my $self  = shift;
    my $opass = shift;
    my $upass = shift;
    my $backward = shift;

    my $o = $self->_format_pass($opass);
    my $u = $self->_format_pass($upass);

    my $hash = Digest::MD5::md5($o);

    if ($self->{R} == 3) {
        for my $iter (1..50) {
            $hash = Digest::MD5::md5($hash);
        }
    }

    my $size = $self->{keylength} >> 3;
    my $code = substr $hash, 0, $size;
    return $self->_do_iter_crypt($code, $u, $backward);
}

sub _format_pass
{
    my $self = shift;
    my $pass = shift;

    if (!defined $pass)
    {
        $pass = q{};
    }

    return substr $pass.$padding, 0, 32;
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
        images       => {},
        core         => Mail::SpamAssassin::PDF::Core->new(),

        context      => $opts{context},

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
    $self->{data} =~ /(\d+)\s+\%\%EOF\s*$/ or die "EOF marker not found";
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

    # Parse page tree
    $root->{'/Pages'} = $self->_parse_pages($root->{'/Pages'});

    $self->{context}->parse_complete($self) if $self->{context}->can('parse_complete');

}

sub get_page_count {
    my $self = shift;
    scalar(@{$self->{pages}});
}

sub get_image_count {
    my $self = shift;
    scalar(keys %{$self->{images}});
}

sub version {
    shift->{version};
}

sub info {
    shift->{trailer}->{'/Info'};
}

sub is_encrypted {
    defined(shift->{trailer}->{'/Encrypt'}) ? 1 : 0;
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
        # print "xref $start $count\n";
        for (my ($i,$n)=($start,0);$n<$count;$i++,$n++) {
            $self->{data} =~ /\G(\d+) (\d+) (f|n)\s+/g or die "Invalid xref entry";
            # print "$1 $2 $3\n";
            next unless $3 eq 'n';
            my ($offset,$gen) = ($1+0,$2+0);
            my $key = "$i $gen R";
            # print "$key = $offset\n";
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
    # print Dumper($xref);
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
        # print join(',',@fields),"\n";
        if ( $type == 0 ) {
            next;
        } elsif ( $type == 1 ) {
            my ($offset,$gen) = @fields;
            my $key = "$i $gen R";
            # print "$key = $offset\n";
            $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
        } elsif ( $type == 2 ) {
            my ($obj,$index) = @fields;
            my $key = "$i 0 R";
            # print "$key = $obj,$index\n";
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

    $self->{core}->{crypt} = Mail::SpamAssassin::PDF::Filter::Decrypt->new($encrypt,$self->{trailer}->{'/ID'}->[0]);

}

sub _parse_pages {
    my ($self,$node,$parent_node) = @_;
    $node = $self->_dereference($node);
    return unless defined($node);

    debug('pages',$node);

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
            $self->_parse_action($annot->{'/A'});
        }
    }

}

sub _parse_action {
    my ($self,$action) = @_;
    $action = $self->_dereference($action);
    return unless defined($action);

    if ( $action->{'/S'} eq '/URI' ) {
        my $location = $action->{'/URI'};
        if ( $location =~ /^\w+:\/\// ) {
            $self->{context}->uri($location) if $self->{context}->can('uri');
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
            # $self->_parse_image('image',$ref,$obj,$name);
        } elsif ( $obj->{'/Subtype'} eq '/Form' ) {
            # print "Form: $name $ref\n";
            $obj->{'/Resources'} = $self->_parse_resources($obj->{'/Resources'}) if (defined($obj->{'/Resources'}));
        }
    }
    return $xobject;
}

sub _parse_contents {
    my ($self,$contents,$page) = @_;
    my $core = Mail::SpamAssassin::PDF::Core->new;

    $contents = [ $contents ] if (ref($contents) ne 'ARRAY');

    #@type Mail::SpamAssassin::PDF::Context
    my $context = $self->{context};
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
            my $cmap = Mail::SpamAssassin::PDF::CMap->new();
            if (defined($font->{'/ToUnicode'})) {
                # print "$font->{'/ToUnicode'}\n";
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
            debug('tokens',$token.' '.join(',',@params));
            if ( defined($dispatch{$token}) ) {
                $dispatch{$token}->(@params);
            } else {
                # print "Skipping: $token\n";
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
    # print Dumper($stream_obj);
    my $data = $self->_get_stream_data($stream_obj);

    if ( !defined($stream_obj->{pos}) ) {
        while ( $data =~ /\G\s*(\d+) (\d+)\s+/ ) {
            $stream_obj->{xref}->{$1} = $2;
            pos($data) = $+[0];
            # print "$1 -> $2\n";
        }
        $stream_obj->{pos} = pos($data);
    }

    # print $data,"\n\n";
    # print "$stream_obj_ref, $index, $ref\n";
    # print $stream_obj->{pos}." + ".$stream_obj->{xref}->{$obj},"\n";
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
    $self->register_eval_rule ("pdf_link_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    # $self->register_eval_rule ("pdf_words", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);
    $self->register_eval_rule ("pdf_page_count", $Mail::SpamAssassin::Conf::TYPE_BODY_EVALS);

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

sub pdf_link_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo}->{totals}->{LinkCount});
}

sub pdf_words {
    my ($self, $pms, $body, $min, $max) = @_;

}

sub pdf_page_count {
    my ($self, $pms, $body, $min, $max) = @_;

    return _result_check($min, $max, $pms->{pdfinfo}->{totals}->{PageCount});
}

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