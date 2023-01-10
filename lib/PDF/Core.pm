package PDF::Core;
use strict;
use warnings FATAL => 'all';

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

    my %dict = @array;

    if ( $$ptr =~ /\G\s*stream\r?\n/ ) {
        $dict{_offset} = $+[0];
    }

    return \%dict;

}

sub _get_stream_data {
    my ($ptr,$stream_obj) = @_;

    return $stream_obj->{_stream} if defined($stream_obj->{_stream});

    my $offset = $stream_obj->{'_offset'};
    my $length = $stream_obj->{'/Length'};
    my $filter = $stream_obj->{'/Filter'} || '';

    if ( $filter eq '/FlateDecode' ) {
        return $stream_obj->{_stream} = _flate_decode(
            substr($$ptr,$offset,$length),
            $stream_obj->{'/DecodeParms'}->{'/Predictor'},
            $stream_obj->{'/DecodeParms'}->{'/Columns'},
        );
    }

    return substr($$ptr,$offset,$length);
}

sub _flate_decode {
    my ($data,$predictor,$columns) = @_;

    $data = uncompress($data);
    return $data unless defined($predictor);

    my $length = length($data);
    my $out;

    my @prior = (0) x $columns;
    for( my $i=0; $i<$length; $i+=($columns+1) ) {
        my $template = 'x'.$i.'C'.($columns+1);
        my @row = unpack($template,$data);
        my $alg = shift(@row);
        my @out;

        for( my $x=0; $x<scalar(@row);$x++) {
            if ( $alg == 2 ) {
                push(@out,($row[$x]+$prior[$x])%256);
            } else {
                die "Unknown algorithm: $alg";
            }
        }

        $out .= pack('C*',@out);
        # printf "i=$i prior=%s row=%s out=%s\n",join(',',@prior),join(',',@row),join(',',@out);

        @prior = ( @out );
    }

    return $out;

}

sub _get_primitive {
    my ($ptr) = @_;

    $$ptr =~ /\G\s*(\/\w+|<{1,2}|>>|\[|\]|\(|\d+ \d+ R\b|\d+(\.\d+)?|true|false)/ or die "Unknown primitive at offset ".pos($$ptr);
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