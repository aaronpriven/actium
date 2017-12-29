package Actium::Sked::CalendarCollection 0.014;

use Actium ('class');

has calendars_r => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::Sked::Calendar]',
    handles => { calendars => 'elements' },
);

method determine_noteletters {
    # not sure how this should work -- notes clearly
    # have to be decided at the whole collection level,
    # but in general one is only interested in the note
    # for a particular calendar.

    # maybe each calendar has a weak ref to its parent,
    # and then calendar->noteletter says "aha, no noteletter here"
    # and at that point it determines all the noteletters for the
    # whole collection.

    ...;

}

Actium::immut;

1;

__END__

=head1 NAME

Actium::Sked::CalendarCollection - Class representing a collection of
schedule calendars

=head1 VERSION

This documentation refers to Actium::Sked::CalendarCollection version
0.014

=head1 DESCRIPTION

This is a Moose class, representing sets of dates that a schedule will
operate.

=head1 ATTRIBUTES

All attributes are read-only.

...not written yet...


=head1 DIAGNOSTICS

See L<Moose>.

=head1 DEPENDENCIES

=over

=item the Actium system

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

