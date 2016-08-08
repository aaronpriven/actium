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

has 'tstp_place' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_place',
);

has 'place_rank' => (
    is        => 'rw',
    isa       => 'Int',
    predicate => 'has_place_rank',
);

has 'stop_and_place' => (
    isa     => 'Str',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_stop_and_place',
);

#has place_obj => (
#    is      => 'ro',
#    writer  => 'set_place_obj',
#    predicate => 'has_place_obj',
#    isa     => 'Actium::O::Pattern::Place',
#); 
    
sub _build_stop_and_place {
    my $self           = shift;
    my $stop_and_place = $self->h_stp_511_id;
    return $stop_and_place unless $self->has_place;
    $stop_and_place .= '.' . $self->tstp_place;
    if ( $self->has_place_rank ) {
        $stop_and_place .= '.' . $self->place_rank;
    }
    return $stop_and_place;
}

u::immut;

1;
