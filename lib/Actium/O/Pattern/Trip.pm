package Actium::O::Pattern::Trip 0.012;

use Actium::Moose;
use Actium::O::Time;

sub id {
    my $self = shift;
    return $self->int_number;
}

has 'int_number' => (
    is       => 'ro',
    required => 1,
    isa      => 'Int',
);

has [qw/days pattern_id/] => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
);

has [
    qw/schedule_daytype event_and_status op_except
      block_id vehicle_group vehicle_type /
  ] => (
    is  => 'ro',
    isa => 'Str',
  );

has 'stoptime_r' => (
    traits  => ['Array'],
    is      => 'ro',
    writer => '_set_stoptime_r',
    isa     => 'ArrayRef[Actium::O::Time]',
    default => sub { [] },
    handles => {
        set_stoptime        => 'set',
        stoptime            => 'get',
        stoptimes           => 'elements',
        stoptime_count      => 'count',
        stoptimes_are_empty => 'is_empty',
        _delete_stoptime    => 'delete',
    },
);

u::immut;

1;
