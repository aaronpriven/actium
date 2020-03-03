package Octium::Sked::Trip::Time 0.014;

use Actium 'class';

use Actium::Time;

has _time_obj => (
    is       => 'rw',
    isa      => 'Actium::Time',
    required => 1,
    init_arg => 'time_obj',
    handles  => qr/^(?!(?:new|from_str|from_num|from_excel)$).*/,
    # use all of Actium::Time's methods except for
    # from_str, from_num, from_excel which are defined below
    # and new which nobody should be using anyway
);

has was_interpolated => (
    is      => 'ro',
    isa     => 'Bool',
    traits  => ['Bool'],
    default => 0,
    handles => { _make_interpolated => 'set' },
);

method set_interpolated_str ($string) {
    $self->_set_time_obj( Actium::Time->from_str($string) );
    $self->_make_interpolated;
    return;
}

method set_interpolated_num ($num) {
    $self->_set_time_obj( Actium::Time->from_num($num) );
    $self->_make_interpolated;
    return;
}

method from_str ($class: $string) {
    return $class->new( time_obj => Actium::Time->from_str($string) );
}

method from_num ($class: $num) {
    return $class->new( time_obj => Actium::Time->from_num($num) );
}

method from_excel ($class: $cell) {
    return $class->new( time_obj => Actium::Time->from_excel($cell) );
}

Actium::immut;

__END__

=encoding utf8

=head1 NAME

Octium::Sked::Trip::Time - Times associated with schedules

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Octium:Sked::Trip::Time;
 my $time = Octium::Sked::Trip::Time->from_str('21:30');
   
=head1 DESCRIPTION

Octium::Sked::Trip::Time is an object representing a time in a 
schedule. Most of the work is done by
L<Actium::Time|Actium::Time>, q.v. , and all methods supported by
Actium::Time are supported by this module. There are only a small
number of additional methods, which allow the replacement of a time in a
schedule by an interpolated version.

=head1 METHODS 

=head2 was_interpolated

This method returns a boolean value: true if a time has been
interpolated here, false if it has not. This indicates that the time
I<was> interpolated -- to check if a time still needs to be
interpolated, use the method C<is_awaiting_interpolation> (documented in
Actium::Time).

=head2 set_interpolated_str, set_interpolated_num

These methods set the value of this time to a new value. The C<set_interpolated_str>
method expects a string (which is sent to by Actium::Time->from_str), and the
C<set_interpolated_num> method expects a number (sent to
Actium::Time->from_num). They also mark this time as having been
interpolated (which can be queried by C<was_interpolated>).

=head2 from_str, from_num, from_excel

These are the same as their counterparts in Actium::Time, except that
they return an Octium::Sked::Trip::Time object instead of an
Actium::Time object.

=back

=head1 DEPENDENCIES

=over

=item Actium

=item Actium::Time

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

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

