package PDF::Filter::FlateDecode;
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