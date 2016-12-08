package Actium::O::Skedlike 0.012;

# Role for defining objects that do what skeds can do
# (including such things as Timetables and IDTables)

use warnings;
use 5.016;    # turns on features

use Moose::Role; ### DEP ###

requires(
       qw[ earliest_timenum id linedir should_preserve_direction_order
          sortable_id sortable_id_with_timenum ]
    
);

no Moose::Role;

1;

__END__
