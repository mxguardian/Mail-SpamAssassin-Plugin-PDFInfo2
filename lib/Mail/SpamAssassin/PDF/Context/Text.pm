use strict;
use warnings FATAL => 'all';
package Mail::SpamAssassin::PDF::Context::Text;
use Mail::SpamAssassin::PDF::Context;
use Encode qw(from_to);
use Data::Dumper;

our @ISA = qw(Mail::SpamAssassin::PDF::Context);

=head1 SYNOPSIS

 Extracts text from a PDF.

 Too slow to be useful. Leaving code here for reference
 
=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{text} = '';
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
    $self->{text} .= $self->{cmap}->convert($text);
}

sub text_newline {
    shift->{text} .= "\n";
}
