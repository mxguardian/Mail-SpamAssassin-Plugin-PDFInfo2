package PDF::FlateDecode;
use strict;
use warnings FATAL => 'all';
use Compress::Zlib;

sub decode {
    my ($data,$params) = @_;

    $data = uncompress($data);
    return $data unless defined($params) && defined($params->{'/Predictor'});

    my $out;
    my $predictor = $params->{'/Predictor'};
    if ( $predictor == 2 ) {
        die "TIFF Predictor not implemented";
    } elsif ( $predictor >= 10 ) {

        # PNG Predictor https://www.rfc-editor.org/rfc/rfc2083#section-6
        my $columns = $params->{'/Columns'} + 1;
        my $length = length($data);

        my @prior = (0) x $columns;
        for( my $i=0; $i<$length; $i+=$columns ) {
            my @out;
            my @row = unpack("x$i C$columns",$data);
            my $alg = shift(@row);

            if ( $alg == 2 ) {
                # PNG "Up" Predictor
                push(@out,($row[$_]+$prior[$_])%256) for (0..$#row)
            } else {
                die "PNG algorithm $alg not implemented";
            }

            $out .= pack('C*',@out);
            # printf "i=$i prior=%s row=%s out=%s\n",join(',',@prior),join(',',@row),join(',',@out);

            @prior = @out;
        }

    } else {
        die "Unknown predictor $predictor";
    }

    return $out;

}

1;