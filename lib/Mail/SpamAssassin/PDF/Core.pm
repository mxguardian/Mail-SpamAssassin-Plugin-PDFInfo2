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

use constant CHAR_SPACE => 0;
use constant CHAR_NUM   => 1;
use constant CHAR_ALPHA => 2;
use constant CHAR_TERM  => 3;

use constant TYPE_NUM     => 0;
use constant TYPE_OP      => 1;
use constant TYPE_STR     => 2;
use constant TYPE_NAME    => 3;
use constant TYPE_REF     => 4;
use constant TYPE_ARRAY   => 5;
use constant TYPE_DICT    => 6;
use constant TYPE_STREAM  => 7;

my %specials = (
    'n' => "\n",
    'r' => "\r",
    't' => "\t",
    'b' => "\b",
    'f' => "\f",
);

my %class_map;
$class_map{$_} = CHAR_SPACE for split //, " \n\r\t\f\b";
$class_map{$_} = CHAR_NUM   for qw( 0 1 2 3 4 5 6 7 8 9 . + - );
$class_map{$_} = CHAR_ALPHA for qw( a b c d e f g h i j k l m n o p q r s t u v w x y z );
$class_map{$_} = CHAR_ALPHA for qw( A B C D E F G H I J K L M N O P Q R S T U V W X Y Z );
$class_map{$_} = CHAR_ALPHA for qw( _ * );
$class_map{$_} = CHAR_TERM  for split //, "[]<>(){}/";


sub new {
    my ($class,$fh) = @_;
    bless {fh=>$fh},$class;
}

=item clone($fh)

Returns a new instance of the object with the same state as the original, but
using the new file handle.

=cut

sub clone {
    my ($self,$fh) = @_;
    my $copy = bless { %$self }, ref $self;
    $copy->{fh} = $fh;
    return $copy;
}

=item pos($offset)

Sets the file pointer to the specified offset.

=cut

sub pos {
    my ($self,$offset) = @_;
    defined($offset) ? seek($self->{fh},$offset,0) : tell($self->{fh});
}

sub get_name {
    my ($self) = @_;
    my $fh = $self->{fh};

    {
        my $offset = tell($fh);
        unless (getc($fh) eq '/') {
            seek($fh, $offset, 0);
            croak "Name not found at offset $offset";
        }
    }

    my $name = '/';
    while (defined(my $ch = getc($fh))) {
        my $class = $class_map{$ch};
        if ( defined($class) && $class == CHAR_ALPHA) {
            $name .= $ch;
            next;
        } else {
            seek($fh, -1, 1);
            last;
        }
    }
    return wantarray ? ($name,TYPE_NAME) : $name;
}


sub get_string {
    my ($self) = @_;
    my $fh = $self->{fh};

    {
        my $offset = tell($fh);
        unless (getc($fh) eq '(') {
            seek($fh, $offset, 0);
            croak "string not found at offset $offset";
        }
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

    return wantarray ? ($str,TYPE_STR) : $str;
}

sub get_number {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $num = '';
    while (defined(my $ch = getc($fh))) {
        my $class = $class_map{$ch};
        if ( defined($class) && $class == CHAR_NUM) {
            $num .= $ch;
            next;
        } elsif ( length($num) ) {
            seek($fh, -1, 1);
            last;
        } elsif ( defined($class) && $class == CHAR_SPACE) {
            # skip leading spaces
            next;
        } else {
            seek($fh, -1, 1);
            croak "Number expected, got '$ch' at offset " . tell($fh);
        }
    }
    $num += 0;
    return wantarray ? ($num,TYPE_NUM) : $num;
}


=item assert_token($literal)

Get the next token from the file and croak if it doesn't match the specified literal.

=cut

sub assert_token {
    my ($self,$literal) = @_;
    my $fh = $self->{fh};

    my $token = '';
    my $last_class;
    while (defined(my $ch = getc($fh))) {
        my $class = $class_map{$ch};
        die "unknown char $ch" unless defined($class);
        if ( defined($last_class) && $class != $last_class ) {
            if ($last_class == CHAR_SPACE ) {
                # skip leading spaces
                $token = '';
            } else {
                seek($fh, -1, 1);
                last;
            }
        }
        $last_class = $class;
        $token .= $ch;
    }
    if ($token ne $literal) {
        seek($fh, -length($token), 1);
        croak "Expected '$literal', got '$token' at offset " . tell($fh);
    }

}

sub get_hex_string {
    my ($self) = @_;
    my $fh = $self->{fh};

    {
        my $offset = tell($fh);
        unless (getc($fh) eq '<') {
            seek($fh, $offset, 0);
            croak "hex string not found at offset " . tell($fh);
        }
    }

    my $hex = '';
    while ( defined(my $ch = getc($fh)) ) {
        last if $ch eq '>';
        next if $ch =~ /\s/;
        die "Invalid hex string" unless $ch =~ /[0-9a-fA-F]/;
        $hex .= $ch;
    }
    $hex .= '0' if (length($hex) % 2 == 1);
    my $str = pack("H*",$hex);

    # decrypt
    if ( defined($self->{crypt}) ) {
        $str = $self->{crypt}->decrypt($str);
    }

    if ( substr($str,0,2) eq "\xFE\xFF" ) {
        from_to($str,'UTF-16be', 'UTF-8');
    } elsif ( $str =~ s/^\xff\xfe// ) {
        from_to($str,'UTF-16le', 'UTF-8');
    }
    return  wantarray ? ($str,TYPE_STR) : $str;
}

sub get_array {
    my ($self) = @_;
    my $fh = $self->{fh};
    my @array;

    {
        my $offset = tell($fh);
        unless (getc($fh) eq '[') {
            seek($fh, $offset, 0);
            croak "Array not found at offset $offset";
        }
    }

    while () {
        ($_) = $self->get_primitive($fh);
        last if $_ eq ']';
        push(@array,$_);
    }

    return wantarray ? (\@array,TYPE_ARRAY) : \@array;
}

sub get_dict {
    my ($self) = @_;
    my $fh = $self->{fh};
    my @array;

    $self->assert_token('<<');

    print tell($fh),"\n";

    while () {
        $_ = $self->get_primitive();
        print Dumper($_);
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
    ($_) = $self->get_primitive();
    if ($_ eq 'stream') {
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
    } else {
        seek($fh, $offset, 0);
    }

    return wantarray ? (\%dict,TYPE_DICT) : \%dict;

}


sub get_primitive {
    my ($self) = @_;
    my $fh = $self->{fh};

    my $last_class;
    my $buf = '';
    while (defined(my $ch = getc($fh))) {
        if ( $ch eq '/' ) {
            seek($fh, -1, 1);
            return $self->get_name($fh);
        }
        if ( $ch eq '<' ) {
            if (getc($fh) eq '<') {
                seek($fh, -2, 1);
                return $self->get_dict($fh);
            } else {
                seek($fh, -2, 1);
                return $self->get_hex_string($fh);
            }
        }
        if ( $ch eq '[' ) {
            seek($fh, -1, 1);
            return $self->get_array($fh);
        }
        if ( $ch eq '(' ) {
            seek($fh, -1, 1);
            return $self->get_string($fh);
        }
        if ( index(')]', $ch) >= 0 ) {
            # single char terminator
            return wantarray ? ($ch,CHAR_TERM) : $ch;
        }
        if ( $ch eq '>' ) {
            if ( getc($fh) eq '>' ) {
                # double char terminator
                return wantarray ? ('>>',CHAR_TERM) : '>>';
            }
            seek($fh, -1, 1);
        }
        my $class = $class_map{$ch};
        die "unknown char $ch" unless defined($class);
        if ( $class == CHAR_NUM ) {
            return $self->_get_num_or_ref($ch);
        }
        if ( defined($last_class) && $class != $last_class ) {
            if ($last_class == CHAR_SPACE ) {
                $buf = '';
            } else {
                seek($fh, -1, 1);
                last;
            }
        }
        $buf .= $ch;
        $last_class = $class;
    }

    if (!defined($last_class) || $last_class != CHAR_SPACE) {
        # EOF
        return (undef,undef);
    } elsif ( $last_class == CHAR_ALPHA ) {
        return wantarray ? ($buf,TYPE_OP) : $buf;
    } else {
        # shouldn't happen
        return wantarray ? ($buf,undef) : $buf;
    }

}

=item _get_num_or_ref($fh,$ch)

Reads a number or reference from the file. A number can be an integer or a real number. A reference is two non-negative
integers separated by a space, followed by 'R' (eg. '0 15 R').  The file pointer is left at the first character after
the number or reference.

If $ch is provided, it is used as the first character of the number or reference.  Otherwise, the first character is
read from the file.

=cut

sub _get_num_or_ref {
    my ($self,$ch) = @_;
    my $fh = $self->{fh};
    my $state = 0;
    my ($buf,$num,$ref) = ('','','');
    my $last_class;
    $ch = getc($fh) unless defined($ch);
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
        if ( defined($last_class) && $class != $last_class ) {

            if ( $last_class == CHAR_SPACE ) {
                # skip leading spaces
                $buf = '';
            } elsif ( $last_class == CHAR_NUM ) {
                if ($state == -1) {
                    # found a real number so we're done
                    $num = $buf;
                    last;
                } elsif ($state == 0) {
                    # save the first number and keep looking
                    $num = $buf;
                    $buf = '';
                    $state = 1;
                }
                elsif ($state == 1) {
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
        return wantarray ? ($ref,'ref') : $ref;
    }

    seek($fh, -length($ref)+length($num), 1);
    return wantarray ? ($num,'number') : $num;
}

sub unquote_name {
    my $value = shift;
    $value =~ s/#([\da-f]{2})/chr(hex($1))/ige;
    return $value;
}

=back

=cut

1;