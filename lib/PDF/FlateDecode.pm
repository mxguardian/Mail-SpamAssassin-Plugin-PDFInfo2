package PDF::FlateDecode;
use strict;
use warnings FATAL => 'all';
use Compress::Zlib;

sub decode {
    my ($data,$params) = @_;

    $data = uncompress($data);
    return $data unless defined($params) && defined($params->{'/Predictor'});

    my $predictor = $params->{'/Predictor'};

    if ( $predictor == 2 ) {
        die "TIFF Predictor not implemented";
    } elsif ( $predictor >= 10 ) {

        my $columns = $params->{'/Columns'};
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

    } else {
        die "Unknown predictor $predictor";
    }

}

1;