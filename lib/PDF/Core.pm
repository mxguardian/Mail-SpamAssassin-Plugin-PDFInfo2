package PDF::Core;
use strict;
use warnings FATAL => 'all';
use bytes;
use Carp;
use Data::Dumper;

sub new {
    my ($class) = @_;
    bless {},$class;
}

sub _get_string {
    my ($self,$ptr) = @_;

    $$ptr =~ /\G\s*\(/g or die "string not found";

    $$ptr =~ /\G(.*?)(?<!\\)\)/g or die "Invalid string";

    my $str = unquote_string($1);

    if ( defined($self->{crypt}) ) {
        return $self->{crypt}->decrypt($str);
    }
    return $str;
}

sub _get_hex_string {
    my ($self,$ptr) = @_;

    $$ptr =~ /\G\s*<([0-9A-Fa-f]*?)>/g or die "Invalid hex string";
    return pack("H*",$1);
}

sub _get_array {
    my ($self,$ptr) = @_;
    my @array;

    $$ptr =~ /\G\s*\[/g or die "array not found";

    while () {
        $_ = $self->_get_primitive($ptr);
        last if $_ eq ']';
        push(@array,$_);
    }

    return \@array;
}

sub _get_dict {
    my ($self,$ptr) = @_;

    my @array;

    $$ptr =~ /\G\s*<</g or die "dict not found";

    while () {
        $_ = $self->_get_primitive($ptr);
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

sub _get_primitive {
    my ($self,$ptr) = @_;

    while () {
        $$ptr =~ /\G\s*( \/[^\/%\(\)\[\]<>{}\s]+ | <{1,2} | >> | \[ | \] | \( | \d+\s\d+\sR\b | -?\d+(?:\.\d+)? | true | false | \%[^\n]*\n )/x or do {
            print substr($$ptr,pos($$ptr)-10,10)."|".substr($$ptr,pos($$ptr),20),"\n";
            croak "Unknown primitive at offset ".pos($$ptr);
        };
        # print "> $1\n";
        if ( $1 eq '<<' ) {
            return $self->_get_dict($ptr);
        }
        if ( $1 eq '(' ) {
            return $self->_get_string($ptr);
        }
        if ( $1 eq '<' ) {
            return $self->_get_hex_string($ptr);
        }
        if ( $1 eq '[' ) {
            return $self->_get_array($ptr);
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

sub unquote_string {
    my $value = shift;

    $value =~ s/\x00+$//;  # remove trailing null chars

    my %quoted = ("n" => "\n", "r" => "\r",
        "t" => "\t", "b" => "\b",
        "f" => "\f", "\\" => "\\",
        "(" => "(", ")" => ")");

    $value =~ s/\\([nrtbf\\()]|[0-7]{1,3})/
        defined ($quoted{$1}) ? $quoted{$1} : chr(oct($1))/gex;

    return $value;
}


1;