package Octium::Sked::StopSked 0.015;
# vimcolor: #002613

use Actium 'class';

use Octium::Types   (qw/ActiumDays/);
use Types::Standard (qw/Str ArrayRef/);
use Actium::Types('Dir');
use Actium::Dir;

has [qw/stopid linegroup/] => (
    required => 1,
    is       => 'ro',
    isa      => Str,
);

has dir => (
    required => 1,
    coerce   => 1,
    is       => 'ro',
    isa      => Dir,
    handles  => {
        should_preserve_direction_order => 'should_preserve_direction_order',
        to_text                         => 'as_to_text',
    },
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

method id {
    my $id = join( '_',
        $self->stopid,       $self->linegroup,
        $self->dir->dircode, $self->days->daycode,
    );
    return $id;
}

has _trips_r => (
    required => 1,
    isa      => 'ArrayRef[Octium::Sked::StopTrip]',
    is       => 'bare',
    init_arg => 'trips',
    traits   => ['Array'],
    handles  => { 'trips' => 'elements' },
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

method freeze {
    my @trips = $self->trips;
    @trips = map { $_->freeze } @trips;

    my $struct = {
        trips => \@trips,
        days  => $self->days->freeze,
        dir   => $self->dir->freeze,
        map { $_ => $self->$_ } qw/stop_id linegroup/
    };
    require JSON;    ### DEP ###
    return JSON->new->encode($struct);
}

method thaw (Str $cyst) {
    require JSON;
    my $struct = JSON->new->decode($cyst);
    $struct->{days} = Octium::Days->thaw( $struct->{days} );
    $struct->{dir}  = Octium::Dir->thaw( $struct->{dir} );
    $struct->{trips}
      = map { Octium::Sked::StopTrip->thaw($_) } $struct->trips->@*;
    return $self->new($struct);
}

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

=head2 thaw($string)

The C<thaw> method takes a string created by the C<freeze> method and
returns a recreated object.

=head1 ATTRIBUTES

All attributes are required to be passed to the constructor.

=head2  stopid

A string, the stop ID of the represented stop.

=head2 linegroup

A string, the line group ID of the schedule being reprented here. A
line group is the set of lines that appear on a single schedule.
Usually each line group has only one line, but for example, lines 72
and 72M should be in the same line group.

=head2 dir

An L<Actium::Dir|Actium::Dir> object representing the direction of
travel for this schedule. Uses coercions defined in
L<Actium::Types|Actium::Types>.

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

=head2 freeze

This returns a string which, when passed to the C<thaw> class method,
will recreate the object.

=head1 DIAGNOSTICS

None specific to this class, but see L<Actium|Actium> and
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

