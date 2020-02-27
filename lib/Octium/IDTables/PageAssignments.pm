package Octium::IDTables::PageAssignments 0.012;

use 5.016;
use warnings;

use Octium;
use Octium::Crier (qw/cry last_cry/);
use Octium::Text::InDesignTags;
use Octium::Text::CharWidth ( 'ems', 'char_width' );
use Octium::O::Sked;
use Octium::O::Sked::Timetable;
use Octium::O::Sked::Timetable::IDTimetable;
use Octium::O::Sked::Timetable::IDTimetableSet;
use List::Util (qw/max sum/);    ### DEP ###
use List::Compare::Functional(qw/get_intersection/);          ### DEP ###
use Algorithm::Combinatorics(qw/partitions permutations/);    ### DEP ###
use Octium::Set (qw/odometer_combinations ordered_partitions/);

use Octium::O::Sked::Timetable::IDPageFrameSets;

const my $IDT        => 'Octium::Text::InDesignTags';
const my $SOFTRETURN => $IDT->softreturn;

my $shortpage_framesets = Octium::O::Sked::Timetable::IDPageFrameSets->new(
    {   description => 'Landscape full',
        frames      => [ { widthpair => [ 10, 0 ], frame_idx => 0 } ],
        height      => 42,
    },
    {   description => 'Landscape halves',
        frames      => [
            { widthpair => [ 4, 1 ], frame_idx => 0 },
            { widthpair => [ 5, 0 ], frame_idx => 1 },
        ],
        height => 42,
    },
    {   description => 'Portrait full',
        frames      => [ { widthpair => [ 11, 0 ], frame_idx => 2 } ],
        height      => 36,
        is_portrait => 1,
    },
    {   description => 'Portrait halves',
        frames      => [
            { widthpair => [ 5, 1 ], frame_idx => 2 },
            { widthpair => [ 5, 0 ], frame_idx => 3 },
        ],
        is_portrait => 1,
        height      => 36,
    },
);

my $page_framesets = Octium::O::Sked::Timetable::IDPageFrameSets->new(
    {   description       => 'Landscape full',
        compression_level => 0,
        frames            => [ { widthpair => [ 15, 0 ], frame_idx => 0 }, ],
        height            => 42,
    },
    {   description       => 'Landscape halves',
        compression_level => 0,
        frames            => [
            { widthpair => [ 7, 0 ], frame_idx => 0 },
            { widthpair => [ 7, 0 ], frame_idx => 1 },
        ],
        height => 42,
    },
    {   description       => 'Landscape thirds',
        compression_level => 0,
        frames            => [
            { widthpair => [ 4, 1 ], frame_idx => 0 },
            { widthpair => [ 5, 0 ], frame_idx => 2 },
            { widthpair => [ 4, 1 ], frame_idx => 3 },
        ],
        height => 42,
    },
    {   description       => 'Landscape 2/3 - 1/3',
        compression_level => 0,
        frames            => [
            { widthpair => [ 10, 0 ], frame_idx => 0 },
            { widthpair => [ 4,  1 ], frame_idx => 3 },
        ],
        height => 42,
    },
    {   description       => 'Landscape 1/3 - 2/3',
        compression_level => 0,
        frames            => [
            { widthpair => [ 4,  1 ], frame_idx => 0 },
            { widthpair => [ 10, 0 ], frame_idx => 2 },
        ],
        height => 42,
    },

    {   description       => 'Portrait full',
        is_portrait       => 1,
        compression_level => 0,
        frames            => [ { widthpair => [ 11, 0 ], frame_idx => 4 }, ],
        height            => 59,
    },
    {   description       => 'Portrait halves',
        is_portrait       => 1,
        compression_level => 0,
        frames            => [
            { widthpair => [ 5, 1 ], frame_idx => 4 },
            { widthpair => [ 5, 0 ], frame_idx => 5 },
        ],
        height => 59,
    },
    {   description       => 'Landscape full, narrow columns',
        compression_level => 1,
        frames            => [ { widthpair => [ 18, 0 ], frame_idx => 0 } ],
        height            => 40,
    },
    {   description       => 'Landscape full, 18.5 narrower columns',
        compression_level => 2,
        frames            => [ { widthpair => [ 18, 1 ], frame_idx => 0 } ],
        height            => 40,
    },
);
# reduced height by two, in order to allow for two more lines
# of timepoint names.  This is a guess

sub assign {

    my (@tables) = @{ +shift };       # copy
    my $force_no_shortpage = shift;

    my ( $fit_failure, $has_overlong, @idtables )
      = $page_framesets->make_idtables(@tables);

    if ($fit_failure) {
        foreach my $idtable (@idtables) {
            next unless $idtable->failed;

            last_cry()
              ->text( $idtable->id
                  . " could not be fit in the pages available: "
                  . $idtable->dimensions_for_display );

        }

        return;
    }

    # If any timetable is so big that it won't fit on any page,
    # we return, having warned about it.

    my @page_assignments;
    if ( not $has_overlong ) {
        @page_assignments = _assign_pages(@idtables);
    }
    else {
        @page_assignments = _overlong_assign_pages(@idtables);
    }

    return unless @page_assignments;
    # If we went through all the possible page assignments and couldn't
    # find one that works, return nothing

    my $has_shortpage;
    if ($force_no_shortpage) {
        $has_shortpage = 0;
    }
    else {
        ( $has_shortpage, @page_assignments )
          = _reassign_short_page(@page_assignments);
    }

    # @page_assignments is organized by page, but want to return
    # table_assignments, organized by table

    my $portrait_chars
      = _make_portrait_chars( $has_shortpage, @page_assignments );

    return $portrait_chars,
      _make_table_assignments_from_page_assignments( $has_shortpage,
        @page_assignments );

}    ## tidy end: sub assign

sub _make_portrait_chars {
    my $has_shortpage    = shift;
    my @page_assignments = @_;

    shift @page_assignments if $has_shortpage;

    return Octium::joinempty( map { $_->{frameset}->is_portrait ? 'P' : 'L' }
          @page_assignments );

    #my @portrait_chars;
    #foreach my $page_assignment_r (@page_assignments) {
    #    push @portrait_chars,
    #    ($page_assignment_r->{frameset}->is_portrait ? 'P' : 'L');
    #}

    #return j(@portrait_chars);

}

sub _assign_pages {
    my @idtables = @_;

    for my $numpages ( 1 .. @idtables ) {
        my @page_partitions
          = _sort_page_partitions( partitions( \@idtables, $numpages ) );
        my @page_assignments = _make_page_assignments(@page_partitions);
        return @page_assignments if @page_assignments;
    }
    return;

}

sub _overlong_assign_pages {
    my @idtables = @_;

    my @table_sets = Octium::O::Sked::Timetable::IDTimetableSet->new;

    for my $idtable (@idtables) {

        my $endmost_set                     = $table_sets[-1];
        my $number_of_tables_in_endmost_set = $endmost_set->timetable_count;

        if ( $number_of_tables_in_endmost_set < 2
            or not( $idtable->overlong or $endmost_set->overlong ) )
        {

            $endmost_set->add_timetable($idtable);
            # add this one to the set if the set will be less than two tables,
            # or there are no overlongs in this one or in the set

        }
        else {
            # make a new set
            my $set = Octium::O::Sked::Timetable::IDTimetableSet->new;
            $set->add_timetable($idtable);
            push @table_sets, $set;
        }

    }    ## tidy end: for my $idtable (@idtables)

    my @page_assignments;
    foreach my $table_set (@table_sets) {
        my @timetables = $table_set->timetables;

        if ( $table_set->overlong ) {
            push @page_assignments, _overlong_set_assign_pages(@timetables);

        }
        else {
            push @page_assignments, _assign_pages(@timetables);
        }

    }

    return @page_assignments;

}    ## tidy end: sub _overlong_assign_pages

sub _overlong_set_assign_pages {

    my @idtables = @_;

    my @expanded_table_sets;

    # @table_expansions =
    # [ # first table
    #   [ Table1_0-19  Table1_20-34 ], # if height is 20 - remainder at end
    #   [ Table1_0-14  Table1_15-34 ], # if height is 20 - remainder at start
    # ] ,
    # [ # second table
    #   [ Table2 ]   # not overlong
    # ]

    # @expanded_table_sets =
    # [ # first combination
    #   [ Table1_0-19 Table1_20-34 ], [ Table2 ], # Table1 remainder at end
    # ],
    # [ # second combination
    #   [ Table1_0-14 Table1_15_34 ], [ Table2 ], # Table1 remainder at start
    # ]

    my @table_expansions;

    foreach my $table (@idtables) {
        if ( not $table->overlong ) {
            push @table_expansions, [ [$table] ];
        }
        else {
            my @heights = $page_framesets->heights_of_compression_level(
                $table->compression_level );

            push @table_expansions, $table->expand_overlong(@heights);

        }

    }

    push @expanded_table_sets, odometer_combinations(@table_expansions);

    my @page_partitions;

    foreach my $table_set (@expanded_table_sets) {
        my @tables           = Octium::flatten($table_set);
        my @these_partitions = ordered_partitions( \@tables );
        push @page_partitions, @these_partitions;
    }

    #    if (@page_partitions) {
    @page_partitions = _sort_page_partitions(@page_partitions);
    my @page_assignments = _make_page_assignments(@page_partitions);
    return @page_assignments if @page_assignments;
    #    }

    #    $pages++;

    #} ## tidy end: while ($all_pages_le_tables)

    return;

}    ## tidy end: sub _overlong_set_assign_pages

sub _count_full_frame_idtables {
    my $full_frame = 0;
    foreach my $idtable ( ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_ ) {
        $full_frame++ if $idtable->full_frame;
    }

    return $full_frame;
}

sub _sort_page_partitions {

#####

    # So the set of tables first needs to be divided up into pages,
    # and then needs to be divided up into frames within those pages.
    # Page(s) contains Frame(s) contains Table(s)

    # Then, the pages need to be examined, and if any of them can fit as a
    # short page, make that first page a short page.
    # (Short pages are the pages with the covers on them.)

    # First, we get all the possible sets of timetables on each page.

    # @page_partitions consists of all the valid ways of
    # breaking up the various tables into valid pages,
    # in order of preference.

    # A simple example might be:
    #   @page_partitions =
    #   [ [ Table 1, Table 2, Table 3, Table 4 ] ] ,     # all on one page
    #   [ [ Table 1, Table 2] , [ Table 3, Table 4 ] ],  # Two pages
    #   [ [ Table 1, Table 3] , [ Table 2, Table 4 ] ],  # Two other pages
    #   [ [Table 1], [Table 2], [Table 3], [Table 4] ]   # Each on its own page

    my @partitions_to_sort = @_;

    my @page_partitions;

    foreach my $partition (@partitions_to_sort) {

        my %partitions_with_values = (
            partition        => $partition,
            num_pages        => ( scalar @{$partition} ),
            pointsforsorting => 0,
        );

        my @tablecounts;

      PAGE:
        foreach my $page ( @{$partition} ) {

            my $numtables = scalar( @{$page} );
            push @tablecounts, $numtables;

            my ( @ids, @lines, @all_lines, @dircodes, @daycodes );

            foreach my $table ( @{$page} ) {
                push @ids, $table->id;

                my @lines_of_this_table = $table->lines;
                push @lines,     \@lines_of_this_table;
                push @all_lines, Octium::joinkey(@lines_of_this_table);

                push @dircodes, $table->dircode;
                push @daycodes, $table->daycode;

            }

            if ( Octium::all_eq(@ids) ) {
                $partitions_with_values{pointsforsorting} += 11;
                next PAGE;
                # one ID; maximum value (8+2+1)
            }

            my $pagepoints = 0;

            my $all_eq_lines = Octium::all_eq(@all_lines);

            if ($all_eq_lines) {
                $pagepoints += 8;

                # should this be 12, since if all lines are equal,
                # one line must be in common?
                # whatever, distinction without difference
            }
            else {
                $pagepoints += 4 if _one_line_in_common(@lines);
            }
            $pagepoints += 2 if Octium::all_eq(@daycodes);
            $pagepoints += 1 if Octium::all_eq(@dircodes);

            $partitions_with_values{pointsforsorting} += $pagepoints;

        }    ## tidy end: PAGE: foreach my $page ( @{$partition...})

        $partitions_with_values{deviation}
          = Octium::population_stdev(@tablecounts);

        push @page_partitions, \%partitions_with_values;

    }    ## tidy end: foreach my $partition (@partitions_to_sort)

    @page_partitions = sort _page_partition_sort @page_partitions;

    @page_partitions = map { $_->{partition} } @page_partitions;
    # drop sort_values from partition;

    return @page_partitions;

}    ## tidy end: sub _sort_page_partitions

sub _page_partition_sort {

    return
         $a->{num_pages} <=> $b->{num_pages}
      || $a->{deviation} <=> $b->{deviation}
      || $b->{pointsforsorting} <=> $a->{pointsforsorting};

}

sub _one_line_in_common {
    my @lol = @_;

    # if only one element, dereference it.
    # No point in passing only one element to this list
    if ( @lol == 1 ) {
        @lol = @{ $lol[0] };
    }

    my @first_elements = @{ shift @lol };
    my $match          = 0;

  ELEMENT:
    foreach my $element (@first_elements) {
        foreach my $list_r (@lol) {
            next ELEMENT unless Octium::in( $element, $list_r );
        }
        return 1;    # matches all elements
    }

    return;

}    ## tidy end: sub _one_line_in_common

sub _make_page_assignments {

    my @page_partitions = @_;

    my @page_assignments;

    my $prefer_portrait = 0;

    # go through each possible page assignment
    # For this page assignment, does each possible page fit on
    # one of the framesets?
    # If all pages fit, use it! if not, go to the next page set

  POSSIBLE_PAGE_ASSIGNMENT:
    foreach my $page_permutation_r (@page_partitions) {

        # so now we have a single grouping of tables into one or more pages.
        # For example,
        # @page_permutation_r = ([ Table 1, Table 2] , [Table 3 , Table 4])
        # But this page assignment may not fit. For each page, check to
        # see if it fits.

      PAGE:
        foreach my $tables_on_this_page_r ( @{$page_permutation_r} ) {

            # And now we have a single page:
            # $tables_on_this_page_r = [ Table 1, Table 2 ]

            # Now we check to see whether this page fits!

            my $page_assignment_r
              = $page_framesets->assign_page( $tables_on_this_page_r,
                $prefer_portrait );

            # $page_assignment_r->{tables} = [ [ Table 1, Table 2] ,[Table 3] ]
            # $page_assignment_r->{frameset} = frameset object

            if ( not defined $page_assignment_r ) {
                # This page does not fit any frameset, so we have to give up
                # on this possible page assignment and try the next one

                @page_assignments = ();    # reset assignments
                $prefer_portrait  = 0;     # reset portrait preference
                next POSSIBLE_PAGE_ASSIGNMENT;

            }

            # It did fit a frame assignment, so save it
            push @page_assignments, $page_assignment_r;
            $prefer_portrait = $page_assignment_r->{frameset}->is_portrait;

        }    ## tidy end: PAGE: foreach my $tables_on_this_page_r...

        last if @page_assignments;

    }   ## tidy end: POSSIBLE_PAGE_ASSIGNMENT: foreach my $page_permutation_r...

    _slide_up_multiframe_tables(@page_assignments)
      if @page_assignments;

    return @page_assignments;

}    ## tidy end: sub _make_page_assignments

sub _slide_up_multiframe_tables {

    # for the last table of each frame, if this table extends to the
    # following frame, move as many lines as possible up from the
    # following frame to this frame

    my @page_assignments = @_;

    my @data_of_frame;

    for my $page_assignment_r (@page_assignments) {
        my $height = $page_assignment_r->{frameset}->height;
        foreach my $tables_of_frame_r ( @{ $page_assignment_r->{tables} } ) {
            my ( $table_height, $table_width )
              = Octium::O::Sked::Timetable::IDTimetable
              ->get_stacked_measurements( @{$tables_of_frame_r} );

            push @data_of_frame,
              { frame_height  => $height,
                first_table   => $tables_of_frame_r->[0],
                final_table   => $tables_of_frame_r->[-1],
                tables_height => $table_height,
              };

        }
    }

    for my $i ( 1 .. $#data_of_frame ) {

        my $follower       = $data_of_frame[$i];
        my $follower_table = $follower->{first_table};
        my $leader         = $data_of_frame[ $i - 1 ];
        my $leader_table   = $leader->{final_table};

        next unless $follower_table->id eq $leader_table->id;
        next
          if $leader->{tables_height} == $leader->{frame_height};    # no room
            # not the same table, so can't move individual items

        my $rows_to_move = $leader->{frame_height} - $leader->{tables_height};
        $leader_table->set_upper_bound(
            $leader_table->upper_bound + $rows_to_move );
        $follower_table->set_lower_bound(
            $follower_table->lower_bound + $rows_to_move );

    }

    return @page_assignments;

}    ## tidy end: sub _slide_up_multiframe_tables

sub _reassign_short_page {

    my @page_assignments = @_;

    ###
    # Replace assigned frameset with a short frameset if it fits

    # Check the first page, then the last page,
    # only then any intermediate pages

    my @page_order = ( 0 .. $#page_assignments );
    if ( @page_order > 2 ) {
        my $final = pop @page_order;
        splice( @page_order, 1, 0, $final );
    }

    #my $has_shortpage = 0;

  FRAMESET_TO_REPLACE:
    for my $page_idx (@page_order) {
        my $page_assignment_r = $page_assignments[$page_idx];
        my $tables_r          = Octium::flatten( $page_assignment_r->{tables} );
        #my $frameset          = $page_assignment_r->{frameset};

        # don't move part of a overlong table to the short page,
        # unless this is either the first or last page
        if ( $page_idx != 0 and $page_idx != $#page_assignments ) {
            foreach my $table (@$tables_r) {
                next FRAMESET_TO_REPLACE
                  if $table->overlong;
            }
        }

        my $prefer_portrait = $page_assignment_r->{frameset}->is_portrait;

        my $short_page_assignment
          = $shortpage_framesets->assign_page( $tables_r, $prefer_portrait );

        if ( defined $short_page_assignment ) {
            splice( @page_assignments, $page_idx, 1 );
            unshift @page_assignments, $short_page_assignment;
            #$has_shortpage = 1;
            return 1, @page_assignments;
            #last FRAMESET_TO_REPLACE;
        }
    }    ## tidy end: FRAMESET_TO_REPLACE: for my $page_idx (@page_order)

    #return $has_shortpage, @page_assignments;
    return 0, @page_assignments;

}    ## tidy end: sub _reassign_short_page

sub _make_table_assignments_from_page_assignments {

    my $has_shortpage    = shift;
    my @page_assignments = @_;

    my @table_assignments;

    my $pagebreak = not($has_shortpage);
    # initial break for blank shortpage only

    for my $page_assignment_r (@page_assignments) {

        my @tables_of_frames_of_page = @{ $page_assignment_r->{tables} };
        my $frameset                 = $page_assignment_r->{frameset};
        my $compression_level        = $frameset->compression_level;
        my @frames                   = $frameset->frames;

        for my $frame_of_frameset_idx ( 0 .. $#frames ) {
            my $frame = $frames[$frame_of_frameset_idx];
            my @tables_of_frame
              = @{ $tables_of_frames_of_page[$frame_of_frameset_idx] };

            my $widthpair = $frame->widthpair_r;
            my $frame_idx = $frame->frame_idx;

            foreach my $table (@tables_of_frame) {
                push @table_assignments,
                  { table       => $table,
                    width       => $widthpair,
                    frame       => $frame_idx,
                    pagebreak   => $pagebreak,
                    compression => $compression_level,
                  };
                $pagebreak = 0;
                # no pagebreak after tables, except at end of page
            }

        }    ## tidy end: for my $frame_of_frameset_idx...

        $pagebreak = 1;    # end of page

    }    ## tidy end: for my $page_assignment_r...

    return @table_assignments;

}    ## tidy end: sub _make_table_assignments_from_page_assignments

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

