package Mail::SpamAssassin::PDF::Context::Info;
use strict;
use warnings FATAL => 'all';
use Mail::SpamAssassin::PDF::Context;
use Digest::MD5 qw(md5_hex);
use Encode qw(decode);
use Data::Dumper;

our @ISA = qw(Mail::SpamAssassin::PDF::Context);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{info} = {
        ImageCount => 0,
        ColorImageCount => 0,
        PageCount  => 0,
        PageArea   => 0,
        ImageArea  => 0,
        ClickArea  => 0,
        LinkCount  => 0,
        OpenAction => 0,
        JavaScript => 0,
        uris       => {}
    };
    $self->{fuzzy_md5} = Digest::MD5->new();
    $self;
}

sub get_info {
    my $self = shift;
    return $self->{info};
}

sub parse_begin {
    my ($self,$parser) = @_;

    $self->add_fuzzy('V:'.$parser->{version});

    my %trailer = %{$parser->{trailer}};
    delete $trailer{'/ID'};
    $self->add_fuzzy(\%trailer);
}

sub page_begin {
    my ($self, $page) = @_;

    $self->add_fuzzy($page);

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

    my $is_color = 1;
    $is_color = 0 if defined($image->{'/ColorSpace'}) && $image->{'/ColorSpace'} =~ /gray/i;
    $is_color = 0 if defined($image->{'/BitsPerComponent'}) && $image->{'/BitsPerComponent'} == 1;

    $self->add_fuzzy($image);

    $self->{info}->{ImageCount}++;
    $self->{info}->{ColorImageCount}++ if $is_color;

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
    my ($self,$location,$rect,$page) = @_;

    $self->add_fuzzy('\URI');

    $self->{info}->{uris}->{$location} = 1;
    $self->{info}->{LinkCount}++;

    if ( defined($rect) ) {
        my ($x1,$y1,$x2,$y2) = @{$rect};
        if ( defined($page->{'/MediaBox'}) ) {
            # clip rectangle to media box
            $x1 = _max($page->{'/MediaBox'}->[0],_min($page->{'/MediaBox'}->[2],$x1));
            $x2 = _max($page->{'/MediaBox'}->[0],_min($page->{'/MediaBox'}->[2],$x2));
            $y1 = _max($page->{'/MediaBox'}->[1],_min($page->{'/MediaBox'}->[3],$y1));
            $y2 = _max($page->{'/MediaBox'}->[1],_min($page->{'/MediaBox'}->[3],$y2));
        }
        $self->{info}->{ClickArea} += abs(($x2-$x1) * ($y2-$y1));
    }
}

sub javascript {
    my ($self, $js) = @_;

    $self->add_fuzzy('\JavaScript');
    $self->{info}->{JavaScript} = 1;
}

sub open_action {
    my ($self, $action) = @_;

    $self->add_fuzzy($action);
    $self->{info}->{OpenAction} = 1;
}

sub parse_end {
    my ($self,$parser) = @_;

    $self->{info}->{Encrypted} = $parser->is_encrypted();
    $self->{info}->{Protected} = $parser->is_protected();
    $self->{info}->{Version} = $parser->{version};

    return if $parser->is_protected();

    $self->{info}->{ImageArea} = _round($self->{info}->{ImageArea},0);
    $self->{info}->{PageArea} = _round($self->{info}->{PageArea},0);
    $self->{info}->{ClickArea} = _round($self->{info}->{ClickArea},0);

    if ( $self->{info}->{PageArea} > 0 ) {
        $self->{info}->{ImageRatio} = _min(100,_round($self->{info}->{ImageArea} / $self->{info}->{PageArea} * 100,2));
        $self->{info}->{ClickRatio} = _min(100,_round($self->{info}->{ClickArea} / $self->{info}->{PageArea} * 100,2));
    } else {
        $self->{info}->{ImageRatio} = 0;
        $self->{info}->{ClickRatio} = 0;
    }

    for (keys %{$parser->{trailer}->{'/Info'}}) {
        my $key = $_;
        $key =~ s/^\///; # Trim leading slash
        $self->{info}->{$key} = $parser->{trailer}->{'/Info'}->{$_};
    }

    # Compute MD5
    my $md5 = Digest::MD5->new();
    my $core = $parser->{core};
    $core->pos(0);
    $md5->addfile($core->{fh});
    $self->{info}->{MD5} = uc($md5->hexdigest());

    # Compute MD5 Fuzzy1
    $self->{info}->{MD5Fuzzy1} = uc($self->{fuzzy_md5}->hexdigest());

    # Compute MD5 Fuzzy2
    # Start at beginning, get comments + first object
    $md5->reset();
    $core->pos(0);
    my $line; my $pos = 0;
    while (defined($line = $core->get_line())) {
        next if $line =~ /^\s*$/; # skip blank lines
        last unless $line =~ /^%/;
        # print "> $line\n";
        $md5->add($line);
        $pos += length($line);
    }

    if ( $line =~ /^\s*(\d+) (\d+) (obj\s*)/g ) {
        $core->pos($pos + $+[3]);
        $md5->add("$1 $2 $3"); # include object number
        $core->{crypt}->set_current_object($1,$2) if defined($core->{crypt});
        my $obj = $core->get_primitive();
        my $str = $self->serialize_fuzzy($obj);
        # print "> $str\n";
        $md5->add($str);
    };

    $self->{info}->{MD5Fuzzy2} = uc($md5->hexdigest());


}

sub add_fuzzy {
    my ($self,$obj) = @_;
    my $data = $self->serialize_fuzzy($obj);
    $self->{fuzzy_md5}->add( $data );
    # print "Fuzzy: $data\n";
}

sub serialize_fuzzy {
    my ($self,$obj) = @_;

    if ( !defined($obj) ) {
        # undef
        return 'U';
    } elsif ( ref($obj) eq 'ARRAY' ) {
        # recurse into arrays
        my $str = '';
        $str .= $self->serialize_fuzzy($_) for @$obj;
        return $str;
    } elsif ( ref($obj) eq 'HASH' ) {
        # recurse into dictionaries
        my $str = '';
        foreach (sort keys %$obj) {
            next unless /^\//;
            $str .= $_ . $self->serialize_fuzzy( $obj->{$_} );
        }
        return $str;
    } elsif ( $obj =~ /^[\d.+-]+$/ ) {
        # number
        return 'N';
    } elsif ( $obj =~ /^D:/ ) {
        # date
        return 'D';
    }

    # include data as-is
    return $obj;

}

sub _round {
    my ($num,$prec) = @_;
    sprintf("%.${prec}f",$num);
}

sub _min {
    my ($x,$y) = @_;
    $x < $y ? $x : $y;
}

sub _max {
    my ($x,$y) = @_;
    $x > $y ? $x : $y;
}

1;