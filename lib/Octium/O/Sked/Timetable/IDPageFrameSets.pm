package Octium::O::Sked::Timetable::IDPageFrameSets 0.012;

# Moose object representing all the frame sets (series of one or more frames
# used on a page) for an InDesign timetable

use Actium ('class');
use Octium;
use Octium::O::Sked::Timetable::IDFrameSet;
use Octium::O::Sked::Timetable::IDTimetable;
use Octium::Set(':all');

use Params::Validate (':all');    ### DEP ###

const my $IDTABLE => 'Octium::O::Sked::Timetable::IDTimetable';

has frameset_r => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Octium::O::Sked::Timetable::IDFrameSet]',
    required => 1,
    init_arg => 'framesets',
    handles  => { framesets => 'elements', },
);

has portrait_preferred_frameset_r => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Octium::O::Sked::Timetable::IDFrameSet]',
    lazy    => 1,
    builder => '_build_portrait_preferred_frameset_r',
    handles => { portrait_preferred_framesets => 'elements', },
);

sub _build_portrait_preferred_frameset_r {
    my $self = shift;

    my @divided_framesets;

    foreach my $frameset ( $self->framesets ) {
        my $portrait = $frameset->is_portrait ? 0 : 1;
        # avoids non-zero false values

        push @{ $divided_framesets[$portrait] }, $frameset;
    }

    return scalar Octium::flatten(@divided_framesets);

}

around BUILDARGS ( $orig, $class: @ ) {

    my @framesets = map { Octium::O::Sked::Timetable::IDFrameSet->new($_) } @_;

    return $class->$orig( framesets => \@framesets );

}

has compression_levels_r => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Int]',
    lazy    => 1,
    builder => '_build_compression_levels_r',
    handles => {
        compression_levels        => 'elements',
        highest_compression_level => [ get => -1 ],
    },

);

sub _build_compression_levels_r {
    my $self = shift;

    return sort { $a <=> $b } $self->_unsorted_compression_levels;

    # my %seen_levels;

    # $seen_levels{ $_->compression_level } = 1 foreach $self->framesets;
    # return [ sort { $a <=> $b } keys %seen_levels ];
}

has framesets_of_compression_level_r => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Octium::O::Sked::Timetable::IDFrameSet]]',
    lazy    => 1,
    builder => '_build_framesets_of_compression_level_r',
    handles => {
        _framesets_of_compression_level_r => 'get',
        _unsorted_compression_levels      => 'keys',
    },
);

sub _build_framesets_of_compression_level_r {
    my $self = shift;
    my %framesets_of;
    foreach my $frameset ( $self->framesets ) {
        my $level = $frameset->compression_level;
        push @{ $framesets_of{$level} }, $frameset;
    }
    return \%framesets_of;
}

sub framesets_of_compression_level {
    my $self  = shift;
    my $level = shift;
    return @{ $self->_framesets_of_compression_level_r($level) };
}

has heights_of_compression_level_r => (
    traits  => ['Hash'],
    is      => 'ro',
    isa     => 'HashRef[ArrayRef[Int]]',
    lazy    => 1,
    builder => '_build_heights_of_compression_level_r',
    handles => { _heights_of_compression_level => 'get' },
);

sub _build_heights_of_compression_level_r {
    my $self = shift;
    my %heights_of;

    foreach my $frameset ( $self->framesets ) {
        my $level  = $frameset->compression_level;
        my $height = $frameset->height;
        push @{ $heights_of{$level} }, $height;
    }

    foreach my $level ( keys %heights_of ) {
        my @heights
          = Octium::uniq( sort { $b <=> $a } @{ $heights_of{$level} } );
        $heights_of{$level} = \@heights;
    }

    return \%heights_of;
}

sub heights_of_compression_level {
    my $self  = shift;
    my $level = shift;
    return @{ $self->_heights_of_compression_level($level) };
}

has _smallest_frame_height => (
    is      => 'ro',
    lazy    => 1,
    isa     => 'Int',
    builder => '_build_smallest_frame_height',
);

sub _build_smallest_frame_height {
    my $self = shift;
    my $min;
    foreach my $frameset ( $self->framesets ) {
        if ( defined $min ) {
            $min = Octium::min( $min, $frameset->height );
        }
        else {
            $min = $frameset->height;
        }
    }

    return $min;
}

has maximum_frame_count => (
    is      => 'ro',
    lazy    => 1,
    isa     => 'Int',
    builder => '_build_maximum_frame_count',
);

sub _build_maximum_frame_count {
    my $self = shift;
    my $max  = 0;
    foreach my $frameset ( $self->framesets ) {
        $max = Octium::max( $max, $frameset->frame_count );
    }
    return $max;

}

#has all_frames_r => (
#    traits  => ['Array'],
#    is      => 'bare',
#    isa     => 'ArrayRef[Octium::O::Sked::Timetable::IDFrame]',
#    lazy    => 1,
#    builder => '_build_all_frames_r',
#    handles => { all_frames => 'elements', },
#);
#
#sub _build_all_frames_r {
#    my $self = shift;
#    return map { $_->frames } $self->framesets;
#}

sub make_idtables {

    my $self   = shift;
    my @tables = @_;
    my @idtables;
    my $seen_a_failure;
    my $any_overlong;

  TABLE:
    foreach my $table (@tables) {

        my $table_width  = $table->width_in_halfcols;
        my $table_height = $table->height;
        my $partial_level;

        foreach my $frameset ( $self->framesets ) {
            my $compression_level = $frameset->compression_level;

            # does it fit entirely? if so, push it to the list, and next table
            my $frame_height = $frameset->height;

            foreach my $frame ( $frameset->frames ) {
                my $frame_width = $frame->width;

                if (    $table_height <= $frame_height
                    and $table_width <= $frame_width )
                {
                    push @idtables,
                      $IDTABLE->new(
                        timetable_obj     => $table,
                        compression_level => $compression_level,
                        overlong          => 0,
                      );

                    next TABLE;
                }

                # if not, and we haven't defined a partial level already,
                # save the level

                $partial_level = $compression_level
                  if ( not defined $partial_level
                    and $table_width <= $frame_width );

            }    ## tidy end: foreach my $frame ( $frameset...)

        }    ## tidy end: foreach my $frameset ( $self...)

        if ( defined $partial_level ) {
            # if there's a partial level, save it to the list

            push @idtables,
              $IDTABLE->new(
                timetable_obj     => $table,
                compression_level => $partial_level,
                overlong          => 1
              );
            $any_overlong = 1;
            next TABLE;
        }

        # otherwise, save it as failed

        push @idtables, $IDTABLE->new( timetable_obj => $table, failed => 1 );
        $seen_a_failure = 1;

    }    ## tidy end: TABLE: foreach my $table (@tables)

    return $seen_a_failure, $any_overlong, @idtables;

}    ## tidy end: sub make_idtables

sub minimum_pages {
    my $self     = shift;
    my @idtables = @_;

    my $overlong = 0;
    foreach my $idtable (@idtables) {
        $overlong++ if ( $idtable->overlong );
    }

    return 1 if ( $overlong == 0 );
    # if not overlong, could fit on one page

    my $minimum_frames = Actium::ceil( $overlong * 1.5 );

    # Each overlong table can only be paired with one other overlong table.
    # So it takes at least 1.5 frames per overlong one.

    return Actium::ceil( $minimum_frames / $self->maximum_frame_count );
}

sub assign_page {

    my $self            = shift;
    my @tables          = @{ +shift };
    my $prefer_portrait = shift;

    my @framesets
      = $prefer_portrait
      ? $self->portrait_preferred_framesets
      : $self->framesets;

  FRAMESET:

    foreach my $frameset (@framesets) {

        my $frame_height = $frameset->height;

        my @frames = $frameset->frames;

        next if ( @frames > @tables );
        # If there are more frames than there are tables,
        # this cannot be the best fit

        # will this set of tables fit on this page?

        if ( @frames == 1 ) {
            my ( $height, $width )
              = $IDTABLE->get_stacked_measurements(@tables);
            if (not(    $height <= $frame_height
                    and $width <= $frames[0]->width )
              )

            {
                next;

            }
            return { tables => [ \@tables ], frameset => $frameset };
        }

        if ( @frames == @tables ) {
            for my $i ( 0 .. $#frames ) {
                next FRAMESET
                  if $frame_height < $tables[$i]->height
                  or $frames[$i]->width < $tables[$i]->width_in_halfcols;
                # doesn't fit if frame's height or width aren't big enough
            }
            return {
                tables   => [ map { [$_] } @tables ],
                frameset => $frameset
            };
            # all frames fit
        }

        # more tables than frames. Divide tables up into appropriate sets,
        # and then try them

        my @table_permutations = _sort_table_permutations(
            ordered_partitions( \@tables, scalar @frames ) );

      TABLE_PERMUTATION:
        foreach my $table_permutation (@table_permutations) {

            foreach my $i ( 0 .. $#frames ) {
                my @tables = @{ $table_permutation->[$i] };
                my ( $height, $width )
                  = $IDTABLE->get_stacked_measurements(@tables);
                next TABLE_PERMUTATION
                  if $frame_height < $height
                  or $frames[$i]->width < $width;
                # doesn't fit if frame's height or width aren't big enough
            }

            # it got here, so the tables fit within the frames

            return { tables => $table_permutation, frameset => $frameset };

        }

        # finished all the permutations for this page, but nothing fit

    }    ## tidy end: FRAMESET: foreach my $frameset (@framesets)

    return;
    # finished all the permutations for this page set, but nothing fit

}    ## tidy end: sub assign_page

sub _sort_table_permutations {

    my @partitions_to_sort;

    foreach my $partition_r (@_) {
        my @partition = @{$partition_r};

        my @sort_values = map { scalar @{$_} } @partition;
        # count of tables in each frame

        unshift @sort_values, Octium::population_stdev(@sort_values);
        # standard deviation -- so makes them as close to the same
        # number of tables as possible

        push @partitions_to_sort, [ \@partition, \@sort_values ];

    }

    my @partitions = sort _by_table_permutation_sort @partitions_to_sort;

    return map { $_->[0] } @partitions;

}    ## tidy end: sub _sort_table_permutations

sub _by_table_permutation_sort {
    my @a = @{ $a->[1] };
    my @b = @{ $b->[1] };

    # first, return the comparison of the standard deviations of the
    # count of tables in each frame

    my $result = $a[0] <=> $b[0];
    return $result if $result;

    # If those are the same, go through the remaining values,
    # which are the counts of the tables in each frame.
    # Return the one that's highest first -- so it will
    # prefer [2, 1] over [1, 2]
    for my $i ( 1 .. $#a ) {
        my $result = $b[$i] <=> $a[$i];
        return $result if $result;
    }

    return 0;    # the same...

}    ## tidy end: sub _by_table_permutation_sort

__PACKAGE__->meta->make_immutable;

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

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

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

