package Octium::O::Sked::Timetable::IDFrameSet 0.012;

# Actium/O/Sked/Timetable/IDFrameSet.pm

# Moose object representing the frame set (series of one or more frames
# used on a page) for an InDesign timetable

use Actium ('class');
use Octium;

use Octium::O::Sked::Timetable::IDFrame;

use overload '""' => sub { shift->description };
# overload ### DEP ###

has description => (
    isa => 'Str',
    is  => 'ro',
);

has frames_r => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Octium::O::Sked::Timetable::IDFrame]',
    required => 1,
    init_arg => 'frames',
    handles  => {
        frames      => 'elements',
        frame       => 'get',
        frame_count => 'count',
    },
);

has compression_level => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has height => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has is_portrait => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

around BUILDARGS ( $orig, $class: @) {

    my $params_r = Actium::hashref(@_);

    # run through each frame -- if it's not already an object,
    # instantiate the appropriate object and place it back in list

    return $class->$orig(@_)
      unless exists $params_r->{frames}
      and Octium::reftype( $params_r->{frames} ) eq 'ARRAY';

    my $frames_r = $params_r->{frames};

    foreach my $i ( 0 .. $#{$frames_r} ) {
        my $frame_r = $frames_r->[$i];

        next if blessed($frame_r);

        croak 'Frame passed to '
          . __PACKAGE__
          . '->new must be reference to hash of attribute specifications'
          unless Octium::reftype($frame_r) eq 'HASH';

        $frames_r->[$i] = Octium::O::Sked::Timetable::IDFrame->new($frame_r);

    }

    return $class->$orig($params_r);

}    ## tidy end: around BUILDARGS

Actium::immut;

1;

__END__


head1 NAME

Octium::O::Sked::Timetable::IDFrameSet - Object representing a set of 
InDesign timetable frames

=head1 VERSION

This documentation refers to version 0.002

=head1 SYNOPSIS

 use Octium::O::Sked::Timetable::IDFrameSet;
 my $frameset = Octium::O::Sked::Timetable::IDFrameSet->new(
     description       => 'Landscape halves',
     compression_level => 0,
     height            => 42,
     frames            => [
         {   widthpair => [ 4, 1 ],
             frame_idx => 0,
         },
         {   widthpair => [ 5, 0 ],
             frame_idx => 2,
         },
     ],
 );

 
=head1 DESCRIPTION

Each page of an Actium timetable document in InDesign consists of a
series  of text frames that are linked to each other, and to the pages
before  and after.

These frames overlap, and the actual text is placed in an appropriate
frame depending on the specific size of the timetable and what other
timetables are placed with it on the same page.

This object represents a set of frames, and contains the frame objects
and the compression level.

=head1 ATTRIBUTES

=over

=item B<description>

An optional text description of this frame (usually something like 
"Portrait halves" for two frames representing two halves of a portrait
page). At this point it's not used for anything, but it's convenient to
have a place for it in I<new()> calls.

=item B<is_portrait>

True if this frameset represents a portrait page. Defaults to false.

=item B<frames>

Required during construction, it consists of the frames that make up
the  frameset. Frames are described in 
L<Octium::O::Sked::Timetable::IDFrame|Octium::O::Sked::Timetable::IDFrame>.
In the constructor, it should be passed as an array reference; it will
be  returned as a plain list of objects.

If any of the values passed in the I<frames> entry is an unblessed hash
 reference, Octium::O::Sked::Timetable::IDFrameSet will pass it to 
Octium::O::Sked::Timetable::IDFrame->new() and use the result.  (So,
you don't have to explicitly create the IDFrame objects; this module
will do it for you.)

=item B<height>

Requiretd during construction, this is the height  of these frames in
terms of rows in the table. It should be specified excluding the number
of rows used for the header (line name, direction, days, and timepoint
names).

=item B<compression_level>

An integer, it represents the amount of shrinkage this timetable will
be  subjected to. Compression level 0 is full size; compression level 1
is smaller; compression level 2 is smaller yet; etc.

The idea is that timetables that are small can be printed with bigger
type or  with bigger table cells, while timetables that are large might
need to be shrunk ("compressed") to fit on a page.  The various IDFrame
objects are  designed to allow different sizes to be used in different
circumstances.

=back

=head1 DEPENDENCIES

=over 

=item Perl 5.016

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Scalar::Util

=item Octium::O::Sked::Timetable::IDFrame

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2013

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

