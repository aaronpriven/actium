# Actium/Sked/Stop/Time.pm

# the stop time object, containing all the info for each time of a schedule

# Subversion: $Id$

# legacy status 4

package Actium::Sked::Stop::Time 0.002;

use 5.016;
use strict;

use Moose;
#use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use MooseX::Storage;
with Storage( traits => ['OnlyWhenBuilt'] );

use Actium::Types qw(Str4 TimeNum ActiumSkedDays);

has [qw(origin destination follower previous)] => (
    is       => 'ro',
    isa      => Str4,
    required => 1,
);

has line => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has days_obj => (
    required => 1,
    coerce   => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumSkedDays,
    handles  => {
        daycode       => 'daycode',
        schooldaycode => 'schooldaycode',
        sortable_days => 'as_sortable',
    },
);

has 'time' => (
    is       => 'ro',
    isa      => TimeNum,
    coerce   => 1,
    required => 1,
);

has stop_index => (
   is => 'ro',
   isa => 'Int',
);

1;

__END__
