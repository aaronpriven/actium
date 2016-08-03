package Actium::O::Pattern::Block 0.012;

use Actium::Moose;

sub id {
    my $self = shift;
    return $self->block_id;
}

has 'block_id' => (
    isa      => 'Int',
    is       => 'ro',
    required => 1,
);

has [qw[vehicle_group vehicle_type garage]] => (
    is        => 'ro',
    isa       => 'Str',
);

u::immut;

1;
