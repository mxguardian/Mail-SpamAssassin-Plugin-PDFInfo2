package PDF::Parser;
use strict;
use warnings FATAL => 'all';
use PDF::Core;
use PDF::Filter::FlateDecode;
use PDF::Filter::Decrypt;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Carp;

my $debug;  # debugging level

sub new {
    my ($class,%opts) = @_;

    my $self = bless {
        xref         => {},
        trailer      => {},
        pages        => [],
        images       => {},
        core         => PDF::Core->new(),

        events => $opts{events},

        object_cache => {},
        stream_cache => {},
    }, $class;

    $debug = $opts{debug};

    $self;
}

sub parse {
    my ($self,$data) = @_;

    $data =~ /^%PDF\-(\d\.\d)/ or croak("PDF magic header not found");

    $self->{version} = $1;
    $self->{data} = $data;
    $self->{info} = {
        links  => 0,
        uris   => {},
        pages  => 0,
        images => {
            count => 0,
            area  => 0,
        },
    };

    # Parse cross-reference table (and trailer)
    $self->{data} =~ /(\d+)\s+\%\%EOF\s*$/ or die "EOF marker not found";
    $self->_parse_xref($1);

    # Parse encryption dictionary
    $self->_parse_encrypt($self->{trailer}->{'/Encrypt'}) if defined($self->{trailer}->{'/Encrypt'});

    # Parse info object
    $self->{trailer}->{'/Info'} = $self->_get_obj($self->{trailer}->{'/Info'});
    $self->{trailer}->{'/Root'} = $self->_get_obj($self->{trailer}->{'/Root'});

    # Parse catalog
    my $root = $self->{trailer}->{'/Root'};
    if (defined($root->{'/OpenAction'}) && ref($root->{'/OpenAction'}) eq 'HASH') {
        $self->_parse_action($root->{'/OpenAction'});
    }

    # Parse page tree
    $root->{'/Pages'} = $self->_parse_pages($root->{'/Pages'});

    $self->{info}->{images}->{count} = grep { $self->{images}->{$_}->{type} eq 'image' } keys %{$self->{images}};

}

sub get_page_count {
    my $self = shift;
    scalar(@{$self->{pages}});
}

sub get_image_count {
    my $self = shift;
    scalar(keys %{$self->{images}});
}

###################
# Private methods
###################
sub _parse_xref {
    my ($self,$pos) = @_;

    pos($self->{data}) = $pos;

    if ( $self->{data} =~ /\G\s*\d+ \d+ obj\s+/) {
        return $self->_parse_xref_stream($+[0]);
    }
    $self->{data} =~ /\G\s*xref\s+/g or die "xref not found at position $pos";

    while ($self->{data} =~ /\G(\d+) (\d+)\s+/) {
        pos($self->{data}) = $+[0]; # advance the pointer
        my ($start,$count) = ($1,$2);
        # print "xref $start $count\n";
        for (my ($i,$n)=($start,0);$n<$count;$i++,$n++) {
            $self->{data} =~ /\G(\d+) (\d+) (f|n)\s+/g or die "Invalid xref entry";
            # print "$1 $2 $3\n";
            next unless $3 eq 'n';
            my ($offset,$gen) = ($1+0,$2+0);
            my $key = "$i $gen R";
            # print "$key = $offset\n";
            $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
        }
    }

    $self->{data} =~ /\G\s*trailer\s+/g or die "trailer not found";

    my $trailer = $self->{core}->get_dict(\$self->{data});
    $self->{trailer} = {
        %{$trailer},
        %{$self->{trailer}}
    };

    if ( defined($trailer->{'/Prev'}) ) {
        $self->_parse_xref($trailer->{'/Prev'});
    }

}

sub _parse_xref_stream {
    my ($self,$pos) = @_;

    pos($self->{data}) = $pos;

    my $xref = $self->{core}->get_dict(\$self->{data});
    # print Dumper($xref);
    my ($start,$count) = (0,$xref->{'/Size'});
    if ( defined($xref->{'/Index'}) ) {
        $start = $xref->{'/Index'}->[0];
        $count = $xref->{'/Index'}->[1];
    }
    my $width = $xref->{'/W'}->[0] + $xref->{'/W'}->[1] + $xref->{'/W'}->[2];
    my $template = 'H'.($xref->{'/W'}->[0]*2).'H'.($xref->{'/W'}->[1]*2).'H'.($xref->{'/W'}->[2]*2);

    my $data = $self->_get_stream_data($xref);

    for ( my ($i,$n,$o)=($start,0,0); $n<$count; $i++,$n++,$o+=$width ) {
        my ($type,@fields) = map { hex($_) } unpack("x$o $template",$data);
        # print join(',',@fields),"\n";
        if ( $type == 0 ) {
            next;
        } elsif ( $type == 1 ) {
            my ($offset,$gen) = @fields;
            my $key = "$i $gen R";
            # print "$key = $offset\n";
            $self->{xref}->{$key} = $offset unless defined($self->{xref}->{$key});
        } elsif ( $type == 2 ) {
            my ($obj,$index) = @fields;
            my $key = "$i 0 R";
            # print "$key = $obj,$index\n";
            $self->{xref}->{$key} = [ "$obj 0 R", $index ] unless defined($self->{xref}->{$key});
        }
    }

    $self->{trailer} = $xref;

    if ( defined($xref->{'/Prev'}) ) {
        $self->_parse_xref($xref->{'/Prev'});
    }

}

sub _parse_encrypt {
    my ($self,$encrypt) = @_;
    $encrypt = $self->_dereference($encrypt);
    return unless defined($encrypt);

    if ( $encrypt->{'/Filter'} ne '/Standard' ) {
        die "Encryption filter $encrypt->{'/Filter'} not implemented";
    }

    $self->{core}->{crypt} = PDF::Filter::Decrypt->new($encrypt,$self->{trailer}->{'/ID'}->[0]);

}

sub _parse_pages {
    my ($self,$node,$parent_node) = @_;
    $node = $self->_dereference($node);
    return unless defined($node);

    debug('pages',$node);

    # inherit properties
    $parent_node = {} unless defined($parent_node);
    for (qw(/MediaBox /Resources) ) {
        $node->{$_} = $parent_node->{$_} unless defined($node->{$_});
    }

    if ( $node->{'/Type'} eq '/Pages' ) {
        $self->_parse_pages($_, $node) for (@{$node->{'/Kids'}});
    } elsif ( $node->{'/Type'} eq '/Page' ) {

        push @{$self->{pages}}, $node;

        # call page begin handler
        if (defined($self->{events}->{page_begin})) {
            $self->{events}->{page_begin}->(
                scalar(@{$self->{pages}}),
                $node
            );
        }

        $self->_parse_annotations($node->{'/Annots'}) if (defined($node->{'/Annots'}));
        $node->{'/Resources'} = $self->_parse_resources($node->{'/Resources'}) if (defined($node->{'/Resources'}));
        $self->_parse_contents($node->{'/Contents'},$node) if (defined($node->{'/Contents'}));

        # call page end handler
        if (defined($self->{events}->{page_end})) {
            $self->{events}->{page_end}->(
                scalar(@{$self->{pages}}),
                $node
            );
        }

    } else {
        die "Unexpected page type";
    }

    return $node;

}

sub _parse_annotations {
    my ($self,$annots) = @_;
    $annots = $self->_dereference($annots);
    return unless defined($annots);

    for my $ref (@$annots) {
        my $annot = $self->_get_obj($ref);
        if ( defined($annot->{'/Subtype'}) && $annot->{'/Subtype'} eq '/Link' && defined($annot->{'/A'}) ) {
            $self->_parse_action($annot->{'/A'});
        }
    }

}

sub _parse_action {
    my ($self,$action) = @_;
    $action = $self->_dereference($action);
    return unless defined($action);

    if ( $action->{'/S'} eq '/URI' ) {
        my $location = $action->{'/URI'};
        if ( $location =~ /^https?:\/\// ) {
            $self->{info}->{uris}->{$location} = 1;
            $self->{info}->{links}++;
        }
    }

    if ( defined($action->{'/Next'}) ) {
        # can be array or dict
        if ( ref($action->{'/Next'}) eq 'ARRAY' ) {
            $self->_parse_action($_) for @{$action->{'/Next'}};
        } else {
            $self->_parse_action($action->{'/Next'});
        }
    }

}
sub _parse_resources {
    my ($self,$resources) = @_;
    $resources = $self->_dereference($resources);
    return unless defined($resources);

    $resources->{'/XObject'} = $self->_parse_xobject($resources->{'/XObject'}) if (defined($resources->{'/XObject'}));
    return $resources;
}

sub _parse_xobject {
    my ($self,$xobject) = @_;
    $xobject = $self->_dereference($xobject);
    return unless defined($xobject);

    for my $name (keys %$xobject) {
        my $ref = $xobject->{$name};
        my $obj = $xobject->{$name} = $self->_get_obj($ref);
        if ( $obj->{'/Subtype'} eq '/Image' ) {
            # $self->_parse_image('image',$ref,$obj,$name);
        } elsif ( $obj->{'/Subtype'} eq '/Form' ) {
            # print "Form: $name $ref\n";
            $obj->{'/Resources'} = $self->_parse_resources($obj->{'/Resources'}) if (defined($obj->{'/Resources'}));
        }
    }
    return $xobject;
}

sub _parse_image {
    my ($self,$type,$ref,$obj,$name) = @_;

    return unless defined($name);

    # get object unless it was provided
    $obj = $self->_get_obj($ref) unless defined($obj);
    if ( !defined($obj) ) {
        carp "Invalid image reference: $ref";
        return;
    }

    debug('images',"Image: $name $ref\n".Dumper($obj));

    my $image = {
        type   => $type,
        object => $ref,
        name   => $name,
        width  => $obj->{'/Width'},
        height => $obj->{'/Height'},
    };

    # push(@{$self->{pages}->[-1]->{images}}, $image);

    # $self->{pages}->[-1]->{images}->{$name} = $ref;
    $self->{images}->{$ref} = $image unless defined($self->{images}->{$ref});

    # if ( defined($obj->{'/SMask'}) ) {
    #     $self->_parse_image('mask',$obj->{'/SMask'});
    # }

}

sub _parse_contents {
    my ($self,$contents,$page) = @_;
    my $core = PDF::Core->new;

    $contents = [ $contents ] if (ref($contents) ne 'ARRAY');

    my $state = {
        cm => [0,0,0,0,0,0]
    };
    my @params = ();
    my $stream = '';

    for my $obj ( @$contents ) {
        $stream = $self->_get_stream_data($obj);
        while (defined(my $token = $core->get_primitive(\$stream))) {
            if ( $token !~ /^[a-zA-Z][a-zA-Z0-9*'"]*$/) {
                push(@params,$token);
                next;
            }
            debug('tokens',$token.' '.join(',',@params));
            if ( $token eq 'cm' ) {
                $state->{cm} = [ @params ];
            } elsif ( $token eq 'Do' ) {
                # print "$token ".join(',',@params)."\n";
                # print "cm=".join(',',@{$state->{cm}}),"\n";
                my $name = $params[0];
                my $xobj = $page->{'/Resources'}->{'/XObject'}->{$name};
                if ( $xobj->{'/Subtype'} eq '/Image' ) {
                    # Call image handler
                    if (defined($self->{events}->{image_handler})) {
                        $self->{events}->{image_handler}->(
                            $xobj,
                            $state->{cm},
                            $self->{pages}->[-1]
                        );
                    }
                }



            }


            @params = ();
        }
    }



    # while ($stream =~ /\G.*?\b(Do)\b/gs ) {
    #     if ( $1 eq 'Do' ) {
    #         if ($stream =~ /([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+cm\s+(\/[^\/%\(\)\[\]<>{}\s]+)\s+Do\G/) {
    #             print "$1 $2 $3 $4 $5 $6 $7\n";
    #         } else {
    #             warn "problem at ",substr($stream,pos($stream)-10,20);
    #         }
    #
    #     }
    # }

}

sub _get_obj {
    my ($self,$ref) = @_;

    # return undef for non-existent objects
    return undef unless defined($ref) && defined($self->{xref}->{$ref});

    # return cached object if possible
    return $self->{object_cache}->{$ref} if defined($self->{object_cache}->{$ref});

    if (defined($self->{core}->{crypt})) {
        my ($objnum,$gennum) = $ref =~ /^(\d+) (\d+) R$/;
        $self->{core}->{crypt}->set_current_object($objnum, $gennum);
    }

    if ( ref($self->{xref}->{$ref}) eq 'ARRAY' ) {
        my ($stream_obj_ref,$index) = @{$self->{xref}->{$ref}};
        $self->{object_cache}->{$ref} = $self->_get_compressed_obj($stream_obj_ref,$index,$ref);
    } else {
        pos($self->{data}) = $self->{xref}->{$ref};
        $self->{data} =~ /\G\s*\d+ \d+ obj\s*/g or die "object $ref not found";
        eval {
            $self->{object_cache}->{$ref} = $self->{core}->get_primitive(\$self->{data});
        } or die "Error getting object $ref: $@";
    }
    return $self->{object_cache}->{$ref};
}

sub _dereference {
    my ($self,$obj) = @_;
    while ( defined($obj) && !ref($obj) && $obj =~ /^\d+ \d+ R$/ ) {
        $obj = $self->_get_obj($obj);
    }
    return $obj;
}

sub _get_compressed_obj {
    my ($self,$stream_obj_ref,$index,$ref) = @_;

    $ref =~ /^(\d+)/ or die "invalid object reference";
    my $obj = $1;

    my $stream_obj = $self->_get_obj($stream_obj_ref);
    # print Dumper($stream_obj);
    my $data = $self->_get_stream_data($stream_obj);

    if ( !defined($stream_obj->{pos}) ) {
        while ( $data =~ /\G\s*(\d+) (\d+)\s+/ ) {
            $stream_obj->{xref}->{$1} = $2;
            pos($data) = $+[0];
            # print "$1 -> $2\n";
        }
        $stream_obj->{pos} = pos($data);
    }

    # print $data,"\n\n";
    # print "$stream_obj_ref, $index, $ref\n";
    # print $stream_obj->{pos}." + ".$stream_obj->{xref}->{$obj},"\n";
    pos($data) = $stream_obj->{pos} + $stream_obj->{xref}->{$obj};
    return $self->{object_cache}->{$ref} = $self->{core}->get_primitive(\$data);
}

sub _get_stream_data {
    my ($self,$stream_obj) = @_;
    $stream_obj = $self->_dereference($stream_obj);
    return unless defined($stream_obj);

    # not a stream object
    return undef unless ref($stream_obj) eq 'HASH' && defined($stream_obj->{_stream_offset});

    my $offset = $stream_obj->{_stream_offset};
    my $length = $stream_obj->{'/Length'};
    my $filter = $stream_obj->{'/Filter'} || '';

    # check for cached version
    return $self->{stream_cache}->{$offset} if defined($self->{stream_cache}->{$offset});

    if ( $filter eq '/FlateDecode' ) {
        my $f = PDF::Filter::FlateDecode->new($stream_obj->{'/DecodeParms'});
        $self->{stream_cache}->{$offset} = $f->decode(
            substr($self->{data},$offset,$length)
        );
    } else {
        $self->{stream_cache}->{$offset} = substr($self->{data},$offset,$length);
    }

    return $self->{stream_cache}->{$offset};

}

sub _bin2hex {
    my $data = shift;
    my $bytes = shift || length($data);
    return unpack("H".$bytes*2, $data);
}

sub debug {
    my $level = shift;
    return if !defined($debug);
    if ( $debug eq $level || $debug eq 'all' ) {
        for (@_) {
            print STDOUT (ref($_) ? Dumper($_) : $_),"\n";
        }
    }
}

1;