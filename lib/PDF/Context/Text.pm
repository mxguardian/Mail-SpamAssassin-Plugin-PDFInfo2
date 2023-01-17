use strict;
use warnings FATAL => 'all';
package PDF::Context::Text;
use PDF::Context;
use Encode qw(from_to);
use Data::Dumper;

our @ISA = qw(PDF::Context);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self;
}

sub text_begin {
    my ($self) = @_;
    $self->{tm} = [ 1, 0, 0, 1, 0, 0 ];  # Text matrix
    $self->{tlm} = [ 1, 0, 0, 1, 0, 0 ]; # Text line matrix
    $self->{trm} = [];
}

sub text_font {
    my ($self,$font,$cmap) = @_;
    $self->{cmap} = $cmap;
}

sub text {
    my ($self,$text) = @_;
    # print $text,"\n";
    # print unpack("H*",$text),"\n";
    print $self->{cmap}->to_utf8($text);
    # exit;
}

sub text_newline {
    print "\n";
}
