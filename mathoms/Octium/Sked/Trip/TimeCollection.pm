package Octium::Sked::Trip::Time::Collection 0.014;

use Actium ('role');
use Octium;

# This is part of a start at rewriting Actium::Sked to use time objects
# and otherwise be more modern. It is not complete.

# This is a role applied to Octium::Sked::Trip. It represents
# the methods associated with the collection of times in the trip

################
### STOPTIMES
################

has 'stoptime_r' => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Octium::Sked::Trip::Time]',
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
    isa      => 'ArrayRef[Octium::Sked::Trip::Time]',
    required => 0,
    default  => sub { [] },
    trigger  => method( $placetimes_r, $? )
    {
        my @stoptimes = $self->stoptimes;
        foreach my $placetime (@$placetimes_r) {
            if ( Actium::none { $_ == $placetime } @stoptimes ) {
                croak 'Octium::Sked::Trip::Time object '
                  . 'found in placetimes but not in stoptimes.';
            }
        }
        return;
    },
    handles => {
        placetimes            => 'elements',
        placetime_count       => 'count',
        _placetimes_are_empty => 'is_empty',
        placetime             => 'get',
        _splice_placetimes    => 'splice',
        _delete_placetime     => 'delete',
        # only from BUILD in Octium::Sked
    },
);

method placetimes_initialized {
    return not $self->_placetimes_are_empty;
}

method specify_placetimes (@stoptimes_indices) {
    my @placetimes;
    for my $index (@stoptimes_indices) {
        push @placetimes, $self->stoptime($index);
    }
    $self->_set_placetime_r( \@placetimes );
    return;
}

1;

__END__

=head1 NAME

Octium::Sked::Trip::Time::Collection - Role representing collection of 
schedule times

=head1 VERSION

This documentation refers to Octium:::Sked::Trip::Time::Collection
version 0.014

=head1 DESCRIPTION

This is a Moose role, representing the collection of times associated
with a trip of a transit schedule.  It is designed to be applied to the
 Octium::Sked::Trip class, but could conceivably be used for other
collections of times.

=head1 ATTRIBUTES

=head2 B<stoptimes>

This is an array of Octium::Sked::Trip::Time objects, each one
representing the time the vehicle passes a stop. See
Octium::Sked::Trip::Time and Actium::Time for more details.

There is one entry for each stop in the schedule, although that may
point to an Actium::Time value representing a stop that is not served
by this trip.

=head3 construction

In the constructor, the C<stoptimes> entry expects an array reference.

=head3 C<stoptimes> method

The C<stoptimes> method returns a list of the times. The stoptimes 
attribute is read-only.

=head3 C<stoptime( I<index> ) > method

The C<stoptime> method returns the time object at the specified index.

=head3 C<stoptime_count> method

The C<stoptime_count> method returns the count of the elements of
stoptimes.

=head2 C<placetimes>

This is a list of those times from C<stoptimes> that are the times
representing "places" (timepoints).

There is one entry for each place (timepoint) in the schedule, although
that may point to an Actium::Time value representing a stop that is not
served by this trip.

=head3 construction

In the constructor, the C<placetimes> entry expects an array reference.

=head3 C<placetimes> method

The C<placetimes> method returns a list of the times.

=head3 C<placetime( I<index> ) > method

The C<placetime> method returns the time object at the specified index.

=head3 C<placetime_count> method

The C<placetime_count> method returns the count of the elements of
placetimes.

=head3 C<placetimes_initialized>

Returns true if the placetimes have been initialized, false otherwise.

=head3 C<< specify_placetimes (I<stoptime_indices>) >>

This method accepts a list of indices in stoptimes, to be made into the
placetimes for this object. So, for example, C<specify_placetimes
(0,3,7,9)> would make the zeroth, third, seventh, and ninth stop times
into the place times.

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

