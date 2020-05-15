package Octium::Sked::StopSked 0.015;
# vimcolor: #002020

use Actium 'class';

use Octium::Types (qw/ActiumDays/);
use Octium::Days;
use Types::Standard        (qw/Str ArrayRef InstanceOf/);
use Types::Common::Numeric (qw/PositiveOrZeroInt/);
use DDP;

### ATTRIBUTES

has [qw/stopid/] => (
    required => 1,
    is       => 'ro',
    isa      => Str,
);

has days => (
    required => 1,
    coerce   => 1,
    is       => 'ro',
    isa      => ActiumDays,
    handles  => {
        daycode       => 'daycode',
        sortable_days => 'as_sortable',
    },
);

has _trips_r => (
    required => 1,
    isa      => ArrayRef [ InstanceOf ['Octium::Sked::StopTrip'] ],
    is       => 'rw',
    init_arg => 'trips',
    traits   => ['Array'],
    handles  => {
        trips      => 'elements',
        trip_count => 'count',
        trip       => 'get',
    },
);

has is_final_stop => (
    lazy     => 1,
    builder  => 1,
    init_arg => undef,
    is       => 'ro',
);

method _build_is_final_stop {
    return Actium::all { $_->is_final_stop } $self->trips;
}

has is_dropoff_only => (
    lazy     => 1,
    builder  => 1,
    init_arg => undef,
    is       => 'ro',
);

method _build_is_dropoff_only {

    return Actium::all { $_->is_dropoff_only } $self->trips;
    return 0;
}

has _merge_comparison_strings_r => (
    lazy     => 1,
    builder  => 1,
    init_arg => undef,
    traits   => ['Array'],
    is       => 'ro',
    handles  => { merge_comparison_strings => 'elements', },
);

method _build_merge_comparison_strings_r {

    my @merge_comparison_strings;
    for my $trip ( $self->trips ) {
        my @trip_components = (
            $trip->line,
            $trip->dir->as_sortable,
            $trip->time->timenum,
            $trip->is_at_place ? $trip->place_in_effect : $EMPTY,
            $trip->destination_place,
        );
        push @merge_comparison_strings, join( "\N{US}", @trip_components );
    }

    return \@merge_comparison_strings;
}

has _lines_r => (
    isa      => ArrayRef [Str],
    builder  => '_build_lines',
    lazy     => 1,
    init_arg => undef,
    traits   => ['Array'],
    is       => 'bare',
    handles  => {
        lines      => 'elements',
        _line_str  => [ join => ':' ],
        _linegroup => [ get => 0 ],
    },
);

method _build_lines {
    my @lines = map { $_->line } $self->trips;
    @lines = Actium::uniq( Actium::sortbyline @lines );
    return \@lines;
}

has id => (
    isa      => Str,
    is       => 'ro',
    builder  => '_build_id',
    lazy     => 1,
    init_arg => undef,
);

method _build_id {

    my $stopid   = $self->stopid;
    my @linedirs = map { [ $_->line, $_->dir ] } $self->trips;
    my $linedirs = join( ":",
        map  { $_->[0] . $SPACE . $_->[1] }
        sort { $a->[2] cmp $b->[2] or $a->[3] cmp $b->[3] }
        map  { [ $_->@*, Actium::linekeys( $_->@* ) ] } @linedirs );
    my $daycode = $self->days->daycode;

    return join( '_', $stopid, $linedirs, $daycode );

}

method BUILD {
    my @sorted_trips = map { $_->[0] }
      sort { $a->[1] <=> $b->[1] or $a->[2] cmp $b->[2] }
      map  { [ $_, $_->time->timenum, Actium::linekeys( $_->line ) ] }
      $self->trips;
    $self->_set_trips_r( \@sorted_trips );

    # I think this is the only place I will ever need to sort stoptrips.  If I
    # need to sort them anywhere else, it should be made a class method of
    # Octium::Sked::StopTrip

    $_->_set_stopsked($self) foreach @sorted_trips;
    # tell each trip what schedule it belongs to
}

### BUNDLE / UNBUNDLE ###

method bundle {
    my @trips = $self->trips;
    my @stoppatterns;
    my @tripstructs;
    my %stoppattern_idx_of;

    foreach my $trip (@trips) {
        my $tripstruct  = $trip->bundle;
        my $stoppattern = $trip->stoppattern;
        my $refaddr     = Actium::refaddr($stoppattern);
        if ( exists $stoppattern_idx_of{$refaddr} ) {
            $tripstruct->{stoppattern} = $stoppattern_idx_of{$refaddr};
            # replace stoppattern struct with index
        }
        else {
            push @stoppatterns, $tripstruct->{stoppattern};
            $tripstruct->{stoppattern} = $stoppattern_idx_of{$refaddr}
              = $#stoppatterns;
        }
        push @tripstructs, $tripstruct;
    }

    return {
        trips        => \@tripstructs,
        stoppatterns => \@stoppatterns,
        days         => $self->days->bundle,
        map { $_ => $self->$_ } qw/stopid/
    };
}

classmethod unbundle (HashRef $bundle ) {
    \my @stoppatterns = delete $bundle->{stoppatterns};
    @stoppatterns
      = map { Octium::Sked::StopTrip::StopPattern->unbundle($_) } @stoppatterns;

    foreach my $tripstruct ( $bundle->{trips}->@* ) {
        $tripstruct->{stoppattern}
          = $stoppatterns[ $tripstruct->{stoppattern} ];
    }
    # replace index with stoppattern

    $bundle->{days} = Octium::Days->unbundle( $bundle->{days} );

    return $class->new($bundle);

}

### OBJECT METHODS

method kpoint {

    my $firsttrip = $self->trip(0);
    my $linegroup = $firsttrip->line;
    my $dir       = $firsttrip->dir->_as_hastus_order;
    my $day       = $self->daycode;
    $day =~ s/H//;

    my @entries = ( $linegroup, $dir, $day );

    if ( $self->is_final_stop ) {
        push @entries, "#LASTSTOP", join( ':', $self->lines );
        my @dests = map { $_->destination_place } $self->trips;
        @dests = Actium::uniq( sort @dests );
        push @entries, join( ':', @dests );
    }
    else {

        for my $trip ( $self->trips ) {
            next if $trip->calendar_id;
            push @entries,
              join( ':',
                $trip->time->apbx_noseparator,
                $trip->line,
                $trip->destination_place,
                $trip->is_at_place ? $trip->place_in_effect : $EMPTY,
                $EMPTY );
        }
    }
    return join( "\t", @entries );

}

method ensuing_count (PositiveOrZeroInt $threshold //=0 ) {

    my %ensuing_count;
    foreach my $trip ( $self->trips ) {
        my $ensuing_str = $trip->ensuing_str($threshold);
        $ensuing_count{$ensuing_str}++;
    }

    return \%ensuing_count;

}

### MERGING AND COMBINING

# merge - merge two schedules so that identical trips are merged into one

classmethod merge ($leftsked , $rightsked) {
    # signals an invalid merge with empty return

    my @ltrips = map { [ $_, $_->time->timenum ] } $leftsked->trips;
    my @rtrips = map { [ $_, $_->time->timenum ] } $rightsked->trips;
    my @newtrips;

    while ( @ltrips and @rtrips ) {
        my @l = ( shift @ltrips )->@*;
        my @r = ( shift @rtrips )->@*;
        my ( $ltrip, $ltime ) = @l;
        my ( $rtrip, $rtime ) = @r;

        if ( $ltime < $rtime ) {
            push @newtrips, $ltrip;
            unshift @rtrips, \@r;
        }
        elsif ( $rtime < $ltime ) {
            push @newtrips, $rtrip;
            unshift @ltrips, \@l;
        }
        else {    # times are equal - merge if possible
            if (   $ltrip->line ne $rtrip->line
                or $ltrip->calendar_id ne $rtrip->calendar_id
                or $ltrip->stoppattern != $rtrip->stoppattern
                or $ltrip->dir->dircode ne $rtrip->dir->dircode )
            {
                return;
            }
            # invalid merger. I don't want to display times like
            #     7:15
            #     7:15¹
            #  or
            #     8:00¹
            #     8:00²
            #  It's too confusing and complicated.
            #  And I don't want to write code that deals with all the
            #  zillions of possible exceptions that would be needed:
            #
            #     ¹ - On weekdays, goes to 14th & Broadway, except on
            #  weekends and on 7/4 and 9/3, when it goes to Lake Merritt
            #  BART.
            #
            # So return blank, and don't merge these schedules at all.
            #
            # Note that stoppattern is reference equality, and depends on
            # stoppattern being a flyweight object.

            my %newtripspec = map { $_, $ltrip->$_ }
              qw/time line dir calendar_id stoppattern/;
            $newtripspec{days}
              = Octium::Days->union( $rtrip->days, $ltrip->days );

            my $tripclass = Actium::blessed $ltrip;
            push @newtrips, $tripclass->new(%newtripspec);

        }

    }

   # at least one of @ltrips or @rtrips is exhausted, but the other might not be
    push @newtrips, $_->[0] foreach ( @ltrips, @rtrips );

    my $days = Octium::Days->union( $leftsked->days, $rightsked->days );

    return $class->new(
        trips  => \@newtrips,
        stopid => $leftsked->stopid,
        days   => $days,
    );

}

# merge - combine two schedules so that trips from two different schedules are placed
# in the same column. It's not assumed that any of them are the same

classmethod combine (@stopskeds) {

    my $days = Octium::Days->union( map { $_->days } @stopskeds );

    my @stopids = map { $_->stopid } @stopskeds;
    unless ( Actium::all_eq(@stopids) ) {
        croak "Can't merge schedules where stop IDs are different";
    }

    my @trips = map { $_->trips } @stopskeds;

    return $class->new(
        trips  => \@trips,
        stopid => $stopids[0],
        days   => $days
    );

}

Actium::immut;

1;

__END__

=encoding utf8

=head1 NAME

Octium::Sked::StopSked - Object representing a schedules of a
particular stop

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use Octium::Sked::StopSked;
 Octium::Sked::StopSked->new(...)

=head1 DESCRIPTION

This is an object that represents a single schedule for a stop: the
trips on a line, in a direction, and on scheduled days, passing a
single stop.  It is created using Moose.

=head1 CLASS METHODS

=head2 new

The method inherits its constructor from Moose.

=head2 unbundle

 $stopsked = Octium::Sked::StopSked->unbundle($string);

The C<unbundle> method takes a string created by the C<bundle> method
and returns a recreated object.

=head2 merge 

 $merged = Octium::Sked::StopSked->merge(@stopskeds);

The C<merge> method takes two stop schedule objects and merges them
into a single object, with a combined set of trips.

The schedules must all be associated with the same stop ID.  The days
are set to be a union of all the associated schedules' days.

=head1 ATTRIBUTES

All attributes are required to be passed to the constructor.

=head2 stopid

A string, the stop ID of the represented stop.

=head2 days

An L<Octium::Days|Octium::Days> object representing the scheduled days
of service for this schedule. Required.  Uses coercions defined in
L<Actium::Types|Actium::Types>.

=head2 trips

An array of L<Octium::Sked::StopTrip|Octium::Sked::StopTrip> objects. 
It is expected to be passed in the order in which it will be displayed.
 The "trips" argument in the constructor should be a reference to the
array, while the trips() method will return the list.

=head1 OBJECT METHODS

=head2 is_final_stop

True if this is the final stop of this schedule, false otherwise. (Only
true if it is the final stop of I<every> trip, not just some trips.)

=head2 bundle

This returns a string which, when passed to the C<unbundle> class
method, will recreate the object.

=head2 ensuing_count ($threshold)

Returns a hash reference. The key is a string, the result of
L<C<ensuing_str> in
Octium::Sked::StopTrip::EnsuingStops|Octium::Sked::StopTrip::EnsuingStops/ensuing_str>.
All trips with the same ensuing stops (up to $threshold, or all of them
if $threshold is omitted or 0) will have the same string.  The values
are the counts, the number of trips which will see those ensuing stops.

=head1 DIAGNOSTICS

=over

=item Can't merge schedules where stop IDs are different

The C<merge> method received schedules that didn't share a stop ID.
Merged schedules must share a stop ID.

=back

See alaso L<Actium|Actium> and L<Moose|Moose>.

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

