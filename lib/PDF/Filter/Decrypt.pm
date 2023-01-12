package PDF::Filter::Decrypt;
use strict;
use warnings FATAL => 'all';
use bytes;
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
