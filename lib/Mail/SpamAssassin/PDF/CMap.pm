package Mail::SpamAssassin::PDF::CMap;
use strict;
use warnings FATAL => 'all';
use Mail::SpamAssassin::PDF::Core;
use Encode qw(encode decode);
use Carp;
use Data::Dumper;

sub new {
    my ($class) = @_;
    bless {
        core => Mail::SpamAssassin::PDF::Core->new(),
        cmap => {}
    },$class;
}

sub convert {
    my ($self,$data) = @_;

    $data = encode('UTF-16BE',$data) unless $data =~ /^\x00/; # hackish way to tell if already UTF-16

    my $str = '';
    for my $code (unpack("n*",$data)) {
        # print "$code,";
        $str .= defined($self->{cmap}->{$code}) ? $self->{cmap}->{$code} : chr($code);
    }
    # print "\n";
    return $str;

}


sub parse_stream {
    my ($self,$stream) = @_;

    my @params;

    while () {
        my ($token,$type) = $self->{core}->get_primitive(\$stream);
        last unless defined($token);
        if ( $type ne 'operator' ) {
            push(@params,$token);
            next;
        }
        if ( $token eq 'beginbfchar') {
            $self->_parse_bfchar(\$stream,$params[0]);
        }

        @params = ();
    }
    # print Dumper($self->{cmap});

}

sub _parse_bfchar {
    my ($self,$ptr,$count) = @_;

    while ($count--) {
        # print substr($$ptr,pos($$ptr),20),"\n";
        $$ptr =~ /\G\s*<([A-Fa-f0-9]+)>\s+<([A-Fa-f0-9]+)>/gc or croak "Invalid cmap format at offset ".pos($$ptr);
        my $key = hex($1);
        my $value = decode('UTF-16BE',pack("H*",$2));
        # print "$key -> $value\n";
        $self->{cmap}->{$key} = $value;
    }
    $$ptr =~ /\G\s*endbfchar/ or croak "Invalid cmap format at offset ".pos($$ptr);

}

1;