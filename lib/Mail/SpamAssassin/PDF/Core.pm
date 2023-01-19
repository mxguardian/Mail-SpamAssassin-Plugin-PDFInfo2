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