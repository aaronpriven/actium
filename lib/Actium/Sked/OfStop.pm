package Actium::Sked::OfStop 0.014;

use Actium 'class';

has stopid => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has _stopskeds_r => (
    traits   => ['Array'],
    is       => 'bare',
    init_arg => 'stopskeds',
    isa      => 'ArrayRef[Actium::Sked::OfStop::StopSked]',
    required => 1,
    handles  => { stopskeds => 'elements', },
);

1;

__END__

=encoding utf8

=head1 NAME

Actium::Sked::OfStop - Object representing schedule info for a
particular  bus stop

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Actium::Sked::OfStop;
 # do something with Actium::Sked::OfStop
   
=head1 DESCRIPTION

This represents schedule information for a particular bus stop.

=head1 ATTRIBUTES/METHODS

=head2 stopid

Returns the unique identifier of the bus stop.

=head2 stopskeds

Returns a list of the Actium::Sked::OfStop::Sked objects that are
appropriate for this stop.

=head1 DIAGNOSTICS

None so far.

=head1 CONFIGURATION AND ENVIRONMENT

None so far.

=head1 DEPENDENCIES

=over

=item * 

Actium

=back

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
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

