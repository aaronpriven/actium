package Actium::O::Pattern::TripStop 0.012;

use Actium::Moose;

sub id {
    my $self = shift;
    return $self->stp_511_id;
}

has 'h_stp_511_id' => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has 'tstp_place' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_place',
);

has [qw( ttp_is_public   ttp_is_arrival  ttp_is_departure)] => (
    is  => 'rw',
    isa => 'Str',
);

has 'time' => (
    is       => 'ro',
    isa      => 'Actium::O::Time',
    required => 1,
);

u::immut;

1;
