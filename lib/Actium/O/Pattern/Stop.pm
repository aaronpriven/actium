package Actium::O::Pattern::Stop 0.012;

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

has [
    qw(
      h_stp_identifier   tstp_place
      ttp_is_arrival     ttp_is_departure
      ttp_is_public      ttp_prev  ttp_next
      )
  ] => (
    is  => 'ro',
    isa => 'Str',
  );

u::immut;

1;
