# Actium/IDTables/PageAssignments.pm

# Produces the page assignments for the timetables

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.012;

package Actium::IDTables::PageAssignments 0.001;

use English '-no_match_vars';
use autodie;
use Text::Trim;
use Actium::Constants;
use Actium::Text::InDesignTags;
use Actium::Text::CharWidth ( 'ems', 'char_width' );
use Actium::O::Folders::Signup;
use Actium::Term;
use Actium::O::Sked;
use Actium::O::Sked::Timetable;
use Actium::Util qw/doe in chunks flatten population_stdev jk all_eq halves/;
use Const::Fast;
use List::Util (qw/max sum/);
use Algorithm::Combinatorics;

const my $IDT        => 'Actium::Text::InDesignTags';
const my $SOFTRETURN => $IDT->softreturn;

my $shortpage_framesets = Actium::O::Sked::Timetable::IDPageFrameSets->new(
    [   description => 'Landscape full',
        frames => [ { widthpair => [ 10, 0 ], height => 42, frame_idx => 0 } ],
    ],
    [   description => 'Landscape halves',
        frames      => [
            { widthpair => [ 4, 1 ], height => 42, frame_idx => 0 },
            { widthpair => [ 5, 0 ], height => 42, frame_idx => 2 },
        ],
    ],
    [   description => 'Portrait full',
        frames => [ { widthpair => [ 11, 0 ], height => 36, frame_idx => 4 } ],
    ],
    [   description => 'Portrait halves',
        frames      => [
            { widthpair => [ 5, 1 ], height => 36, frame_idx => 4 },
            { widthpair => [ 5, 0 ], height => 36, frame_idx => 5 },
        ]
    ],
);

my $page_framesets = Actium::O::Sked::Timetable::IDPageFrameSets->new(
    [   description       => 'Landscape full',
        compression_level => 0,
        frames => [ { widthpair => [ 15, 0 ], height => 42, frame_idx => 0 }, ]
    ],
    [   description       => 'Landscape halves',
        compression_level => 0,
        frames            => [
            { widthpair => [ 7, 0 ], height => 42, frame_idx => 0 },
            { widthpair => [ 7, 0 ], height => 42, frame_idx => 1 },
        ]
    ],
    [   description       => 'Landscape thirds',
        compression_level => 0,
        frames            => [
            { widthpair => [ 4, 1 ], height => 42, frame_idx => 0 },
            { widthpair => [ 5, 0 ], height => 42, frame_idx => 2 },
            { widthpair => [ 4, 1 ], height => 42, frame_idx => 3 },
        ]
    ],
    [   description       => 'Landscape 2/3 - 1/3',
        compression_level => 0,
        frames            => [
            { widthpair => [ 10, 0 ], height => 42, frame_idx => 0 },
            { widthpair => [ 4,  1 ], height => 42, frame_idx => 3 },
        ]
    ],
    [   description       => 'Landscape 1/3 - 2/3',
        compression_level => 0,
        frames            => [
            { widthpair => [ 4,  1 ], height => 42, frame_idx => 0 },
            { widthpair => [ 10, 0 ], height => 42, frame_idx => 2 },
        ]
    ],

    [   description       => 'Portrait full',
        compression_level => 0,
        frames => [ { widthpair => [ 11, 0 ], height => 59, frame_idx => 4 }, ]
    ],
    [   description       => 'Portrait halves',
        compression_level => 0,
        frames            => [
            { widthpair => [ 5, 1 ], height => 59, frame_idx => 4 },
            { widthpair => [ 5, 0 ], height => 59, frame_idx => 5 },
        ]
    ],
    [   description       => 'Landscape full, narrow columns',
        compression_level => 1,
        frames => [ { widthpair => [ 18, 0 ], height => 40, frame_idx => 0 } ],
    ],
);
# reduced height by two, in order to allow for two more lines
# of timepoint names.  This is a guess

sub assign {

    my (@tables) = @{ +shift };    # copy

    return unless _every_table_fits_on_a_page(@tables);

    # If any timetable is so big that it won't fit on any page,
    # we return, having warned about it.

    my @page_assignments = _make_page_assignments(@tables);
    return unless @page_assignments;
    # If we went through all the possible page assignments and couldn't
    # find one that works, return nothing

    my $has_shortpage;
    ( $has_shortpage, @page_assignments )
      = _reassign_short_page(@page_assignments);

    # @page_assignments is organized by page, but want to return
    # table_assignments, organized by table

    return _make_table_assignments_from_page_assignments( $has_shortpage,
        @page_assignments );

} ## tidy end: sub assign

sub every_table_fits_on_a_page {
    my @tables = @_;

    foreach my $table (@tables) {
        my $width = $table->width_in_halfcols;
        if ( $page_framesets->no_frame_is_wide_enough($width) ) {
            my $displaywidth = sprintf( '%.1f', $width / 2 );
            emit_text $table->id
              . " does not fit on a single page: $displaywidth columns";

            return;
        }
    }

    return 1;

}

sub _make_page_assignments {

    my @tables = @_;
    my @tables_with_overage;

  TABLE:
    foreach my $table (@tables) {
        my $table_width  = $table->width_in_halfcols;
        my $table_height = $table->height;

        my $level = $page_framesets->level_that_fits_whole_table(
            height => $table_height,
            width  => $table_width
        );

        if ( defined $level ) {
            push @tables_with_overage,
              { table            => $table,
                compressed_level => $level,
                multipage        => 0,
              };
            next TABLE;
        }

        # so now we know it's too tall

        $level = $page_framesets->level_that_fits_partial_table($table_width);

        if ( not defined $level ) {
            emit_text q{Couldn't find even a partial table that fit }
              . $table->id;

            push @tables_with_overage,
              { table            => $table,
                compressed_level => $level,
                multipage        => 1,
              };

        }

    }
    
    
    
    #### TODO
    
    #### Here is where I need to figure out how to break up the multipage
    # tables into partial tables, so they can be assigned separately.

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

    # At this point _partition_tables_into_pages returns *every* possible
    # partition in *every* order, but is sorted into most likely order for use.

    my @page_partitions = _partition_tables_into_pages(@tables);

    # So now we know every possible way the tables can be divided into pages.

    my @page_assignments;

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

            my $page_assignment_r = _assign_page(
                {   tables    => $tables_on_this_page_r,
                    framesets => \@page_framesets
                }
            );

            # $page_assignment_r->{tables} = [ [ Table 1, Table 2] ,[Table 3] ]
            # $page_assignment_r->{frameset} = [ Frame 1, Frame 2]

            if ( not defined $page_assignment_r ) {
                # This page does not fit any frameset, so we have to give up
                # on this possible page assignment and try the next one

                @page_assignments = ();    # reset assignments
                next POSSIBLE_PAGE_ASSIGNMENT;

            }

            # It did fit a frame assignment, so save it
            push @page_assignments, $page_assignment_r;

        } ## tidy end: PAGE: foreach my $tables_on_this_page_r...

        last if @page_assignments;

    } ## tidy end: POSSIBLE_PAGE_ASSIGNMENT: foreach my $page_permutation_r...

    return @page_assignments;

} ## tidy end: sub _make_page_assignments

sub _assign_page {

    my $args_r                = shift;
    my $tables_on_this_page_r = $args_r->{tables};
    my @framesets             = @{ $args_r->{framesets} };

    foreach my $frameset (@framesets) {

        my $tables_in_each_frame_r
          = _assign_tables_to_frames( $frameset, $tables_on_this_page_r );

        next unless $tables_in_each_frame_r;
        my $page_assignment_r = {
            tables   => $tables_in_each_frame_r,
            frameset => $frameset
        };

        return $page_assignment_r;

    }

    return;

} ## tidy end: sub _assign_page

# if it got here, it successfully placed all tables
# on all pages!

sub _assign_tables_to_frames {

    my @frames = @{ +shift };
    my @tables = @{ +shift };

    return if ( @frames > @tables );
    # If there are more frames than there are tables,
    # this cannot be the best fit

    # will this set of tables fit on this page?

    if ( @frames == 1 ) {
        my ( $height, $width ) = _get_stacked_measurement(@tables);
        if (not(    $height <= $frames[0]{height}
                and $width <= $frames[0]{width} )
          )

        {
            return;

        }
        return [ \@tables ];
    }

    if ( @frames == @tables ) {
        for my $i ( 0 .. $#frames ) {
            return
              if $frames[$i]{height} < $tables[$i]->height
              or $frames[$i]{width} < $tables[$i]->width_in_halfcols;
            # doesn't fit if frame's height or width aren't big enough
        }
        return [ map { [$_] } @tables ];
        # all frames fit
    }

    # more tables than frames. Divide tables up into appropriate sets,
    # and then try them

    my @table_permutations = _table_permutations( ( scalar @frames ), @tables );

  TABLE_PERMUTATION:
    foreach my $table_permutation (@table_permutations) {

        foreach my $i ( 0 .. $#frames ) {
            my @tables = @{ $table_permutation->[$i] };
            my ( $height, $width ) = _get_stacked_measurement(@tables);
            next TABLE_PERMUTATION
              if $frames[$i]{height} < $height
              or $frames[$i]{width} < $width;
            # doesn't fit if frame's height or width aren't big enough
        }

        # it got here, so the tables fit within the frames

        return $table_permutation;

    }

    return;
    # finished all the permutations, but nothing fit everything

} ## tidy end: sub _assign_tables_to_frames

sub _table_permutations {

    # The idea here is that permutations are identified by a combination
    # of numbers representing the breaks between items.

    # So if you have items qw<a b c d e> then the possible breaks are
    # after a, after b, after c, or after d --
    # numbered 0, 1, 2 and 3.

    # If you have two frames, then you have one break between them.
    # If you have three frames, then you have two breaks between them.

    # This gets all the combinations of breaks between them and
    # then creates the subsets that correspond to those breaks,
    # and returns the subsets. So, if you have two frames, the results are
    # [ a] [ b c d e] , [ a b ] [ c d e] , [a b c] [ d e ], [a b c d] [e].

    # These sorted by which one we'd want to use first
    # (primarily, which combination yields even results, and then
    # if it can't be even, having the extra one at the front rather than
    # at the back or the middle)

    # This differs from
    # Algorithm::Combinatorics::partitions(\@tables, $num_frames)
    # only that it preserves the order. partitions could return
    # [ b] [ a c d e]
    # but this routine will never do that.
    # I am not sure whether this is actually good or not.  Wouldn't
    # it be weird to have a big NX1 table followed by small NX and NX2 tables?
    # If not, then this could be replaced with partitions, as above.

    my $num_frames = shift;
    my @tables     = @_;

    my @indices = ( 0 .. $#tables - 1 );
    my @break_after_idx_sets
      = Algorithm::Combinatorics::combinations( \@indices, $num_frames - 1 );

    my @table_permutations;

    foreach my $break_after_idx_set (@break_after_idx_sets) {
        my @permutation;
        my @break_after_idx = @$break_after_idx_set;

        push @permutation, [ @tables[ 0 .. $break_after_idx[0] ] ];

        for my $i ( 1 .. $#break_after_idx ) {
            my $first = $break_after_idx[ $i - 1 ] + 1;
            my $last  = $break_after_idx[$i];
            push @permutation, [ @tables[ $first .. $last ] ];
        }

        push @permutation, [ @tables[ 1 + $break_after_idx[-1] .. $#tables ] ];

        #push @table_permutations, \@permutation;

        my @sort_values = map { scalar @{$_} } @permutation;
        # count of tables in each frame

        unshift @sort_values, population_stdev(@sort_values);
        # standard deviation -- so makes them as close to the same
        # number of tables as possible

        push @table_permutations, [ \@permutation, \@sort_values ];

    } ## tidy end: foreach my $break_after_idx_set...

    @table_permutations = sort _table_permutation_sort @table_permutations;

    return map { $_->[0] } @table_permutations;

} ## tidy end: sub _table_permutations

sub _table_permutation_sort {

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

} ## tidy end: sub _table_permutation_sort

sub _partition_tables_into_pages {
    # This creates the sets of tables that could possibly fit across pages

    my @all_tables = @_;

    my @page_partitions;

    foreach
      my $partition ( Algorithm::Combinatorics::partitions( \@all_tables ) )
    {

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

            if ( $numtables == 1 ) {
                $partitions_with_values{pointsforsorting} = 15;
                # one table: maximum value
                next PAGE;
            }

            my $pagepoints = 0;

            my ( @lines, @all_lines, @dircodes, @daycodes );

            foreach my $table ( @{$page} ) {
                my @lines_of_this_table = $table->lines;
                push @lines,     \@lines_of_this_table;
                push @all_lines, jk(@lines_of_this_table);

                push @dircodes, $table->dircode;
                push @daycodes, $table->daycode;

            }

            my $all_eq_lines = all_eq(@all_lines);

            if ($all_eq_lines) {
                $pagepoints += 8;

                # should this be 12, since if all lines are equal,
                # one line must be in common?
                # whatever, distinction without difference
            }
            else {
                $pagepoints += 4 if _one_line_in_common(@lines);
            }
            $pagepoints += 2 if all_eq(@daycodes);
            $pagepoints += 1 if all_eq(@dircodes);

            $partitions_with_values{pointsforsorting} += $pagepoints;

        } ## tidy end: PAGE: foreach my $page ( @{$partition...})

        $partitions_with_values{deviation} = population_stdev(@tablecounts);

        push @page_partitions, \%partitions_with_values;

    } ## tidy end: foreach my $partition ( Algorithm::Combinatorics::partitions...)

    @page_partitions = sort _page_partition_sort @page_partitions;

    @page_partitions = map { $_->{partition} } @page_partitions;
    # drop sort_values from partition;

    return @page_partitions;

} ## tidy end: sub _partition_tables_into_pages

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
            next ELEMENT unless in( $element, $list_r );
        }
        return 1;    # matches all elements
    }

    return;

} ## tidy end: sub _one_line_in_common

{

    const my $EXTRA_TABLE_HEIGHT => 9;
  # add 9 for each additional table in a stack -- 1 for blank line,
  # 4 for timepoints and 4 for the color bar. This is inexact and can mess up...
  # not sure how to fix it at this point, I'd need to measure the headers

    sub _get_stacked_measurement {
        my @tables = @_;

        my @widths  = map { $_->width_in_halfcols } @tables;
        my @heights = map { $_->height } @tables;

        my $maxwidth = max(@widths);
        my $sumheight = sum(@heights) + ( $EXTRA_TABLE_HEIGHT * $#heights );

        return ( $sumheight, $maxwidth );

    }

}

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

    my $has_shortpage = 0;

    # First add blank short page

  FRAMESET_TO_REPLACE:
    for my $page_idx (@page_order) {
        my $page_assignment_r = $page_assignments[$page_idx];
        my $tables_r          = flatten( $page_assignment_r->{tables} );
        my $frameset          = $page_assignment_r->{frameset};

        my $short_page_assignment = _assign_page(
            { tables => $tables_r, framesets => \@shortpage_framesets } );

        if ( defined $short_page_assignment ) {
            splice( @page_assignments, $page_idx, 1 );
            unshift @page_assignments, $short_page_assignment;
            $has_shortpage = 1;
            last FRAMESET_TO_REPLACE;
        }
    }

    return $has_shortpage, @page_assignments;

} ## tidy end: sub _reassign_short_page

sub _make_table_assignments_from_page_assignments {

    my $has_shortpage    = shift;
    my @page_assignments = @_;

    my @table_assignments;

    my $pagebreak = not($has_shortpage);
    # initial break for blank shortpage only

    for my $page_assignment_r (@page_assignments) {

        my @tables_of_frames_of_page = @{ $page_assignment_r->{tables} };
        my @frameset                 = @{ $page_assignment_r->{frameset} };

        for my $frame_idx ( 0 .. $#frameset ) {
            my $frame           = $frameset[$frame_idx];
            my @tables_of_frame = @{ $tables_of_frames_of_page[$frame_idx] };

            my $widthpair = $frame->{widthpair};
            my $frame_idx = $frame->{frame_idx};

            foreach my $table (@tables_of_frame) {
                push @table_assignments,
                  { table     => $table,
                    width     => $widthpair,
                    frame     => $frame_idx,
                    pagebreak => $pagebreak,
                  };
                $pagebreak = 0;
                # no pagebreak after tables, except at end of page
            }

        }

        $pagebreak = 1;    # end of page

    } ## tidy end: for my $page_assignment_r...

    return @table_assignments;

} ## tidy end: sub _make_table_assignments_from_page_assignments

1;

__END__

{
    my %maximum_table_dimensions = (
        widest     => { width => _width_in_halfcols( 15, 0 ), height => 42 },
        tallest    => { width => _width_in_halfcols( 11, 0 ), height => 59 },
        compressed => { width => _width_in_halfcols( 18, 0 ), height => 40 },
    );

    my $widest_width = $maximum_table_dimensions{widest}{width};

    sub _is_each_table_oversize {
        my @tables = @_;
        my @oversize;

      TABLE:
        foreach my $table (@tables) {
            my ( $height, $width )
              = ( $table->height, $table->width_in_halfcols );

            if ( $maximum_table_dimensions{compressed}{width} < $width ) {

                emit_text $table->id
                  . " does not fit on a single page: $width x $height";
                return;    # no value - indicates no valid page assignments
            }

            for my $dimensiontype ( keys %maximum_table_dimensions ) {

                my $maximum = $maximum_table_dimensions{$dimensiontype};
                if (    $maximum->{width} >= $width
                    and $maximum->{height} >= $height )
                {
                    # fits!
                    push @oversize,
                      $dimensiontype eq 'compressed' ? 'wide' : $EMPTY_STR;
                    next TABLE;
                }
            }

            # so we know it must be tall

            push @oversize, $width <= $widest_width ? 'tall' : 'both';

        } ## tidy end: TABLE: foreach my $table (@tables)

        return @oversize;

    } ## tidy end: sub _is_each_table_oversize

    my @maximum_table_dimensions = (
        { width => _width_in_halfcols( 15, 0 ), height => 42 },
        { width => _width_in_halfcols( 11, 0 ), height => 59 }
    );

    sub _old_every_table_fits_on_a_page {
        my @tables = @_;

        foreach my $table (@tables) {
            my ( $height, $width )
              = ( $table->height, $table->width_in_halfcols );

            my $fits_on_a_page;
            for my $maximum (@maximum_table_dimensions) {
                if (    $maximum->{width} >= $width
                    and $maximum->{height} >= $height )
                {
                    $fits_on_a_page = 1;
                    last;
                }
            }
            if ( not $fits_on_a_page ) {
                emit_text $table->id
                  . " does not fit on a single page: $width x $height";

                return;
            }

        } ## tidy end: foreach my $table (@tables)

        return 1;

    } ## tidy end: sub _every_table_fits_on_a_page
}

1;
