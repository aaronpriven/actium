package Actium::Sked::Trip::Time 0.014;

use Actium 'class';
use Actium::O::Time;

has _time_obj => (
    is       => 'rw',
    isa      => 'Actium::O::Time',
    required => 1,
    init_arg => 'time_obj',
    handles  => qr/^(?!(?:from_str|from_num|from_excel)$).*/,
);

has was_interpolated => (
    is      => 'ro',
    isa     => 'Bool',
    traits  => ['Bool'],
    default => 0,
    handles => { _make_interpolated => 'set' },
);

method set_interpolated_str ($string) {
    $self->_set_time_obj( Actium::O::Time->from_str($string) );
    $self->_make_interpolated;
    return;
}

method set_interpolated_num ($num) {
    $self->_set_time_obj( Actium::O::Time->from_num($num) );
    $self->_make_interpolated;
    return;
}

method from_str ($class: $string) {
    return $class->new( time_obj => Actium::O::Time->from_str($string) );
}

method from_num ($class: $num) {
    return $class->new( time_obj => Actium::O::Time->from_num($num) );
}

method from_excel ($class: $cell) {
    return $class->new( time_obj => Actium::O::Time->from_excel($cell) );
}

Actium::immut;

__END__

=encoding utf8

=head1 NAME

Actium::Sked::Trip::Time - Times associated with schedules

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Actium:Sked::Trip::Time;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS or ATTRIBUTES

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

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
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

