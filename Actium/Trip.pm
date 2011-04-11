# Actium/Trip.pm

# Trip object (for schedules and headways)

# Subversion: $Id$

# legacy status 3

package Actium::Trip;

use Moose;

use 5.010;

use utf8;
our $VERSION = '0.001';
$VERSION = eval $VERSION;

use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose;

#use Moose::Util::TypeConstraints;
use Actium::Time qw<timestr timestr_sub>;
use Actium::Util 'jt';
use Actium::AttributeHandlers 'arrayhandles';
use Actium::Constants;

use Actium::Types qw<ArrayRefOfTimeNums TimeNum>;

###################
###
### TRIP
###
###################

# exceptions, from , to, vehicletype from headways
# pattern, type, typevalue, vehicledisplay, via, viadescription from HSA
# routenum, runid, blockid from either
has [
    qw<exceptions routenum runid blockid noteletter pattern type typevalue
      from to vehicletype
      vehicledisplay via viadescription>
  ] => (
    is  => 'rw',
    isa => 'Str',
  );

# from headways
has 'stopleave' => (
    is     => 'rw',
    isa    => TimeNum,
    coerce => 1,
);

# from HSA
has 'stoptime_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => ArrayRefOfTimeNums,
    default => sub { [] },
    coerce  => 1,
    handles => { arrayhandles('stoptime') },
);

# from either
has 'placetime_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => ArrayRefOfTimeNums,
    default => sub { [] },
    coerce  => 1,
    handles => { arrayhandles('placetime') },
);

has 'mergedtrip_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Actium::Trip]',
    default => sub { [] },
    handles => { arrayhandles('mergedtrip') },

);

sub dump {    ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;
    require Data::Dumper;
    return Data::Dumper::Dumper($self);
}

sub merge_trips {

    my $class = shift;

    my $firsttrip  = shift;
    my $secondtrip = shift;

    my @mergedtrips;
    foreach my $trip ( $firsttrip, $secondtrip ) {
        if ( $trip->mergedtrip_count ) {
            push @mergedtrips, $trip->mergedtrips;
        }
        else {
            push @mergedtrips, $trip;
        }
    }

    my %merged_value_of = ( mergedtrip_r => \@mergedtrips );

    foreach my $attribute ( $class->meta->get_all_attributes ) {
        my $attrname = $attribute->name;
        given ($attrname) {
            when ('mergedtrip_r') {
            }    # do nothing
            when ( [ 'placetime_r', 'stoptime_r' ] ) {

                # assumed to be equal
                $merged_value_of{$attrname} = $firsttrip->$attrname;
            }
            default {
                my $firstattr  = $firsttrip->$attrname;
                my $secondattr = $secondtrip->$attrname;

                if (    defined($firstattr)
                    and defined($secondattr)
                    and $firsttrip->$attrname eq $secondtrip->$attrname )
                {
                    $merged_value_of{$attrname} = $firstattr;
                }
            }
        } ## <perltidy> end given

    } ## <perltidy> end foreach my $attribute ( $class...)
    return $class->new(%merged_value_of);

} ## <perltidy> end sub merge_trips

no Moose;

#no Moose::Util::TypeConstraints;

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

=head1 NAME

Actium::Trip.pm - Object representing a trip in a schedule

=head1 VERSION

This documentation refers to Actium::Trip.pm version 0.001

=head1 DESCRIPTION

This is a Moose class, representing each trip of a bus schedule. It contains
information for each trip of a schedule. It is intended to be used by the 
L<Actium::HeadwayPage> object and the L<Actium::Sked> object.

=head1 ATTRIBUTES

Methods to get and set attributes are named in a semi-affordance fashion: 
setter methods are "set-I<attribute>()" but getter methods are just 
"I<attribute>()."

=over

=item B<exceptions>

The "Exceptions" field from the headway sheet (usually "SD" for school days,
"SH" for school holidays, or blank).

=item B<routenum>

The route number for this trip.

=item B<runid>

=item B<blockid>

The run and block identification numbers. These are usually only useful
internally, but they can help figure out which trips are connected, which 
is sometimes useful for public information.

=item B<vehicletype>

The vehicle type (generally, which type of bus is used).

=item B<to>

=item B<from>

Where the vehicle for this trip is either going to or coming from 
(either another line or a garage).

=item B<stopleave>

The time the bus leaves the last stop shown on the 
schedule. If it's to return to the yard, it's generally the same as the previous 
time; if it's to continue on another trip, it's usually after some layover time.

This is an integer, the number of minutes since midnight (or before midnight, if
negative). If this is set to a string, it is coerced to an integer using 
L<Actium::Time::timenum|Actium::Time/"timenum ($time)">

=item B<noteletter>

The letter(s) representing the note for this trip. The full note is contained in 
an L<Actium::SkedNote> object.

=item B<stoptime_r>

=item B<placetime_r>

Two references to arrays containing times, numerically, 
in minutes since midnight 
(minutes before midnight are shown as negative numbers). There is one entry 
for each stop or place in the schedule, even if the stop or place 
is not served by this trip.
Entries for stops or places not served by this trip are stored as I<undef>.

These are integers, the number of minutes since midnight (or before midnight, if
negative). If an entry is set to a string, it is coerced to an integer using 
L<Actium::Time::timenum|Actium::Time/"timenum ($time)">.

Each of these has a full set of methods to handle common array functions. 
See L<Actium::AttributeHandlers/arrayhandles>. The base names are "stoptime" and
"placetime" respectively.

=item B<mergedtrip_r>

After trips are  merged using I<merge_trips()>, this array holds all the 
Actium::Trip objects that were originally merged.  

This attribute has a full set of methods to handle common array functions. 
See L<Actium::AttributeHandlers/arrayhandles>. The base name is "mergedtrip".

=back

=head1 CLASS METHOD

=over

=item B<merge_trips()>

This is a class method to merge two trips that, presumably, have identical stoptimes
and placetimes. (The purpose is to allow two trips that are scheduled identically --
two buses that are designed to run at the same time to allow an extra heavy load to be
carried -- to appear only once in the schedule.)

 Actium::Trip->merge_trips($trip1, $trip2);

A new Actium::Trip object is created, with attributes as follows:

=over

=item stoptimes and placetimes

The stoptimes and placetimes for the first trip are used.

=item mergedtrips

This attribute contains the Actium::Trip objects for all the parent trips. 
In the simplest case, it contains the two Actium::Trip objects passed to merge_trips.

However, if either of the Actium::Trip objects passed to merge_trips already has a
mergedtrips attribute, then instead of saving the current Actium::Trip object, it saves
the contents of mergedtrips. The upshot is that mergedtrips contains all the trips 
that are parents of this merged trip.

=item All other attributes

All other attributes are set as follows: if the value of an attribute is the same in 
the two trips, they are set with that value. Otherwise the attribute is not set.

=back

=back

=head1 DIAGNOSTICS

See L<Moose>.

=head1 DEPENDENCIES

=over

=item *

Moose

=item *

MooseX::SemiAffordanceAccessor

=item *

MooseX::StrictConstructor

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
