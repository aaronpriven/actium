# Actium/O/Traits/ShortColumn.pm

# Trait for adding short column names to attributes

# Subversion: $Id: WithShortColumn.pm 299 2013-10-25 00:09:54Z aaronpriven@gmail.com $

use warnings;
use 5.016;    # turns on features

package Actium::O::Traits::WithShortColumn 0.003;

use Actium::MooseRole;

#use Moose::Role;
#use MooseX::SemiAffordanceAccessor;
#use namespace::autoclean;

has short_column => (
    is  => 'rw',
    isa => 'Str',
    predicate => 'has_short_column',
);

1;

__END__
