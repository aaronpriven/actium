package Actium::Sked::Trip::TimeCollection 0.014;

# Collection of times

use Actium ('class');

# This represents a set of times that's part of a trip --
# either stoptimes or placetimes

has '_times_r' => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => 'ArrayRef[Actium::Sked::Trip::Time]',
    required => 1,
    init_arg => 'times',
    handles  => {
        time      => 'get',
        times     => 'elements',
        count     => 'count',
        '_splice' => 'splice',
        '_delete' => 'delete',
    },
);

# splice and delete should only happen when setting placetimes
# times_r reader is there just for the slice method, below

has comparison_str => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
    traits  => ['DoNotSerialize'],
);

method _build_comparison_str {
    return join( '|', Actium::define( map { $_->timenum } $self->times ) );
}

has average => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
    traits  => ['DoNotSerialize'],
);

method _build_average {
    return Actium::mean( grep { $_->has_time } $self->times );
}

has destination_idx => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
    traits  => ['DoNotSerialize'],
);

method _build_destination_idx {
    my $reverseidx = Actium::firstidx { $_->has_time } ( reverse $self->times );
    return $self->stoptime_count - $reverseidx - 1;
}

sub equals {
    my $self             = shift;
    my $other_collection = shift;
    return $self->comparison_str eq $other_collection->comparison_str;
}

method slice (@indices) {
    my $times_r = $self->_time_r;
    return $times_r->@[@indices];
}

1;

__END__

=head1 NAME

Actium::Sked::Trip::TimeCollection - Class representing collection of 
schedule times

=head1 VERSION

This documentation refers to Actium:::Sked::Trip::TimeCollection
version 0.014

=head1 DESCRIPTION

This object is a Moose class, representing the collection of times
associated with a trip of a transit schedule.  It might contain times
for all the stops on a trip, or only those that are published in
schedules ("timepoints"). It is normally held by the Actium::Sked::Trip
objects.

All data is read-only once created.

=head1 CONSTRUCTION

The object is constructed by passing a parameter named "times" to the
"new"  constructor.

=head2 B<times>

This must be a reference to an array of Actium::Sked::Trip::Time
objects, each one representing the time the vehicle passes a stop. See
Actium::Sked::Trip::Time and Actium::Time for more details.

There should be one entry for each entry in the schedule (either stops,
if this is a set of times for stops, or places, if this is a set of
times for places). Some trips do not serve all stops, and entries
representing unserved stops or places should have an Actium::Time value
that means "service does not stop here".

=head1 METHODS

=head3 C<times()>

The C<imes> method returns a list of the times.

=head3 C<time( I<index> ) >

The C<time> method returns the time object at the specified index.

=head3 C<slice( I<index>, I<index>, ... ) >

The C<slice> method returns the times at the specified indices.

=head3 C<count()>

The C<count> method returns the count of the times.

=head3 C<equals($other_collection)>

The C<equals> method checks if two time collections are equal: the
current collection and the one passed in the argument. It returns a
boolean value: true if they are equal.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011-2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

