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

    } elsif ( $self->{R} >= 3 ) {

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
