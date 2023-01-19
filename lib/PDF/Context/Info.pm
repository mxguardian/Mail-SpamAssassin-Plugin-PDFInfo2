package PDF::Context::Info;
use strict;
use warnings FATAL => 'all';
use PDF::Context;
use Data::Dumper;

our @ISA = qw(PDF::Context);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{info} = {
        ImageCount => 0,
        PageCount  => 0,
        PageArea   => 0,
        ImageArea  => 0
    };
    $self;
}

sub get_info {
    my $self = shift;
    return $self->{info};
}

sub page_begin {
    my ($self, $page) = @_;

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

sub parse_complete {
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

}


1;