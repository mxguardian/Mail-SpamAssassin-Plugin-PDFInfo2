package PDF::Core;
use strict;
use warnings FATAL => 'all';
use Carp;
use Data::Dumper;

sub _get_string {
    my ($ptr) = @_;

    $$ptr =~ /\G\s*\(/g or die "string not found";

    $$ptr =~ /\G(.*?)(?<!\\)\)/g or die "Invalid string";
    return $1;
}

sub _get_hex_string {
    my ($ptr) = @_;

    $$ptr =~ /\G\s*<([0-9A-Fa-f]*?)>/g or die "Invalid hex string";
    return $1;
}

sub _get_array {
    my ($ptr) = @_;
    my @array;

    $$ptr =~ /\G\s*\[/g or die "array not found";

    while () {
        $_ = _get_primitive($ptr);
        last if $_ eq ']';
        push(@array,$_);
    }

    return \@array;
}

sub _get_dict {
    my ($ptr) = @_;

    my @array;

    $$ptr =~ /\G\s*<</g or die "dict not found";

    while () {
        $_ = _get_primitive($ptr);
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
    my ($ptr) = @_;

    $$ptr =~ /\G\s*( \/[^\/%\(\)\[\]<>{}\s]+ | <{1,2} | >> | \[ | \] | \( | \d+\s\d+\sR\b | -?\d+(\.\d+)? | true | false )/x or do {
        print substr($$ptr,pos($$ptr)-10,10)."|".substr($$ptr,pos($$ptr),20),"\n";
        croak "Unknown primitive at offset ".pos($$ptr);
    };
    # print "> $1\n";
    if ( $1 eq '<<' ) {
        my $dict = _get_dict($ptr);
        return $dict;
    }
    if ( $1 eq '(' ) {
        return _get_string($ptr);
    }
    if ( $1 eq '<' ) {
        return _get_hex_string($ptr);
    }
    if ( $1 eq '[' ) {
        return _get_array($ptr);
    }

    pos($$ptr) = $+[0];

    return $1;

}

1;