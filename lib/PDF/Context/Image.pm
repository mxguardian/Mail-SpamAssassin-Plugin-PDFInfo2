use strict;
use warnings FATAL => 'all';
package PDF::Context::Image;
use PDF::Context;
use Image::Magick;

our @ISA = qw(PDF::Context);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{path} = '';
    $self;
}

sub page_begin {
    my ($self,$page) = @_;

    $self->reset_state();

    my $page_number = $page->{page_number};

    my $size = sprintf("%dx%d",$self->SUPER::transform($page->{'/MediaBox'}->[2],$page->{'/MediaBox'}->[3]));

    print "Creating page=$page_number Size=$size\n";

    $self->{canvas} = Image::Magick->new(size=>$size);
    $self->{canvas}->ReadImage('canvas:white');
    return 1;
}

sub draw_image {
    my ($self,$image,$page) = @_;
    my ($a,$b,$c,$d,$e,$f) = @{$self->{gs}->{ctm}};

    my $points = sprintf("%d,%d %d,%d",$self->transform(0,0,1,1));
    $self->{canvas}->Draw(primitive=>'rectangle', fill=>'gray', points=>$points);
}

sub page_end {
    my ($self,$page) = @_;
    my $page_number = $page->{page_number};

    my $filename = sprintf("page-%03d.png",$page_number);
    print "Writing file $filename\n";
    $self->{canvas}->write($filename);

}

sub draw_shape {
    my ($self,$shape,@params) = @_;
    if ( $shape eq 'rect' ) {
        my ($x,$y,$w,$h) = @params;
        my $points = sprintf("%d,%d %d,%d",$self->transform($x,$y,$x+$w,$y+$h));
        $self->{canvas}->Draw(primitive=>'rectangle', stroke=>'black', fill => 'none', points=>$points);
    }
}

sub move {
    my ($self,@pos) = @_;
    $self->{path} .= sprintf("M %d,%d ",$self->transform(@pos));
    $self->{pos} = [ @pos ];

}

sub line {
    my ($self,@pos) = @_;
    $self->{path} .= sprintf("L %d,%d ",$self->transform(@pos));
    $self->{pos} = [ @pos ];

}

sub curve {
    my ($self,@pos) = @_;
    $pos[0] = $self->{pos}->[0] if !defined($pos[0]);
    $pos[1] = $self->{pos}->[1] if !defined($pos[1]);
    $pos[2] = $pos[4] if !defined($pos[2]);
    $pos[3] = $pos[5] if !defined($pos[3]);

    $self->{path} .= sprintf("C %d,%d %d,%d %d,%d ",$self->transform(@pos));
    $self->{pos} = [ $pos[4] , $pos[5] ];
}

sub close_path {
    my ($self) = @_;
    $self->{path} .= 'Z ';
}

sub stroke {
    my ($self) = @_;
    return unless defined($self->{path});
    $self->{canvas}->Draw(primitive=>'path',stroke=>'black',fill=>'none',points=>$self->{path});
    $self->{path} = '';
}

sub fill {
    my ($self) = @_;
    return unless defined($self->{path});
    $self->{canvas}->Draw(primitive=>'path',stroke=>'black',fill=>'none',points=>$self->{path});
    $self->{path} = '';
}

sub fill_and_stroke {
    my ($self) = @_;
    return unless defined($self->{path});
    $self->{canvas}->Draw(primitive=>'path',stroke=>'black',fill=>'none',points=>$self->{path});
    $self->{path} = '';
}

sub end_path {
    my ($self) = @_;
    $self->{path} = '';
}

sub transform {
    my $self = shift;
    my $h = $self->{canvas}->get('height');

    my @out = $self->SUPER::transform(@_);
    # flip vertically
    for(my $i=1;$i<=$#out;$i+=2) {
        $out[$i] = $h - $out[$i];
    }
    @out;
}
