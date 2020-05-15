# Actium/O/Sked/Stop.pm

# the stop time object, containing all the info for each time of a schedule

# Subversion: $Id: Stop.pm 238 2013-04-04 00:30:06Z aaronpriven@gmail.com $

# legacy status 4

package Actium::O::Sked::Stop 0.002;

use 5.016;
use strict;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use namespace::autoclean;

use Actium::Types (qw(ActiumDir ActiumDays ArrayRefOfActiumSkedStopTime));
use Actium::Time;

use MooseX::Storage;
with Storage( traits => ['OnlyWhenBuilt'] );

has 'time_obj_r' => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => ArrayRefOfActiumSkedStopTime,
    init_arg => 'time_objs',
    #default  => sub { [] },
    required => 1,
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

    my $self = shift;

    my @kpoint_data = $self->linegroup, $self->dircode, $self->daycode,
      map { $_->for_kpoint } $self->time_objs;

    return jt(@kpoint_data);

}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__
   
