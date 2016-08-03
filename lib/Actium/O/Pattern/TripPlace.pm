package Actium::O::Pattern::TripPlace 0.012;

use Actium::Moose;

sub id {
    my $self = shift;
    return $self->ttp_place;
}

has 'ttp_place' => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has [
    qw( ttp_is_public ttp_is_arrival ttp_is_departure) ] => (
    is  => 'ro',
    isa => 'Str',
  );

u::immut;

1;
