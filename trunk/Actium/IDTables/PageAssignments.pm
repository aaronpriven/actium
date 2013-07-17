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
use Actium::Util(qw/doe in chunks flatten population_stdev/);
use Const::Fast;
use List::Util ( 'max', 'sum' );
use Algorithm::Combinatorics ('combinations');

const my $IDT        => 'Actium::Text::InDesignTags';
const my $SOFTRETURN => $IDT->softreturn;

my @orientation = ( "landscape" x 4, "portrait" x 2 );
# so $orientation[0..4] is landscape, 5 and 6 => portrait

my @shortpage_framesets = (
    [ 'Landscape full', { widthpair => [ 10, 0 ], height => 42, frame => 0 }, ],
    [   'Landscape halves',
        { widthpair => [ 4, 1 ], height => 42, frame => 0 },
        { widthpair => [ 5, 0 ], height => 42, frame => 2 },
    ],
    [ 'Portrait full', { widthpair => [ 11, 0 ], height => 36, frame => 4 }, ],
    [   'Portrait halves',
        { widthpair => [ 5, 1 ], height => 36, frame => 4 },
        { widthpair => [ 5, 0 ], height => 36, frame => 5 },
    ],
);

my @page_framesets = (
    [ 'Landscape full', { widthpair => [ 15, 0 ], height => 42, frame => 0 }, ],
    [   'Landscape halves',
        { widthpair => [ 7, 0 ], height => 42, frame => 0 },
        { widthpair => [ 7, 0 ], height => 42, frame => 1 },
    ],
    [   'Landscape thirds',
        { widthpair => [ 4, 1 ], height => 42, frame => 0 },
        { widthpair => [ 5, 0 ], height => 42, frame => 2 },
        { widthpair => [ 4, 1 ], height => 42, frame => 3 },
    ],
    [   'Landscape 1/3 - 2/3',
        { widthpair => [ 4,  1 ], height => 42, frame => 0 },
        { widthpair => [ 10, 0 ], height => 42, frame => 2 },
    ],
    [   'Landscape 2/3 - 1/3',
        { widthpair => [ 10, 0 ], height => 42, frame => 0 },
        { widthpair => [ 4,  1 ], height => 42, frame => 3 },
    ],
    [ 'Portrait full', { widthpair => [ 11, 0 ], height => 59, frame => 4 }, ],
    [   'Portrait halves',
        { widthpair => [ 5, 1 ], height => 59, frame => 4 },
        { widthpair => [ 5, 0 ], height => 59, frame => 5 },
    ],

);

for my $frameset_r ( @shortpage_framesets, @page_framesets ) {
    shift @{$frameset_r};    # remove the description
    for my $frame_r ( @{$frameset_r} ) {
        $frame_r->{width} = _width_in_halfcols ( $frame_r->{widthpair} );
    }
}

sub _width_in_halfcols {
    my @widths = flatten(@_);
    return ($widths[0] * 2 + $widths[1]);
}

const my $EXTRA_TABLE_HEIGHT => 9;
# add 9 for each additional table in a stack -- 1 for blank line,
# 4 for timepoints and 4 for the color bar. This is inexact and can mess up...
# not sure how to fix it at this point, I'd need to measure the headers

sub assign_tables_to_pages_and_frames {

    my (@tables) = @{ +shift };    # copy

    return unless _every_table_fits_on_a_page(@tables);

    # @page_permutations consists of all the valid ways of breaking up
    # the various tables into valid pages, in order of preference.
    # A simple example might be:
    #   [ [ All tables on one page ] ] ,
    #   [ [ Table 1, Table 2] , [ Table 3, Table 4 ] ],
    #   [ [ Table 1 ] , [Table 2] , [Table 3 ], [ Table 4] ]

    my @page_permutations = _page_permutations(@tables);

    # go through each possible page set.
    # For this page set, does each possible page fit on one of the framesets?
    # If all pages fit, use it! if not, go to the next page set

  PAGESET:
    foreach my $page_permutation (@page_permutations) {
        foreach my $tables_on_this_page_r ( @{$page_permutation} ) {
          FRAMESET:
            foreach my $frameset (@page_framesets) {
                my $frame_assignment
                  = _get_frame_assignment( $frameset, $tables_on_this_page_r );
                next PAGESET if not defined $frame_assignment;
            }
        }
    }

    ...;

} ## tidy end: sub _assign_tables_to_pages_and_frames

sub _page_permutations {
    # This creates the sets of tables that could possibly fit across pages

    my @tables = @_;
    my @page_permutations;

    # for now I am just going to add these in groups of two,
    # from the sortable order
    # eventually this will need to be much more thorough

    # what I think I will have to do is this: create every possible
    # permutation.  Then sort the page combinations depending on how many things
    # they have in common.
    # if everything on a page has lines in common, that page gets 4 points
    # if everything has days in common, it gets 2 points
    # if everything has directions in common, it gets 1 point

    # Then sort them in order, first by fewest pages, then by number of points.

    if ( @tables > 2 ) {
        @page_permutations = [ chunks( 2, @tables ) ];    # each chunk is a page
        
           # This is just one possible set, where each page has exactly two items
           # This will probably be OK for three- or four-table timetables, but for
           # larger ones, more combinations will be necessary

    }

    # plus all tables on a single page, and each table on its own page

    unshift @page_permutations, [ map { [$_] } @tables ];
    push @page_permutations, [ \@tables ];

    return @page_permutations;

} ## tidy end: sub _page_permutations

sub _get_frame_assignment {

    my @frames = @{ +shift };
    my @tables = @{ +shift };

    if ( @frames > @tables ) {return}
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
        for my $i ( 0 .. @frames ) {
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
              if $frames[$i]{height} < $tables[$i]->height
              or $frames[$i]{width} < $tables[$i]->width_in_halfcols;
            # doesn't fit if frame's height or width aren't big enough
        }

        # it got here, so the tables fit within the frames

        return $table_permutation;

    }

    return;
    # finished all the permutations, but nothing fit everything

} ## tidy end: sub _get_frame_assignment

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

    my $num_frames = shift;
    my @tables     = shift;

    my @indices = ( 0 .. $#tables - 1 );
    my @break_after_idx_sets = combinations( \@indices, $num_frames - 1 );

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

        push @permutation, [ @tables[ $break_after_idx[-1] .. $#tables ] ];

        push @table_permutations, \@permutation;

        my @sort_values = map { scalar @{$_} } @permutation;
        # count of tables in each frame

        unshift @sort_values, population_stdev(@sort_values);
        # standard deviation -- so makes them as close to the same
        # number of tables as possible

        push @table_permutations, [ \@permutation, \@sort_values ];

    } ## tidy end: foreach my $break_after_idx_set...

    @table_permutations = sort _permutationsort @table_permutations;

    return map { $_->[0] } @table_permutations;

} ## tidy end: sub _table_permutations

sub _permutationsort {

    my @a = @$a;
    my @b = @$b;

    # first, return the comparison of the standard deviations of the
    # count of tables in each frame

    my $result = $a[1] <=> $b[1];
    return $result if $result;

    # If those are the same, go through the remaining values,
    # which are the counts of the tables in each frame.
    # Return the one that's highest first -- so it will
    # prefer [2, 1] over [1, 2]
    for my $i ( 2 .. $#a ) {
        my $result = $b[$i] <=> $a[$i];
        return $result if $result;
    }

    return 0;    # the same...

} ## tidy end: sub _permutationsort

sub _get_stacked_measurement {
    my @tables = @_;

    my @widths  = map { $_->width_in_halfcols } @tables;
    my @heights = map { $_->height } @tables;

    my $maxwidth = max(@widths);
    my $sumheight = sum(@heights) + ( $EXTRA_TABLE_HEIGHT * $#heights );

    return ( $sumheight, $maxwidth );

}



#

{
    my @maximum_table_dimensions = (
        { width => _width_in_halfcols( 15, 0 ), height => 42 },
        { width => _width_in_halfcols( 11, 0 ), height => 59 }
    );

    sub _every_table_fits_on_a_page {
        my @tables = @_;

        foreach my $table ( 0 .. $#tables ) {
            my ( $height, $width )
              = ( $table->height, $table->width_in_halfcols );

            my $fits_on_a_page;
            for my $maximum (@maximum_table_dimensions) {
                if (    $maximum->{width} <= $width
                    and $maximum->{height} <= $height )
                {
                    $fits_on_a_page = 1;
                    last;
                }
            }
            if ( not $fits_on_a_page ) {
                emit_text $table->id . " does not fit on a single page";
                return;
            }

        }

        return 1;

    } ## tidy end: sub _every_table_fits_on_a_page
}

1;
