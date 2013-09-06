# Actium/O/Sked/Timetable/IDTimetable.pm

# Object representing data in a timetable to be displayed to user,
# specific to InDesign timetables. Mostly to do with frame information.

# Subversion: $Id$

# legacy status: 4

use 5.016;
use warnings;

package Actium::O::Sked::Timetable::IDTimetable 0.002;

use Moose;
use MooseX::StrictConstructor;

use namespace::autoclean;

has timetable_obj => (
    isa      => 'Actium::O::Sked::Timetable',
    is       => 'ro',
    required => 1,
    handles  => [qw(lines dircode daycode height width id dimensions_for_display)],
);

has compression_level => (
    default => 1,
    is       => 'ro',
    isa      => 'Int',
);

has [qw<multipage failed>] => (
    is       => 'ro',
    isa      => 'Bool',
    default => 0,
);

__PACKAGE__->meta->make_immutable;

1;

__END__ 