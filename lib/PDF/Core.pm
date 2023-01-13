package PDF::Core;
use strict;
use warnings FATAL => 'all';
use Encode qw(from_to);
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

    return $str;
}

sub get_hex_string {
    my ($self,$ptr) = @_;

    $$ptr =~ /\G\s*<([0-9A-Fa-f]*?)>/g or die "Invalid hex string at offset ".pos($$ptr);
    my $str = $1;
    $str =~ s/\s+//gxms;
    $str .= '0' if (length($str) % 2 == 1);
    return pack("H*",$str);
}

sub get_array {
    my ($self,$ptr) = @_;
    my @array;

    $$ptr =~ /\G\s*\[/g or die "array not found at offset ".pos($$ptr);

    while () {
        $_ = $self->get_primitive($ptr);
        last if $_ eq ']';
        push(@array,$_);
    }

    return \@array;
}

sub get_dict {
    my ($self,$ptr) = @_;

    my @array;

    $$ptr =~ /\G\s*<</g or croak "dict not found at offset ".pos($$ptr);

    while () {
        $_ = $self->get_primitive($ptr);
        croak "Unexpected end of file" unless defined($_);
        last if $_ eq '>>';
        push(@array,$_);
    }
    # print Dumper(\@array);

    my %dict = @array;

    if ( $$ptr =~ /\G\s*stream\r?\n/ ) {
        $dict{_stream_offset} = $+[0];
    }

    return \%dict;

}

sub get_primitive {
    my ($self,$ptr) = @_;

    local $_;

    while () {
        $$ptr =~ /\G\s*( \/[^\/%\(\)\[\]<>{}\s]* | <{1,2} | >> | \[ | \] | \( | \d+\s\d+\sR\b | [-+]?\d+(?:\.\d+)? | [-+]?\.\d+ | true | false | null | \%[^\n]*\n | [^\/%\(\)\[\]<>{}\s]+ | $ )/x or do {
            print substr($$ptr,pos($$ptr)-10,10)."|".substr($$ptr,pos($$ptr),20),"\n";
            croak "Unknown primitive at offset ".pos($$ptr);
        };
        # print "> $1\n";
        if ( $1 eq '<<' ) {
            return $self->get_dict($ptr);
        }
        if ( $1 eq '(' ) {
            return $self->get_string($ptr);
        }
        if ( $1 eq '<' ) {
            return $self->get_hex_string($ptr);
        }
        if ( $1 eq '[' ) {
            return $self->get_array($ptr);
        }
        if ( $1 eq '' ) {
            # EOF
            return undef;
        }

        pos($$ptr) = $+[0]; # Advance the pointer

        if ( substr($1,0,1) eq '%' ) {
            # skip comments
        } else {
            return $1;
        }

    }

}

sub unquote_name {
    my $value = shift;
    $value =~ s/#([\da-f]{2})/chr(hex($1))/ige;
    return $value;
}

1;