# Actium/O/Sked/Collection.pm

# A collection of Sked objects (or similar objects such as Timetable objects)

# legacy status 4

package Actium::O::Sked::Collection 0.010;
use Actium::Moose;
use Actium::O::Sked;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    # if they're all objects, treat them as though they were skeds
    if ( u::all { u::blessed($_) } @_ ) {
        return $class->$orig( skeds => \@_ );
    }

    # otherwise, normal
    return $class->$orig(@_);

};

has 'skeds_r' => (
    is       => 'bare',
    isa      => 'ArrayRef[Skedlike]',
    traits   => ['Array'],
    required => 1,
);

has '_sked_obj_by_id_r' => (
    is      => 'bare',
    isa     => 'HashRef[Skedlike]',
    traits  => ['Hash'],
    builder => '_build_sked_obj_by_id_r',
    lazy    => 1,
    handles => {
        _set_sked_obj => 'set',
        sked_obj      => 'get',
        _skeds        => 'values',
        #ids => 'keys',
    },
);

sub _build_sked_obj_by_id_r {
    my $self  = shift;
    my @skeds = $self->_skeds;
    my %sked_obj_by_id;
    foreach my $sked (@skeds) {
        my $id = $sked->id;
        $sked_obj_by_id{$id}->@* = $sked;
    }
    return \%sked_obj_by_id;
}

has '_sked_ids_of_lg' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]',
    traits  => ['Hash'],
    builder => '_build_sked_ids_of_lg',
    lazy    => 1,
    handles => { _sked_ids_of_lg_r => 'get' },
);

sub _build_sked_ids_of_lg {
    my $self  = shift;
    my @skeds = $self->_skeds;
    my %sked_ids_of_lg;
    foreach my $sked (@skeds) {

        my $id        = $sked->id;
        my $linegroup = $sked->linegroup;
        push $sked_ids_of_lg{$linegroup}->@*, $id;

    }

    return \%sked_ids_of_lg;

}

sub sked_ids_of_lg {
    my $self      = shift;
    my $linegroup = shift;
    my @skedids   = $self->_sked_ids_of_lg($linegroup)->@*;
    return @skedids;
}

#sub add_sked {
#    my $self = shift;
#    my @objs = shift;
#    $self->_set_sked_obj( map { $_->id, $_ } @objs );
#}

sub load_json {
    my $class = shift;

    my $json_folder = shift;

    my @files = $json_folder->glob_plain_files;

    $class->new( map { Actium::O::Sked::->load($_) } @files );

}

u::immut;

__END__
