# Actium/IDTables/PageAssignments.pm

# Produces the page assignments for the timetables

# Subversion: $Id$

# legacy status: 4

package Actium::IDTables::PageAssignments 0.001;

use 5.016;
use warnings;

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
use Actium::O::Sked::Timetable::IDTimetable;
use Actium::Util qw/doe in chunks flatten population_stdev jk all_eq halves/;
use Const::Fast;
use List::Util (qw/max sum/);
use Algorithm::Combinatorics;
use Actium::Combinatorics ('odometer_combinations');

use Actium::O::Sked::Timetable::IDPageFrameSets;

const my $IDT        => 'Actium::Text::InDesignTags';
const my $SOFTRETURN => $IDT->softreturn;

my $shortpage_framesets = Actium::O::Sked::Timetable::IDPageFrameSets->new(
    {   description => 'Landscape full',
        frames      => [ { widthpair => [ 10, 0 ], frame_idx => 0 } ],
        height      => 42,
    },
    {   description => 'Landscape halves',
        frames      => [
            { widthpair => [ 4, 1 ], frame_idx => 0 },
            { widthpair => [ 5, 0 ], frame_idx => 2 },
        ],
        height => 42,
    },
    {   description => 'Portrait full',
        frames      => [ { widthpair => [ 11, 0 ], frame_idx => 4 } ],
        height      => 36,
    },
    {   description => 'Portrait halves',
        frames      => [
            { widthpair => [ 5, 1 ], frame_idx => 4 },
            { widthpair => [ 5, 0 ], frame_idx => 5 },
        ],
        height => 36,
    },
);

my $page_framesets = Actium::O::Sked::Timetable::IDPageFrameSets->new(
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
        compression_level => 0,
        frames            => [ { widthpair => [ 11, 0 ], frame_idx => 4 }, ],
        height            => 59,
    },
    {   description       => 'Portrait halves',
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
);
# reduced height by two, in order to allow for two more lines
# of timepoint names.  This is a guess

sub assign {

    my (@tables) = @{ +shift };    # copy
    my ( $fit_failure, $has_multipage, @idtables )
      = $page_framesets->make_idtables(@tables);

    if ($fit_failure) {
        foreach my $idtable (@idtables) {
            next unless $idtable->failure;

            emit_text $idtable->id
              . " could not be fit in the pages available: "
              . $idtable->dimensions_for_display;

        }

        return;
    }

    # If any timetable is so big that it won't fit on any page,
    # we return, having warned about it.

    my @partitions_to_test;
    my $heights_of_level_r = $page_framesets->heights_of_compression_level_r;

    if ($has_multipage) {
        my @table_expansions;
        foreach my $table (@idtables) {
            if ( not $table->multipage ) {
                push @table_expansions, [ [$table] ];
            }
            else {
                my @heights
                  = @{ $heights_of_level_r->{ $table->compression_level } };
                push @table_expansions, $table->expand_multipage(@heights);
            }

        }

       # @table_expansions =
       # [ # first table
       #   [ Table1_0-19  Table1_20-34 ], # if height is 20 - remainder at end
       #   [ Table1_0-14  Table1_15-34 ], # if height is 20 - remainder at start
       # ] ,
       # [ # second table
       #   [ Table2 ]   # not multipage
       # ]

        my @combinations = odometer_combinations(@table_expansions);

        foreach my $combination_of_tables (@combinations) {

            my $iter
              = Algoritm::Combinatorics::partitions($combination_of_tables);
          PARTITION:
            while ( my $partition = $iter->next ) {

                my @tables = flatten($partition);
                my $prev_id;
                my $prev_order;
              TABLE:
                foreach my $table (@tables) {
                    my $page_order = $table->page_order;
                    my $id         = $table->id;

                    if ( not $table->multipage or $page_order == 0 ) {
                        $prev_id    = $id;
                        $prev_order = $page_order;
                        next TABLE;
                        # not multipage, or beginning of an order
                    }

                    next PARTITION
                      if ( $id ne $prev_id
                        or $page_order != ( $prev_order - 1 ) );
                    # out of order

                    $prev_id    = $id;
                    $prev_order = $page_order;
                    # in order

                } ## tidy end: TABLE: foreach my $table (@tables)

                push @partitions_to_test, $partition;
            } ## tidy end: PARTITION: while ( my $partition = $iter...)

        } ## tidy end: foreach my $combination_of_tables...

    } ## tidy end: if ($has_multipage)
    else {

        @partitions_to_test
          = Algorithm::Combinatorics::partitions( \@idtables );

    }

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

    my @page_partitions;

    foreach my $partition (@partitions_to_test) {

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

    } ## tidy end: foreach my $partition (@partitions_to_test)

    @page_partitions = sort _page_partition_sort @page_partitions;

    @page_partitions = map { $_->{partition} } @page_partitions;
    # drop sort_values from partition;

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
                    framesets => $page_framesets
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
        #my $frameset          = $page_assignment_r->{frameset};

        my $short_page_assignment = 
         $shortpage_framesets->assign_page(@{$tables_r});

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
        my $frameset                 = $page_assignment_r->{frameset} ;
        my @frames = $frameset->frames;

        for my $frame_idx ( 0 .. $#frames ) {
            my $frame           = $frames[$frame_idx];
            my @tables_of_frame = @{ $tables_of_frames_of_page[$frame_idx] };

            my $widthpair = $frame->widthpair_r;
            my $frame_idx = $frame->frame_idx;

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


__END__

