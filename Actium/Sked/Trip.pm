# Actium/Sked/Trip.pm

# Trip object (for schedules and headways)

# Subversion: $Id$

# legacy status 3

package Actium::Sked::Trip;

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
use Actium::Constants;

use List::Util ('min');

#use overload q{""} => \&stoptimes_comparison_str;
# only for debugging - remove in production

use Actium::Types qw<ArrayRefOfTimeNums TimeNum ActiumSkedDays>;

###################
###
### TRIP
###
###################

# daysexceptions, from , to, vehicletype from headways
# pattern, type, typevalue, vehicledisplay, via, viadescription from HSA
# routenum, runid, blockid from either
has [
    qw<daysexceptions routenum runid blockid noteletter pattern type typevalue
      from to vehicletype
      vehicledisplay via viadescription>
  ] => (
    is  => 'rw',
    isa => 'Str',
  );

# generated from Thea, if nowhere else
has 'days_obj' => (
    required => 0,
    coerce   => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumSkedDays,
    handles  => {
        daycode        => 'daycode',
        schooldaycode  => 'schooldaycode',
        sortable_days  => 'as_sortable',
        days_as_string => 'as_string',
    }
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
    is      => 'ro',
    isa     => ArrayRefOfTimeNums,
    default => sub { [] },
    coerce  => 1,
    handles => {
        stoptime            => 'get',
        stoptimes           => 'elements',
        stoptime_count      => 'count',
        stoptimes_are_empty => 'is_empty',
    },
);

sub stoptimes_comparison_str {
    my $self = shift;
    return join( "\t", grep {defined} $self->stoptimes );
}

sub average_stoptime {
    my $self = shift;
    my @times = grep { defined $_ } $self->stoptimes;
    return ( List::Util::sum(@times) / scalar @times );
}

sub stoptimes_equals {
    my $self       = shift;
    my $secondtrip = shift;
    return $self->stoptimes_comparison_str eq
      $secondtrip->stoptimes_comparison_str;
}

# from either
has 'placetime_r' => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => ArrayRefOfTimeNums,
    default => sub { [] },
    coerce  => 1,
    handles => {
        placetimes           => 'elements',
        splice_placetimes    => 'splice',
        placetime_count      => 'count',
        placetimes_are_empty => 'is_empty',
        placetime            => 'get',
    },
);

has 'mergedtrip_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Actium::Sked::Trip]',
    default => sub { [] },
    handles => { mergedtrips => 'elements', mergedtrip_count => 'count', },

);

sub dump {    ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;
    require Data::Dumper;
    return Data::Dumper::Dumper($self);
}

### CLASS METHODS

sub merge_trips {

    my $class;
    if ( blessed $_[0] ) {
        $class = blessed $_[0];
    }
    else {
        $class = shift;
    }

    # allows calling as object method or class method
    # calling as a class method should be deprecated...

    my $self       = shift;
    my $secondtrip = shift;

    return $self if $self == $secondtrip;
    # if they are the same exact object, then don't do anything else,
    # just return it

    my @mergedtrips;
    foreach my $trip ( $self, $secondtrip ) {
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
        my $init_arg = $attribute->init_arg // $attrname;

        given ($attrname) {
            when ('mergedtrip_r') {
            }    # do nothing
            when ( [ 'placetime_r', 'stoptime_r' ] ) {

                # assumed to be equal
                $merged_value_of{$init_arg} = $self->$attrname;
            }
            when ('days_obj') {
                $merged_value_of{$init_arg}
                  = Actium::Sked::Days->union( $self->$attrname,
                    $secondtrip->$attrname );
            }
            default {
                my $firstattr  = $self->$attrname;
                my $secondattr = $secondtrip->$attrname;

                if (    defined($firstattr)
                    and defined($secondattr)
                    and $self->$attrname eq $secondtrip->$attrname )
                {
                    $merged_value_of{$init_arg} = $firstattr;
                }
                # if they're identical, set the array to the value
                elsif ( $attrname ~~ ['daysexceptions'] ) {
                    $merged_value_of{$init_arg} = '';
                }
                # otherwise, if the attribute name is one of the those, then
                # set it to nothing. (If it isn't listed, the attribute will
                # be blank.)

                # TODO - special days merging should probably merge
                # daysexceptions specially, although currently -- with the
                # only possible values SD and SH -- it would't make
                # a difference

            } ## tidy end: default
        }    ## <perltidy> end given

    }    ## <perltidy> end foreach my $attribute ( $class...)
    return $class->new(%merged_value_of);

}    ## <perltidy> end sub merge_trips

my $common_stop_cr = sub {

    # returns undef if there's no stop in common, or
    # the stop to sort by if there is one

    my @trips = @_;
    my $common_stop;
    my $last_to_search
      = ( List::Util::min( map { $_->stoptime_count } @trips ) ) - 1;

  SORTBY_STOP:
    for my $stop ( 0 .. $last_to_search ) {
      SORTBY_TRIP:
        for my $trip (@trips) {
            next SORTBY_STOP if not defined $trip->stoptime($stop);
        }
        $common_stop = $stop;
        last SORTBY_STOP;
    }

    return $common_stop;

};

sub stoptimes_sort {

    my $class = shift;
    my @trips = @_;

    my $common_stop = $common_stop_cr->(@trips);

    if ( defined $common_stop ) {

        # sort trips with a common stop
        
        my @cache = map {
            [   $_->stoptime($common_stop),    # 0
                $_->average_stoptime,          # 1
                $_,                            # 2
            ]
          } @trips; 
          
        @cache = sort {
                 $a->[0] <=> $b->[0]
              or $a->[1] <=> $b->[1]
              or $a->[2]->sortable_days cmp $b->[2]->sortable_days
          } @cache;
          
        @trips = map { $_->[2] } @cache;
          

        # a schwartzian transform with two criteria --
        # either the common stop, or if those times are the same,
        # the average.
        # if both of those tie, use sortable_days (not put into the
        # cache because will be used very very rarely)

    } ## tidy end: if ( defined $common_stop)
    else {
        # sort trips without a common stop for all of them

        @trips = sort {

            my $common = $common_stop_cr->( $a, $b );

            defined $common
              ? ( $a->stoptime($common) <=> $b->stoptime($common)
                  or $a->average_stoptime <=> $b->average_stoptime
                  or $a->sortable_days cmp $b->sortable_days )
              : $a->average_stoptime <=> $b->average_stoptime
              or $a->sortable_days cmp $b->sortable_days;

            # if these two trips have a common stop, sort first
            # on those common times, and then by the average.

            # if they don't, just sort by the average.

        } @trips;

    } ## tidy end: else [ if ( defined $common_stop)]

    return \@trips;

} ## tidy end: sub stoptimes_sort

sub merge_trips_if_same {
    my $class  = shift;
    my %params = %{ +shift };

    my @trips   = @{ $params{trips} };
    my @methods = @{ $params{methods_to_compare} };

    my @newtrips = shift @trips;

  TRIP_TO_MERGE:
    while (@trips) {
        my $thistrip = shift @trips;
        my $prevtrip = $newtrips[-1];

        foreach my $this_test (@methods) {
            if ( $thistrip->$this_test ne $prevtrip->$this_test ) {
                push @newtrips, $thistrip;
                next TRIP_TO_MERGE;
            }
        }
        # so now we know they are the same

        $newtrips[-1] = $prevtrip->merge_trips($thistrip);

    }

    return \@newtrips;

} ## tidy end: sub merge_trips_if_same

no Moose;

#no Moose::Util::TypeConstraints;

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

=head1 NAME

Actium::Sked::Trip.pm - Object representing a trip in a schedule

=head1 VERSION

This documentation refers to Actium::Sked::Trip.pm version 0.001

=head1 DESCRIPTION

This is a Moose class, representing each trip of a bus schedule. It contains
information for each trip of a schedule. It is intended to be used by the 
L<Actium::Sked::HeadwayPage> object and the L<Actium::Sked> object.

=head1 ATTRIBUTES

Methods to get and set attributes are named in a semi-affordance fashion: 
setter methods are "set-I<attribute>()" but getter methods are just 
"I<attribute>()."

=over

=item B<days_obj>

...not written yet...

=item B<daysexceptions>

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
an L<Actium::Sked::Note> object.

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

=item B<stoptimes>

=item B<placetimes>

The elements of the I<stoptime_r> and I<placetime_r> array references, 
respectively.

=item B<stoptimes_are_empty>

=item B<placetimes_are_empty>

Returns false if stoptime_r or placetime_r, respectively, have any elements;
true otherwise.

=item B<placetime_count>

The number of elements in the placetime array.

=item B<placetime(I<index>)>

Returns the value of the placetime of the given index ( beginning at 0).

=item B<splice_placetimes(I<offset>, I<length>, I<values>)>

Like the perl builtin L<splice|perlfunc/splice>.

=item B<mergedtrip_r>

After trips are  merged using I<merge_trips()>, this array holds all the 
Actium::Sked::Trip objects that were originally merged.  

=item B<mergedtrips>

Returns the elements of I<mergedtrip_r>.

=item B<mergedtrip_count>

The number of elements in the mergedtrip array.

=back

=head1 CLASS METHODS

=over

=item B<merge_trips()>

This is a class method to merge two trips that, presumably, have identical stoptimes
and placetimes. (The purpose is to allow two trips that are scheduled identically --
two buses that are designed to run at the same time to allow an extra heavy load to be
carried -- to appear only once in the schedule.)

 Actium::Sked::Trip->merge_trips($trip1, $trip2);

A new Actium::Sked::Trip object is created, with attributes as follows:

=over

=item stoptimes and placetimes

The stoptimes and placetimes for the first trip are used.

=item mergedtrips

This attribute contains the Actium::Sked::Trip objects for all the parent trips. 
In the simplest case, it contains the two Actium::Sked::Trip objects passed to merge_trips.

However, if either of the Actium::Sked::Trip objects passed to merge_trips already has a
mergedtrips attribute, then instead of saving the current Actium::Sked::Trip object, it saves
the contents of mergedtrips. The upshot is that mergedtrips contains all the trips 
that are parents of this merged trip.

=item All other attributes

All other attributes are set as follows: if the value of an attribute is the same in 
the two trips, they are set with that value. Otherwise the attribute is not set.

=back

=item B<stoptimes_sort()>

To be written

=back

=head1 DIAGNOSTICS

See L<Moose>.

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::SemiAffordanceAccessor

=item MooseX::StrictConstructor

=item Actium::Constants

=item Actium::Time

=item Actium::Types

=item Actium::Util

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
