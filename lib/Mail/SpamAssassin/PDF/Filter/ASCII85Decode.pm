package Mail::SpamAssassin::PDF::Filter::ASCII85Decode;
use strict;
use warnings FATAL => 'all';
use Convert::Ascii85;

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub decode {
    my ($self, $data) = @_;
    Convert::Ascii85::decode($data);
}

1;