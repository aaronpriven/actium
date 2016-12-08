package Actium::O::Traits::WithShortColumn 0.012;
# Trait for adding short column names to attributes

use warnings;
use 5.016;    # turns on features

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
