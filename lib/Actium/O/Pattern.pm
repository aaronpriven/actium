package Actium::O::Pattern 0.012;

# used by Xhea:::ToSkeds

use Actium::Moose;

use Actium::Types (qw/DirCode ActiumDir/);
use Actium::O::Dir;
use Actium::O::Pattern::Stop;

has [ 'line', 'linegroup' ] => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has [qw/vdc via/] => ( is => 'ro', );

for (qw/linedir lgdir/) {
    has $_ => (
        is      => 'ro',
        lazy    => 1,
        builder => "_build_$_",
        isa     => 'Str',
    );
}

sub _build_lgdir {
    my $self = shift;
    return $self->dir_obj->linedir( $self->linegroup );
}

sub _build_linedir {
    my $self = shift;
    return $self->dir_obj->linedir( $self->line );
}

has 'dir_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumDir,
    handles  => ['dircode'],
);

has 'identifier' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'unique_id' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_unique_id',
);

sub id {
    my $self = shift;
    return $self->unique_id;
}

sub _build_unique_id {
    my $self = shift;
    return join( '.', $self->line, $self->identifier );
}

has 'stop_objs_r' => (
    is      => 'rw',
    writer  => '_set_stops_obj_r',
    isa     => 'ArrayRef[Actium::O::Pattern::Stop]',
    default => sub { [] },
    traits  => ['Array'],
    handles =>
      { stop_objs => 'elements', 'stop_obj' => 'get', stop_count => 'count' },
);

has 'trip_objs_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::O::Pattern::Trip]',
    default => sub { [] },
    traits  => ['Array'],
    handles => { trips => 'elements', _push_trip => 'push', },
);

sub add_trip {
    my $self = shift;
    my $trip = shift;
    $self->_push_trip($trip);
    unless ( $self->trip_count ) {

        my @trip_stop_objs = $trip->stop_objs;
        my @stop_objs;
        foreach my $trip_stop_obj (@trip_stop_objs) {
            push @stop_objs, Actium::O::Pattern::Stop->new(
                h_stp_511_id => $trip_stop_obj->h_stp_511_id,
                tstp_place   => $trip_stop_obj->tstp_place,
            );
        }

        $self->_set_stop_objs_r( \@stop_objs );
    }
    return;
} ## tidy end: sub add_trip

has 'stops_and_places_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    lazy    => 1,
    builder => '_build_stops_places_r',
    traits  => ['Array'],
    handles => { stops_and_places => 'elements', },
);

sub _build_stops_places_r {
    my $self = shift;
    return [ map { $_->stop_and_place } $self->stop_objs ];
}

has union_indexes_r => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    traits  => ['Array'],
    handles => { union_indexes => 'elements', union_index => 'get', },
);

u::immut;

1;
