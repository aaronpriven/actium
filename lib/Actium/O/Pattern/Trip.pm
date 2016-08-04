package Actium::O::Pattern::Trip 0.012;

use Actium::Moose;
use Actium::O::Time;
use Actium::O::Pattern::TripStop;
use Actium::O::Pattern::TripPlace;

sub id {
    my $self = shift;
    return $self->int_number;
}

has 'int_number' => (
    is       => 'ro',
    required => 1,
    isa      => 'Int',
);

has [qw/days pattern_id /] => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
);

has [
    qw/schedule_daytype event_and_status op_except 
       block_id vehicle_group vehicle_type garage/
  ] => (
    is  => 'ro',
    isa => 'Str',
  );

has 'stop_objs_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Maybe[Actium::O::Pattern::TripStop]]',
    writer  => '_set_stop_objs_r',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        stops    => 'elements',
        set_stop => 'set',
        stop     => => 'get',
    },
);

sub times {
    my $self = shift;
    return map { $_->time } $self->stops;
    
    
}

# place objects are only used temporarily; their elements are
# merged into the tripstop objects early on
has 'place_objs_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::O::Pattern::TripPlace]',
    writer  => '_set_place_objs_r',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        place_objs   => 'elements',
        set_place    => 'set',
        clear_places => 'clear',
    },
);

u::immut;

1;
