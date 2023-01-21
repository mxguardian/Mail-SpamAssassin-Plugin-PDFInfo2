package Mail::SpamAssassin::PDF::Context::Info;
use strict;
use warnings FATAL => 'all';
use Mail::SpamAssassin::PDF::Context;
use Digest::MD5;
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
    my ($self,$location) = @_;

    my $fuzzy_data = '/URI';
    $self->{fuzzy_md5}->add( $fuzzy_data );
    $self->{fuzzy_md5_data} .= $fuzzy_data;


    $self->{info}->{uris}->{$location} = 1;
    $self->{info}->{LinkCount}++;

}

sub parse_end {
    my ($self,$parser) = @_;

    $self->{info}->{ImageArea} = sprintf(
        "%.0f",
        $self->{info}->{ImageArea}
    );

    $self->{info}->{PageArea} = sprintf(
        "%.0f",
        $self->{info}->{PageArea}
    );

    $self->{info}->{ImageDensity} = sprintf(
        "%.2f",
        $self->{info}->{ImageArea} / $self->{info}->{PageArea} * 100
    );

    for (keys %{$parser->{trailer}->{'/Info'}}) {
        my $key = $_;
        $key =~ s/^\///; # Trim leading slash
        $self->{info}->{$key} = $parser->{trailer}->{'/Info'}->{$_};
    }

    $self->{info}->{Encrypted} = defined($parser->{trailer}->{'/Encrypt'}) ? 1 : 0;
    $self->{info}->{Version} = $parser->{version};
    $self->{info}->{FuzzyMD5} = uc($self->{fuzzy_md5}->hexdigest());

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

    return $obj;

}

1;