package Mail::SpamAssassin::PDF::Context::Info;
use strict;
use warnings FATAL => 'all';
use Mail::SpamAssassin::PDF::Context;
use Digest::MD5;
use Encode qw(decode);
use Data::Dumper;

our @ISA = qw(Mail::SpamAssassin::PDF::Context);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{info} = {
        ImageCount => 0,
        PageCount  => 0,
        PageArea   => 0,
        ImageArea  => 0,
        ClickArea  => 0,
        LinkCount  => 0,
        uris       => {}
    };
    $self->{fuzzy_md5} = Digest::MD5->new();
    $self->{fuzzy_md5_data} = '';
    $self;
}

sub get_info {
    my $self = shift;
    return $self->{info};
}

sub parse_begin {
    my ($self,$parser) = @_;

    my $fuzzy_data = $self->serialize_fuzzy($parser->{trailer});
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

}

sub page_begin {
    my ($self, $page) = @_;

    my $fuzzy_data = $self->serialize_fuzzy($page);
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

    $self->{info}->{PageCount}++;

    return 0 unless $page->{page_number} == 1;

    # Calculate page area in user space
    $self->{info}->{PageArea} +=
        ($page->{'/MediaBox'}->[2] - $page->{'/MediaBox'}->[0]) *
        ($page->{'/MediaBox'}->[3] - $page->{'/MediaBox'}->[1]);

    return 1;
}

sub draw_image {
    my ($self,$image,$page) = @_;

    my $fuzzy_data = $self->serialize_fuzzy($image);
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

    $self->{info}->{ImageCount}++;

    # print $image->{_name},"\n";

    # Calculate image area in user space
    my $ctm = $self->{gs}->{ctm};
    if ( $ctm->[1] == 0 && $ctm->[2] == 0 ) {
        $self->{info}->{ImageArea} += $ctm->[0] * $ctm->[3];
    } else {
        # Image is rotated, skewed, etc. More complicated
        # The following should be accurate for rotated images but just an approximation for other transformations
        my ($x1,$y1,$x2,$y2) = $self->transform(0,0,1,1);
        $self->{info}->{ImageArea} += abs($x2-$x1) * abs($y2-$y1);
    }

}

sub uri {
    my ($self,$location,$rect) = @_;

    my $fuzzy_data = '/URI';
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;

    $self->{info}->{uris}->{$location} = 1;
    $self->{info}->{LinkCount}++;

    if ( defined($rect) ) {
        $self->{info}->{ClickArea} += abs(($rect->[2]-$rect->[0]) * ($rect->[3]-$rect->[1]));
    }
}

sub parse_end {
    my ($self,$parser) = @_;

    $self->{info}->{ImageArea} = _round($self->{info}->{ImageArea},0);
    $self->{info}->{PageArea} = _round($self->{info}->{PageArea},0);
    $self->{info}->{ClickArea} = _round($self->{info}->{ClickArea},0);

    if ( $self->{info}->{PageArea} > 0 ) {
        $self->{info}->{ImageRatio} = _min(100,_round($self->{info}->{ImageArea} / $self->{info}->{PageArea} * 100,2));
        $self->{info}->{ClickRatio} = _min(100,_round($self->{info}->{ClickArea} / $self->{info}->{PageArea} * 100,2));
    } else {
        $self->{info}->{ImageRatio} = 0;
        $self->{info}->{ClickRatio} = 0;
    }

    for (keys %{$parser->{trailer}->{'/Info'}}) {
        my $key = $_;
        $key =~ s/^\///; # Trim leading slash
        $self->{info}->{$key} = $parser->{trailer}->{'/Info'}->{$_};
    }

    $self->{info}->{Encrypted} = defined($parser->{trailer}->{'/Encrypt'}) ? 1 : 0;
    $self->{info}->{Version} = $parser->{version};
    $self->{info}->{FuzzyMD5} = uc($self->{fuzzy_md5}->hexdigest());
    # $self->{info}->{FuzzyMD5Data} = $self->{fuzzy_md5_data};

}

sub serialize_fuzzy {
    my ($self,$obj) = @_;

    if ( !defined($obj) ) {
        return 'U';
    } elsif ( ref($obj) eq 'ARRAY' ) {
        my $str = '';
        $str .= $self->serialize_fuzzy($_) for @$obj;
        return $str;
    } elsif ( ref($obj) eq 'HASH' ) {
        my $str = '';
        foreach (sort keys %$obj) {
            next unless /^\//;
            $str .= $_ . $self->serialize_fuzzy( $obj->{$_} );
        }
        return $str;
    } elsif ( $obj =~ /^\d+ \d+ R$/ )  {
        return 'R';
    } elsif ( $obj =~ /^[\d.+-]+$/ ) {
        return 'N';
    } elsif ( $obj =~ /^D:/ ) {
        return 'D';
    }

    eval {
        my $tmp = $obj;
        decode('utf-8-strict',$tmp,Encode::FB_CROAK);
    } or return 'B';

    return $obj;

}

sub _round {
    my ($num,$prec) = @_;
    sprintf("%.${prec}f",$num);
}

sub _min {
    my ($x,$y) = @_;
    $x < $y ? $x : $y;
}

1;