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
$class_map{$_} = CHAR_ALPHA         for split //, 'abcdefghijklmnopqrstuvwxyz*';
$class_map{$_} = CHAR_ALPHA         for split //, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_';
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
        if ( defined($class) && ($class == CHAR_ALPHA || $class == CHAR_NUM )) {
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
            local $/ = "\n";
            my $comment = $ch.readline($fh);
            return wantarray ? ($comment,TYPE_COMMENT) : $comment;
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
    while (defined(my $ch = getc($fh))) {
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