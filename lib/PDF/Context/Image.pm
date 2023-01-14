use strict;
use warnings FATAL => 'all';
package PDF::Context::Image;
use PDF::Context;
use Image::Magick;


our @ISA = qw(PDF::Context);

sub page_begin {
    my ($self,$page) = @_;

    $self->reset_state();

    my $page_number = $page->{page_number};
    my $size = $page->{'/MediaBox'}->[2].'x'.$page->{'/MediaBox'}->[3];

    print "Page=$page_number Size=$size\n";

    $self->{canvas} = Image::Magick->new(size=>$size);
    $self->{canvas}->ReadImage('canvas:white');

}

sub draw_image {
    my ($self,$image,$page) = @_;
    my ($a,$b,$c,$d,$e,$f) = @{$self->{gs}->{ctm}};

    my $h = $self->{canvas}->get('height');
    my $points = sprintf("%d,%d %d,%d",$e, $h-$f, $a+$e, $h-($d+$f));
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
        my $points = sprintf("%d,%d %d,%d",$x,$y,$w,$h);
        $self->{canvas}->Draw(primitive=>'rectangle', stroke=>'black', fill=>'gray', points=>$points);

    }
}
