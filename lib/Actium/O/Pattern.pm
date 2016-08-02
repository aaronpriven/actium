package Actium::O::Pattern 0.012;

# used by Xhea:::ToSkeds

use Actium::Moose;

use Actium::Types (qw/DirCode ActiumDir/);
use Actium::O::Dir;
use Actium::O::Pattern::Stop;

has 'line' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has [qw/vdc via/] => (
    is => 'ro',
);

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
    return join ('.' , $self->line, $self->identifier );
}

has 'stop_objs_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::O::Pattern::Stop]',
    writer => '_set_stop_objs_r',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        stop_objs    => 'elements',
    },
);

has 'stops_and_places_r' => (
    is => 'bare',
    isa => 'ArrayRef[Str]',
    lazy => 1,
    builder => '_build_stops_places_r',
    traits => ['Array'],
    handles => { 
        stops_and_places => 'elements',
    },
);

sub _build_stops_places_r {
    my $self = shift;
    return [ map { $_->stop_and_place } $self->stop_objs ];
}

has union_indexes_r => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    handles => { 
        union_indexes => 'elements',
    },
); 

u::immut;

1;
