# Actium/MOP/ShortColumn.pm

# Trait for adding short column names to attributes

# Subversion: $Id: TabDelimited.pm 189 2012-04-26 00:10:57Z aaronpriven $

use warnings;
use 5.016;    # turns on features

package Actium::MOP::WithShortColumn 0.002;

use Moose::Role;
use Moose::Util;

has short_column => (
    is  => 'rw',
    isa => 'Str',
    predicate => 'has_short_column',
);

1;

__END__
