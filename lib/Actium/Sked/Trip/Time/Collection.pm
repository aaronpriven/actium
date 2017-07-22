package Actium::Sked::Trip::Time::Collection 0.012;

# Collection of trips

use Actium ('role');

# This is a role applied to Actium::Sked::Trip. It represents
# the methods associated with the collection of times in the trip

# The following is invoked only from the BUILD routine in Actium::Sked
# It requires knowledge of the stopplaces which is in the Sked object

sub _add_placetimes_from_stoptimes {
    my $self = shift;
    return unless $self->placetimes_are_empty;

    my @stopplaces = @_;

    my @stoptimes = $self->stoptimes;
    my @placetimes;

    for my $i ( 0 .. $#stoptimes ) {

        my $stopplace = $stopplaces[$i];
        my $stoptime  = $stoptimes[$i];

        if ($stopplace) {
            push @placetimes, $stoptime;
        }
    }

    $self->_set_placetime_r( \@placetimes );

    return;

} ## tidy end: sub _add_placetimes_from_stoptimes

################
### STOPTIMES
################

has 'stoptime_r' => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Actium::Sked::Trip::Time]',
    required => 1,
    init_arg => 'stoptimes',
    handles  => {
        stoptime       => 'get',
        stoptimes      => 'elements',
        stoptime_count => 'count',
    },
);

has stoptimes_comparison_str => (
    is   => 'ro',
    lazy => method {
        join( '|', Actium::define( map { $_->timenum } $self->stoptimes ) )
    },
    traits => ['DoNotSerialize'],
);

has average_stoptime => (
    is   => 'ro',
    lazy => method {
        Actium::mean( grep { $_->has_time } $self->stoptimes )
    },
    traits => ['DoNotSerialize'],
);

has destination_stoptime_idx => (
    is   => 'ro',
    lazy => method {
        my $reverseidx
          = Actium::firstidx { $_->has_time } ( reverse $self->stoptimes );
        return $self->stoptime_count - $reverseidx - 1;
    },
    traits => ['DoNotSerialize'],
);

sub stoptimes_equals {
    my $self       = shift;
    my $secondtrip = shift;
    return $self->stoptimes_comparison_str eq
      $secondtrip->stoptimes_comparison_str;
}

################
### PLACETIMES
################

has placetime_r => (
    traits   => ['Array'],
    is       => 'bare',
    writer   => '_set_placetime_r',
    init_arg => 'placetimes',
    isa      => 'ArrayRef[Actium::Sked::Trip::Time]',
    required => 0,
    default  => sub { [] },
    trigger  => 1,
    handles  => {
        placetimes           => 'elements',
        placetime_count      => 'count',
        placetimes_are_empty => 'is_empty',
        placetime            => 'get',
        _splice_placetimes   => 'splice',
        _delete_placetime    => 'delete',
        # only from BUILD in Actium::O::Sked
    },
);

method _trigger_placetime_r ($placetimes_r, $?) {
    my @stoptimes = $self->stoptimes;

    foreach my $placetime (@$placetimes_r) {
        if ( Actium::none { $_ == $placetime } @stoptimes ) {
            croak 'Actium::Sked::Trip::Time object '
              . 'found in placetimes but not in stoptimes.';
        }
    }

    return;

}

1;

__END__

=head1 NAME

Actium::Sked::Trip::Time::Collection - Role representing collection of 
schedule times

=head1 VERSION

This documentation refers to Actium:::Sked::Trip::Time::Collection version 0.014

=head1 DESCRIPTION

This is a Moose role, representing the collection of times associated with
a trip of a transit schedule.  It is designed to be applied to the 
Actium::Sked::Trip class, but could conceivably be used for other collections
of times.

=head1 ATTRIBUTES

=head2 B<stoptimes>

This is an array of Actium::Sked::Trip::Time objects, each one representing
the time the vehicle passes a stop. See Actium::Sked::Trip::Time and 
Actium::Time for more details.

In the constructor, the <stoptimes> entry expects an array reference.
The C<stoptimes> method returns a list of the times. The stoptimes 
attribute is read-only.

=item B<placetimes>

This is a list of those times (from 




In the constructor, the <stoptimes> entry expects an array reference.
The C<stoptimes> method returns a list of the times.

Two references to arrays containing times, numerically, 
in minutes since midnight 
(minutes before midnight are shown as negative numbers). There is one entry 
for each stop or place in the schedule, even if the stop or place 
is not served by this trip.
Entries for stops or places not served by this trip are stored as I<undef>.

These are integers, the number of minutes since midnight (or before midnight, if
negative). If an entry is set to a string, it is coerced to an integer using 
L<Actium::Time|Actium::Time>.

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

Returns the value of the placetime of the given index (beginning at 0).

=item B<mergedtrips>

After trips are  merged using I<merge_pair()>, this will return all the 
Actium::O::Sked::Trip objects that were originally merged.  

=back

=head1 OBJECT METHODS

=over

=item B<merge_pair()>

This is a method to merge two trips that, presumably, have identical stoptimes
and placetimes. (The purpose is to allow two trips that are scheduled identically --
two buses that are designed to run at the same time to allow an extra heavy load to be
carried -- to appear only once in the schedule.)

 $trip1->merge_pair($trip2);

A new Actium::O::Sked::Trip object is created, with attributes as follows:

=over

=item stoptimes and placetimes

The stoptimes and placetimes for the first trip are used.

=item mergedtrips

This attribute contains the Actium::O::Sked::Trip objects for all
the parent trips.  In the simplest case, it contains the two
Actium::O::Sked::Trip objects passed to merge_pair.

However, if either of the Actium::O::Sked::Trip objects passed to
merge_pair already has a mergedtrips attribute, then instead of
saving the current Actium::O::Sked::Trip object, it saves the
contents of mergedtrips. The upshot is that mergedtrips contains
all the trips that are parents of this merged trip.

=item All other attributes

All other attributes are set as follows: if the value of an attribute is the same in 
the two trips, they are set with that value. Otherwise the attribute is not set.

=back

=head1 DIAGNOSTICS

See L<Moose>.

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item MooseX::Storage

=item Actium::Types

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
