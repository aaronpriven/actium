package Octium::Sked::StopTrip 0.015;
# vimcolor: #002626

use Actium 'class';
use Types::Standard(qw/Str Bool Int ArrayRef Undef/);
use Type::Utils('class_type');
use Actium::Types (qw/Time Dir/);
use Octium::Types (qw/ActiumDays/);

use Octium::Sked::StopTrip::EnsuingStops;
use Octium::Days;
use Actium::Time;
use Actium::Dir;

# KPOINTS -
#  $time_r->{TIME},         - time
#  $time_r->{LINE},         - line
#  $time_r->{DESTINATION},  - destination_place
#  $time_r->{PLACE},        - place
#  $time_r->{DAYEXCEPTIONS} - calendar_id
#  last_stop  - is_final_stop (in ensuingstops)
#  dropoff    - not determined here, requires info from Lines table
#
# $patinfo{Place}        - place
# $patinfo{NextPlace}    - next_place
# $patinfo{AtPlace}      - at_place
# $patinfo{Connections}  - requires info from Stops_Neue table
# $patinfo{District}     - requires info from Stops_Neue table
# $patinfo{Side}         - requires info from Stops_Neue table
# $patinfo{Last}         - is_final_stop (in ensuingstops)
# $patinfo{TransbayOnly} - requires info from Lines table
# $patinfo{DropOffOnly}  - determined from previous two

has time => (
    required => 1,
    isa      => Time,
    coerce   => 1,
    is       => 'ro',
);

has [qw/line/] => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has dir => (
    required => 1,
    coerce   => 1,
    is       => 'ro',
    isa      => Dir,
);

# dir is located in StopTrip because StopSkedCollection can merge multiple
# schedules into one, even if they have different linegroups or directions.

has days => (
    required => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumDays,
    handles  => {
        daycode       => 'daycode',
        sortable_days => 'as_sortable',
    },
);

has qw/calendar_id/ => (
    is      => 'ro',
    default => $EMPTY,
    isa     => Str->plus_coercions( Undef, sub {$EMPTY} ),
    coerce  => 1,
);

has stoppattern => (
    # list of subsequent stops
    isa      => class_type('Octium::Sked::StopTrip::StopPattern'),
    is       => 'ro',
    required => 1,
    handles  => [
        qw/
          destination_place   ensuing_str
          is_at_place         is_final_stop
          next_place          place_in_effect
          /
    ],
);

has _stopsked => (
    weak_ref => 1,
    writer   => '_set_stopsked',
    handles  => { _stopid => 'stopid' },
);
# writer is only used by BUILD in StopSked.pm

has is_dropoff_only => (
    lazy     => 1,
    builder  => 1,
    init_arg => undef,
    is       => 'ro',
);

method _build_is_dropoff_only {
    return env->actiumdb->zone_dropoffonly(
        line              => $self->line,
        stopid            => $self->_stopid,
        destination_place => $self->destination_place,
    );
}

method bundle {
    my $bundle = {
        time        => $self->time->bundle,
        days        => $self->days->bundle,
        dir         => $self->dir->bundle,
        stoppattern => $self->stoppattern->bundle,
        map { $_ => $self->$_ } qw/line calendar_id/,
    };
    return $bundle;
}

method undbundle (HashRef $bundle) {
    $bundle->{dir}  = Actium::Dir->unbundle( $bundle->{dir} );
    $bundle->{time} = Actium::Time->unbundle( $bundle->{time} );
    $bundle->{days} = Octium::Days->unbundle( $bundle->{days} );
    $bundle->{stoppattern}
      = Octium::Sked::StopTrip::StopPattern->unbundle( $bundle->{stoppattern} );
    return $self->new($bundle);
}

Actium::immut;

1;

__END__

=encoding utf8

=head1 NAME

Octium::Sked::StopTrip - Object representing a trip in a stop schedule

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use Octium::Sked::StopTrip;
 my $trip = Octium::Sked::StopTrip->new(
    time              => '5:15a',
    line              => '40',
    place_in_effect  => '12BD',
    'at_place'        => 1,
    destination_place => '11JE',
    days              => '12345',
    next_place        => '11JE',
    ensuingstops           => [qw/51528 51110/],
 );

=head1 DESCRIPTION

This is an object that represents a single trip in a schedule for a
stop.  It is created using Moose.

=head1 CLASS METHODS

=head2 new

This is the constructor for the object, inherited from Moose.

=head1 ATTRIBUTES

=head2 time

This is an L<Actium::Time|Actium::Time> object. If the constructor is
passed a string, will use the C<from_str> method of Actium::Time to get
an object. Required.

=head2 line

A string representing a bus line designation. Required.

=head2 dir

An L<Actium::Dir|Actium::Dir> object representing the direction of
travel for this trip. Uses coercions defined in
L<Actium::Types|Actium::Types>. Required.

=head2 place_in_effect

A string representing the ID of the place (timepoint) of this stop, or
the  previous place, if this stop is between places.

=head2 next_place

A string representing the ID of the place (timepoint) following this
stop. If this stop is the destination place, will be the empty string.

=head2 destination_place

A string representing the ID of the place (timepoint) of the final
stop. Required.

=head2 days

An L<Octium::Days|Octium::Days> object. If passed a string, will send
that to C<Octium::Days->instance>. Required.

=head2 calendar_id

A string representing a calendar ID, from the calendars imported with
this booking.

=head2 ensuingstops

An
L<Octium::Sked::StopTrip::EnsuingStops|Octium::Sked::StopTrip::EnsuingStops>
object, which represents all the subsequent stops after the one on this
trip. If passed an array reference of stop IDs, will create an object
from that. Required.

=head1 METHODS

=head2 is_at_place

Returns true if this stop is at the current place, false if it is
between places.

=head2 is_final_stop

Returns true if this stop is the final stop, false otherwise.

=head2 ensuing_str($threshold)

A string used for comparing ensuing stops on trips. Trips with
C<$threshold> or more stops in common after this one will have the same
string. If C<$threshold> is 0 or omitted, compares all the stops.

=head1 DIAGNOSTICS

None specific to this module, but see L<Actium|Actium> and
L<Moose|Moose>.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

The Actium system.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues|https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2020

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item *

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item *

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

