use strict;
use warnings FATAL => 'all';
package PDF::Context;
use Storable qw(dclone);

sub new {
    my ($class) = @_;

    my $self = {
    };

    bless $self,$class;
}

sub reset_state {
    my $self = shift;

    # Graphics state
    $self->{gs} = {
        ctm => [ 1, 0, 0, 1, 0, 0 ] # Current Transformation Matrix
    };

    $self->{stack} = [];
}

sub save_state {
    my $self = shift;
    push(@{$self->{stack}},dclone $self->{gs});
}

sub restore_state {
    my $self = shift;
    $self->{gs} = pop(@{$self->{stack}});
}

sub concat_matrix {
    my ($self,$m) = @_;

    my $n = $self->{gs}->{ctm};
    
    $self->{gs}->{ctm} = [
        $m->[0]*$n->[0] + $m->[1]*$n->[2],
        $m->[0]*$n->[1] + $m->[1]*$n->[3],
        $m->[2]*$n->[0] + $m->[3]*$n->[2],
        $m->[2]*$n->[1] + $m->[3]*$n->[3],
        $m->[4]*$n->[0] + $m->[5]*$n->[2] + $n->[4],
        $m->[4]*$n->[1] + $m->[5]*$n->[3] + $n->[5]
    ];
}

1;