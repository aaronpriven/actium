# Actium/O/Sked/Timetable/IDTimetableSet.pm

# A set of timetables

# legacy status: 4

package Actium::O::Sked::Timetable::IDTimetableSet 0.010;

use 5.016;
use warnings;

use Moose; ### DEP ###
use MooseX::StrictConstructor; ### DEP ###
use MooseX::SemiAffordanceAccessor; ### DEP ###

has timetables_r => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Actium::O::Sked::Timetable::IDTimetable]',
    default  => sub { [] },
    init_arg => 'timetables',
    handles  => {
        timetables      => 'elements',
        _push_timetable => 'push',
        timetable_count => 'count'
    },
);

has overlong => (
    isa     => 'Bool',
    is      => 'ro',
    writer  => '_set_overlong',
    default => 0,
);

sub add_timetable {
    my $self      = shift;
    my $timetable = shift;
    $self->_set_overlong( $self->overlong || $timetable->overlong );
    $self->_push_timetable($timetable);
    return;
}

1;

__END__
