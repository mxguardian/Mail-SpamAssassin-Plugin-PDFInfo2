package Mail::SpamAssassin::PDF::Context::Image;
use strict;
use warnings FATAL => 'all';
use Mail::SpamAssassin::PDF::Context;
use Image::Magick;

our @ISA = qw(Mail::SpamAssassin::PDF::Context);

=head1 SYNOPSIS

 Creates a representational image for each page of a PDF.

 - Images are shown as a gray box with a red border
 - Text is omitted
 - Vector graphics are drawn with a black line and no fill
 - Clickable areas are shaded blue

 Files are output in PNG format and named page-000.png, page-001.png, etc...

 This is mainly used for testing to make sure the parser is working correctly. This is not part of the distribution
 package.

=cut

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
    $self->{uris} = [];
    return 1;
}

sub draw_image {
    my ($self,$image,$page) = @_;
    my ($a,$b,$c,$d,$e,$f) = @{$self->{gs}->{ctm}};

    my $points = sprintf("%d,%d %d,%d",$self->transform(0,0,1,1));
    $self->{canvas}->Draw(primitive=>'rectangle', stroke=>'red',fill=>'gray', points=>$points);
}

sub uri {
    my ($self,$location,$rect) = @_;
    return unless defined($rect);
    push(@{$self->{uris}},$rect);
}

sub page_end {
    my ($self,$page) = @_;
    my $page_number = $page->{page_number};

    foreach (@{$self->{uris}}) {
        my ($x,$y,$w,$h) = @$_;
        my $points = sprintf("%d,%d %d,%d",$self->transform(@$_));
        $self->{canvas}->Draw(primitive=>'rectangle', stroke=>'none', fill => 'rgba( 0, 0, 255 , 0.5 )', points=>$points);
    }

    my $filename = sprintf("page-%03d.png",$page_number);
    print "Writing file $filename\n";
    $self->{canvas}->write($filename);

}

sub rectangle {
    my ($self,@params) = @_;
    my ($x,$y,$w,$h) = @params;
    my $points = sprintf("%d,%d %d,%d",$self->transform($x,$y,$x+$w,$y+$h));
    $self->{canvas}->Draw(primitive=>'rectangle', stroke=>'black', fill => 'none', points=>$points);
}

sub path_move {
    my ($self,@pos) = @_;
    $self->{path} .= sprintf("M %d,%d ",$self->transform(@pos));
    $self->{pos} = [ @pos ];

}

sub path_line {
    my ($self,@pos) = @_;
    $self->{path} .= sprintf("L %d,%d ",$self->transform(@pos));
    $self->{pos} = [ @pos ];

}

sub path_curve {
    my ($self,@pos) = @_;
    $pos[0] = $self->{pos}->[0] if !defined($pos[0]);
    $pos[1] = $self->{pos}->[1] if !defined($pos[1]);
    $pos[2] = $pos[4] if !defined($pos[2]);
    $pos[3] = $pos[5] if !defined($pos[3]);

    $self->{path} .= sprintf("C %d,%d %d,%d %d,%d ",$self->transform(@pos));
    $self->{pos} = [ $pos[4] , $pos[5] ];
}

sub path_close {
    my ($self) = @_;
    $self->{path} .= 'Z ';
}

sub path_draw {
    my ($self,$stroke,$fill) = @_;
    return unless defined($self->{path});
    $self->{canvas}->Draw(
        primitive => 'path',
        stroke    => 'black', #$stroke ? 'black' : 'none',
        fill      => 'none', #$fill ? 'black' : 'none',
        points    => $self->{path}
    );
    $self->{path} = '';
}

sub path_end {
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
