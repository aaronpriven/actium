# Actium/O/Skedlike.pm

# Role for defining objects that do what skeds can do
# (including such things as Timetables and IDTables)

# Subversion: $Id$

use warnings;
use 5.016;    # turns on features

package Actium::O::Skedlike 0.003;

use Moose::Role;

requires(
    [   qw[ earliest_timenum id linedir should_preserve_direction_order
          sortable_id sortable_id_with_timenum ]
    ]
);

no Moose::Role;

1;

__END__
