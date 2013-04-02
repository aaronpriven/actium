# Actium/MOP/ShortColumn.pm

# Trait for adding short column names to attributes

# Subversion: $Id$

use warnings;
use 5.016;    # turns on features

package Actium::O::Traits::WithShortColumn 0.002;

use Moose::Role;

has short_column => (
    is  => 'rw',
    isa => 'Str',
    predicate => 'has_short_column',
);

1;

__END__
