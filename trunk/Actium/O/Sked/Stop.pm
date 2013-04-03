# Actium/O/Sked/Stop.pm

# the stop time object, containing all the info for each time of a schedule

# Subversion: $Id$

# legacy status 4

package Actium::O::Sked::Stop 0.002;

use 5.016;
use strict;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use Actium::Types (
    qw(ActiumDir ActiumDays ArrayRefOfActiumSkedStopTime));

use MooseX::Storage;
with Storage( traits => ['OnlyWhenBuilt'] );

has 'time_obj_r' => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => ArrayRefOfActiumSkedStopTime,
    init_arg => 'time_objs',
    default  => sub { [] },
    handles  => {
        time_obj   => 'get',
        time_objs  => 'elements',
        time_count => 'count',
    },
);

has 'linegroup' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

# direction
has dir_obj => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumDir,
    handles  => {
        direction => 'dircode',
        dircode   => 'dircode',
    },
);

has days_obj => (
    required => 1,
    coerce   => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumDays,
    handles  => {
        daycode       => 'daycode',
        schooldaycode => 'schooldaycode',
        sortable_days => 'as_sortable',
    }
);

sub as_kpoint {
 
    
 
 
 
}

1;

__END__
   
