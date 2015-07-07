# Actium/O/Sked/Timetable/IDFrame.pm

# Moose object representing a frame (one of a series of one or more frames used
# on a page) for an InDesign timetable

# legacy status: 4

package Actium::O::Sked::Timetable::IDFrame 0.010;

use warnings;
use 5.016;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Actium::Util qw/halves/;

has widthpair_r => (
    # columns and half columns
    traits   => ['Array'],
    is       => 'ro',
    isa      => 'ArrayRef[Int]',
    required => 1,
    init_arg => 'widthpair',
    handles  => { widthpair => 'elements', },
);

has width => (
    # in half columns
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    builder => '_build_width',
);

sub _build_width {
    my $self = shift;
    return halves( $self->widthpair );
}

has frame_idx => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Actium::O::Sked::Timetable::IDFrame - Object representing an InDesign 
timetable frame

=head1 VERSION

This documentation refers to version 0.002

=head1 SYNOPSIS

 use Actium::O::Sked::Timetable::IDFrame;
 my $frameset = Actium::O::Sked::Timetable::IDFrame->new (
    widthpair => [10, 0],
    frame_idx => 0,
    );
 
=head1 DESCRIPTION

Each page of an Actium timetable document in InDesign consists of a series 
of text frames that are linked to each other, and to the pages before 
and after. 

These frames overlap, and the actual text is placed in an appropriate frame
depending on the specific size of the timetable and what other timetables are
placed with it on the same page.

This object represents a single frame: generally, its width, and 
where it is in the order of linked pages. (Its height is stored as part of its 
frame set.)

=head1 ATTRIBUTES

=over

=item B<widthpair>

Required during construction, it consists of two numbers representing the 
number of columns that fit on this page: first the number of whole columns, 
and then the number of half columns.

=item B<width>

Automatically generated from B<widthpair>, the width is simply the total
number of half columns (so, twice the number of columns, plus the number of
half columns).  Used for comparisons.


=item B<frame_idx>

The order of this frame in the linked set of frames. The first frame is 0, 
the second frame is 1, and so forth. It can be thought of as the number of 
"next frame" directives that has to be included in the text file to tell 
InDesign to go to the proper frame.

=back

=head1 DEPENDENCIES

=over 

=item Perl 5.016

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Actium::Util

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2013

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
