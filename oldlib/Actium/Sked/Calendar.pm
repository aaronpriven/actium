package Actium::Sked::Calendar 0.014;

use Actium ('class');

# I think these are the attributes that the calendar should have,
# but I'm not at all sure how they will be accessed, what will be
# required, whether there will be defaults, etc. etc.

has 'calendar_id' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has [qw/start end/] => (
    is       => 'ro',
    isa      => 'Actium::Date',
    required => 1,
);

has dateset => (
    is  => 'ro',
    isa => 'DateTime::Set',
);

has days => (
    is  => 'ro',
    isa => 'Actium::Days',
);

has note => (
    is  => 'ro',
    isa => 'Str',
);

has noteletter => (
    is  => 'ro',
    isa => 'Str',
);

Actium::immut;

1;

__END__

=head1 NAME

Actium::Sked::Calendar - Object representing a schedule calendar

=head1 VERSION

This documentation refers to Actium::Sked::Calendar version 0.014

=head1 DESCRIPTION

This is a Moose class, representing a the dates that a schedule will
operate. 

=head1 ATTRIBUTES

All attributes are read-only.

...not written yet...


=head2 B<noteletter>

...

The letter(s) representing the note for this trip. The full note is contained elsewhere...

=back

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
