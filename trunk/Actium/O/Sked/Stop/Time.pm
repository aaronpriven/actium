# Actium/Sked/Stop/Time.pm

# the stop time object, containing all the info for each time of a schedule

# Subversion: $Id$

# legacy status 4

package Actium::O::Sked::Stop::Time 0.002;

use 5.016;
use strict;

use Moose;
#use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Actium::O::Days;
use Actium::Constants;

use namespace::autoclean;

use MooseX::Storage;
with Storage( traits => ['OnlyWhenBuilt'] );

use Actium::Types qw(Str4 TimeNum ActiumDays);

has [qw(origin destination follower previous)] => (
    is       => 'ro',
    isa      => Str4,
    required => 1,
);

has at_place => (
is => 'bare',
isa => Str4 ,
lazy => 1,
builder => '_build_at_place',
);

sub _build_at_place {
   my $self = shift;
   my $previous = $self->previous;
   my $follower = $self->follower;
   
   return $previous eq $follower ? $previous : $EMPTY_STR;

}

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
    isa      => ActiumDays,
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

my $kpoint_timestr_sub = Actium::Time::timestr_sub( SEPARATOR => '', XB => 1 );

sub for_kpoint {
    my $self = shift;
    
    my @kpoint_time = $kpoint_timestr_sub->($self->time), $self->line,
    $self->destination,$self->place,$self->daysexc
 
 
}

__PACKAGE__->meta->make_immutable; ## no critic (RequireExplicitInclusion)

1;

__END__
