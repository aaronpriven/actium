# Actium/Cmd/Tabula.pm

# Produces InDesign tag files that represent timetables.

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.012;

package Actium::Cmd::Tabula 0.001;

use English '-no_match_vars';
use autodie;
use Text::Trim;
use Actium::EffectiveDate ('effectivedate');
use Actium::Sorting::Line ( 'sortbyline', 'byline' );
use Actium::Constants;
use Actium::Text::InDesignTags;
use Actium::Text::CharWidth ( 'ems', 'char_width' );
use Actium::O::Folders::Signup;
use Actium::Term;
use Actium::O::Sked;
use Actium::O::Sked::Timetable;
use Actium::Util(qw/doe in chunks/);
use Const::Fast;
use List::Util ( 'max', 'sum' );
use List::MoreUtils (qw<uniq pairwise natatime each_arrayref>);
use Algorithm::Combinatorics ('combinations');

const my $IDT        => 'Actium::Text::InDesignTags';
const my $SOFTRETURN => $IDT->softreturn;

# saves typing

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
tabula. Reads schedules and makes tables out of them.
HELP

    Actium::Term::output_usage();

    return;
}

sub START {

    my $signup            = Actium::O::Folders::Signup->new();
    my $tabulae_folder    = $signup->subfolder('tabulae');
    my $pubtt_folder      = $tabulae_folder->subfolder('pubtt');
    my $multipubtt_folder = $tabulae_folder->subfolder('m-pubtt');

    my $xml_db = $signup->load_xml;

    my $prehistorics_folder = $signup->subfolder('skeds');

    chdir( $signup->path );

    # my %front_matter = _get_configuration($signup);

    my @skeds
      = Actium::O::Sked->load_prehistorics( $prehistorics_folder, $xml_db );

    my @all_lines = map { $_->lines } @skeds;
    @all_lines = uniq sortbyline @all_lines;
    my $pubtt_contents_r = _get_pubtt_contents( $xml_db, \@all_lines );

    @skeds = _sort_skeds(@skeds);

    my ( $alltables_r, $tables_of_r )
      = _create_timetable_texts( $xml_db, @skeds );

    _output_all_tables( $tabulae_folder, $alltables_r );
    _output_pubtts( $pubtt_folder, $pubtt_contents_r, $tables_of_r, $signup );
    _output_m_pubtts( $multipubtt_folder, $pubtt_contents_r, $tables_of_r,
        $signup );

    return;

} ## tidy end: sub START

sub _create_timetable_texts {

    emit "Creating timetable texts";

    my $xml_db = shift;
    my @skeds  = @_;

    my ( %tables_of, @alltables );
    my $prev_linegroup = $EMPTY_STR;
    foreach my $sked (@skeds) {

        my $linegroup = $sked->linegroup;
        if ( $linegroup ne $prev_linegroup ) {
            emit_over "$linegroup ";
            $prev_linegroup = $linegroup;
        }

        my $table = Actium::O::Sked::Timetable->new_from_sked( $sked, $xml_db );
        push @{ $tables_of{$linegroup} }, $table;
        push @alltables, $table;
    }

    emit_over $EMPTY_STR;
    emit_done;

    return \@alltables, \%tables_of;

} ## tidy end: sub _create_timetable_texts

sub _sort_skeds {
    my @skeds = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->sortable_id() ] } @_;
    return @skeds;
}

sub _output_all_tables {

    emit "Outputting all tables into all.txt";

    my $tabulae_folder = shift;
    my $alltables_r    = shift;

    #$alltables_r =  [ (@{$alltables_r})[0..50] ]; # debug

    open my $allfh, '>', $tabulae_folder->make_filespec('all.txt');

    print $allfh $IDT->start;
    foreach my $table ( @{$alltables_r} ) {
        print $allfh $table->as_indesign( 4, 0 ), $IDT->boxbreak;
    }
    # minimum 4 columns, no half columns

    close $allfh;

    emit_done;

} ## tidy end: sub _output_all_tables

sub _get_pubtt_contents {
    my $xml_db  = shift;
    my $lines_r = shift;

    $xml_db->ensure_loaded('Lines');
    my $on_timetable_from_db_r
      = $xml_db->all_in_column_key(qw/Lines OnTimetable/);

    my %on_timetable_of;

    foreach my $line (@$lines_r) {
        my $fromdb = $on_timetable_from_db_r->{$line};
        if ( defined $fromdb and $fromdb ne $EMPTY_STR ) {
            push @{ $on_timetable_of{$fromdb} }, $line;
        }
        else {
            push @{ $on_timetable_of{$line} }, $line;
        }
    }

    my @pubtt_contents;

    for my $lines_r ( values %on_timetable_of ) {
        push @pubtt_contents, [ sortbyline @{$lines_r} ];
    }

    return [ sort { byline( $a->[0], $b->[0] ) } @pubtt_contents ];

} ## tidy end: sub _get_pubtt_contents

sub _output_pubtts {

    emit "Outputting public timetable files";

    my $pubtt_folder   = shift;
    my @pubtt_contents = @{ +shift };
    my %tables_of      = %{ +shift };
    my $signup         = shift;

    my $effectivedate = effectivedate($signup);

    foreach my $pubtt (@pubtt_contents) {

        my ( $tables_r, $lines_r ) = _tables_and_lines( $pubtt, \%tables_of );

        next unless @$tables_r;

        my $file = join( "_", @{$lines_r} );

        emit_prog "$file ";

        open my $ttfh, '>', $pubtt_folder->make_filespec("$file.txt");

        print $ttfh Actium::Text::InDesignTags->start;

        #        _output_pubtt_front_matter( $ttfh, $tables_r, $lines_r,
        #            $front_matter{$pubtt}, $effectivedate );
        _output_pubtt_front_matter( $ttfh, $tables_r, $lines_r, [],
            $effectivedate );

        my $minimum_of_r = _minimums($tables_r);

        my @tabletexts;

        my $tablecount = scalar @{$tables_r};

        foreach my $table ( @{$tables_r} ) {

            my $linedays         = $table->linedays;
            my $min_half_columns = $minimum_of_r->{$linedays}{half_columns};
            my $min_columns      = $minimum_of_r->{$linedays}{columns};

            if ( $min_columns * 2 + $min_half_columns <= 9 ) {

                $min_half_columns = 1;
                $min_columns      = 4;

            }

            if ( $tablecount <= 2 or $table->linegroup() =~ /\A 6 \d \d \z/sx )
            {
                $min_half_columns = 0;
                $min_columns      = 10;
            }

            push @tabletexts,
              $table->as_indesign( $min_columns, $min_half_columns );
        } ## tidy end: foreach my $table ( @{$tables_r...})

        #print $ttfh join( ( $IDT->hardreturn x 2 ), @tabletexts );

        print $ttfh $tabletexts[0];

        for my $i ( 1 .. $#tabletexts ) {
            #my $break = ($i % 2) ? ($IDT->hardreturn x 2) : $IDT->boxbreak;
            my $break = ( $IDT->hardreturn x 2 );
            print $ttfh $break, $tabletexts[$i];
        }
        # print two returns in between each pair of schedules
        # print a box break after each pair

        # End matter, if there is any, goes here

        close $ttfh;

    } ## tidy end: foreach my $pubtt (@pubtt_contents)

    emit_done;

} ## tidy end: sub _output_pubtts

sub _minimums {
    my @tables = @{ +shift };

    my %minimum_of;
    foreach my $table (@tables) {
        my $linedays = $table->linedays;

        my $half_columns = $table->half_columns;
        my $columns      = $table->columns;

        if ( not exists $minimum_of{$linedays} ) {
            $minimum_of{$linedays}{half_columns} = $half_columns;
            $minimum_of{$linedays}{columns}      = $columns;
        }

        $minimum_of{$linedays}{half_columns} = $half_columns
          if $half_columns > $minimum_of{$linedays}{half_columns};
        $minimum_of{$linedays}{columns} = $columns
          if $columns > $minimum_of{$linedays}{columns};
    }

    return \%minimum_of;

} ## tidy end: sub _minimums

sub _tables_and_lines {

    my $pubtt     = shift;
    my %tables_of = %{ +shift };

    my @linegroups = @{$pubtt};
    #my @linegroups = sortbyline( split( ' ', $pubtt ) );

    my ( @tables, @lines );

    foreach my $linegroup (@linegroups) {
        next unless $tables_of{$linegroup};
        push @tables, @{ $tables_of{$linegroup} };
    }

    @tables = sort { $a->sortable_id cmp $b->sortable_id } @tables;

    my %is_a_line;
    foreach my $table (@tables) {
        $is_a_line{$_} = 1 foreach ( $table->header_routes );
    }
    @lines = sortbyline( keys %is_a_line );

    return \@tables, \@lines;

} ## tidy end: sub _tables_and_lines

my %front_style_of = (
    '>' => 'CoverCity',
    '}' => 'CoverCitySm',
    ':' => 'CoverLineInDesc',
    ';' => 'CoverLineInDesc',
    '/' => 'CoverNote',
    '|' => 'CoverNoteBold',
    '*' => 'CoverLocalPax',

);

sub _output_pubtt_front_matter {

    my $ttfh          = shift;
    my $tables_r      = shift;
    my @lines         = @{ +shift };
    my @front_matter  = @{ +shift };
    my $effectivedate = shift;

    # @front_matter is currently unused, but I am leaving the code in here
    # for now

    # ROUTES

    my $length = _make_length(@lines);

    print $ttfh $IDT->parastyle("CoverLine$length");
    print $ttfh join( $IDT->hardreturn, @lines ), $IDT->boxbreak;

    # EFFECTIVE DATE

    print $ttfh $IDT->parastyle('CoverEffectiveBlack'), 'Effective:',
      $IDT->hardreturn;
    print $ttfh $IDT->parastyle('CoverDate'), $effectivedate;

    my $per_line_texts_r = _make_per_line_texts( $tables_r, \@lines );

    # COVER MATERIALS
    foreach my $front_text (@front_matter) {

        print $ttfh $IDT->hardreturn;

        my $leading_char = substr( $front_text, 0, 1 );

        if ( not $front_style_of{$leading_char} ) {
            print $ttfh $IDT->parastyle('CoverPlace'), $front_text;
            next;
        }

        $front_text = substr( $front_text, 1 );
        trim($front_text);

        print $ttfh $IDT->parastyle( $front_style_of{$leading_char} ),
          $front_text;

        if ( $leading_char eq ':' and exists $per_line_texts_r->{$front_text} )
        {
            print $ttfh $per_line_texts_r->{$front_text};
        }

    } ## tidy end: foreach my $front_text (@front_matter)

    print $ttfh $IDT->boxbreak;

    print $ttfh $per_line_texts_r->{$EMPTY_STR}
      if exists $per_line_texts_r->{$EMPTY_STR};

    print $ttfh $IDT->boxbreak;

    return;

} ## tidy end: sub _output_pubtt_front_matter

sub _make_per_line_texts {

    my $tables_r = shift;
    my $lines_r  = shift;
    my %per_line_texts;

    my $days_of_r = _make_days( $tables_r, $lines_r );
    my $locals_of_r = _make_locals($lines_r);

    foreach
      my $line ( uniq( sort ( keys %{$days_of_r}, keys %{$locals_of_r} ) ) )
    {

        my @texts;

        if ( $days_of_r->{$line} ) {

            my $daytext = $days_of_r->{$line}->as_plurals;

            $daytext =~ s/\(/${SOFTRETURN}\(/g;

            push @texts, $IDT->parastyle('CoverNoteBold') . $daytext;

        }

        my $local_line = $line || $lines_r->[0];

        if ( exists $locals_of_r->{$line} ) {
            my $local_text = _local_text($local_line);
            push @texts, $local_text if $local_text;
        }

        $per_line_texts{$line} = join( $IDT->hardreturn, @texts );

    } ## tidy end: foreach my $line ( uniq( sort...))

    return \%per_line_texts;

} ## tidy end: sub _make_per_line_texts

sub _make_days {

    my @tables = @{ +shift };
    my @lines  = @{ +shift };

    my %all_days_objs_of;

    foreach my $table (@tables) {
        foreach my $line ( $table->header_routes ) {
            push @{ $all_days_objs_of{$line} }, $table->days_obj();
        }
    }

    my %days_obj_of;
    while ( my ( $line, $days_objs_r ) = each %all_days_objs_of ) {
        $days_obj_of{$line} = Actium::O::Days->union( @{$days_objs_r} );
    }

    if ( @lines == 1 ) {
        return { $EMPTY_STR => $days_obj_of{ $lines[0] } };
    }

    my @days_objs = values %days_obj_of;
    my @days_codes = uniq( map { $_->as_sortable } @days_objs );

    if ( @days_codes == 1 ) {
        return { $EMPTY_STR => $days_objs[0] };
    }

    return \%days_obj_of;

} ## tidy end: sub _make_days

sub _make_locals {

    my @lines = @{ +shift };

    my %local_of;
    foreach my $line (@lines) {

        if ( $line =~ /\A [A-Z]/sx or $line eq '800' ) {
            if ( in( $line, @TRANSBAY_NOLOCALS ) ) {
                $local_of{$line} = 0;
            }
            else {
                $local_of{$line} = 1;
            }

        }
        else {
            $local_of{$line} = -1;
        }
    }

    my @locals = uniq( sort values %local_of );

    if ( @locals == 1 ) {
        return { $EMPTY_STR => $locals[0] };
    }

    return \%local_of;

} ## tidy end: sub _make_locals

sub _local_text {
    my $line = shift;

    if ( in( $line, @TRANSBAY_NOLOCALS ) ) {
        return $IDT->parastyle('CoverLocalPax') . 'No Local Passengers Allowed';
    }

    if ( $line eq '800' or $line =~ /\A [A-Z]/sx ) {
        return $IDT->parastyle('CoverLocalPax')
          . 'Local Passengers Permitted for Local Fare';
    }

    return $EMPTY_STR;

}

sub _make_length {

    my @lines = @_;

    my $ems = max( ( map { ems($_) } @lines ) );

    #if ( $lines[0] =~ /72/ ) {
    #    emit_over '[' . doe($ems) . ']';
    #}

    my $length;
    for ($ems) {
        when ( $_ <= .9 ) {    # two digits are .888
            $length = 1;
        }
        when ( $_ <= 1.2 ) {    # three digits are 1.332
            $length = 2;
        }
        when ( $_ <= 1.5 ) {    # N66 is 1.555
            $length = 3;
        }
        default {
            $length = 4;
        }

    }

    return max( $length, scalar @lines );
} ## tidy end: sub _make_length

sub _output_m_pubtts {

    emit "Outputting multipage public timetable files";

    my $pubtt_folder   = shift;
    my @pubtt_contents = @{ +shift };
    my %tables_of      = %{ +shift };
    my $signup         = shift;

    my $effectivedate = effectivedate($signup);

    foreach my $pubtt (@pubtt_contents) {

        my ( $tables_r, $lines_r ) = _tables_and_lines( $pubtt, \%tables_of );

        next unless @$tables_r;

        my $file = join( "_", @{$lines_r} );

        emit_prog " $file";

        open my $ttfh, '>', $pubtt_folder->make_filespec("$file.txt");

        print $ttfh Actium::Text::InDesignTags->start;

        _output_pubtt_front_matter( $ttfh, $tables_r, $lines_r, [],
            $effectivedate );

        my @table_assignments = _assign_frames($tables_r);

        if ( not @table_assignments ) {
            emit_prog "*";
            next;
        }

        my $firsttable    = 1;
        my $current_frame = 0;

        foreach my $table_assignment (@table_assignments) {

            my $table     = $table_assignment->{table};
            my $width     = $table_assignment->{width};
            my $frame     = $table_assignment->{frame};
            my $pagebreak = $table_assignment->{pagebreak};

            if ( $frame == $current_frame and not $pagebreak ) {
                # if it's in the same frame
                if ( not $firsttable ) {
                    print $ttfh $IDT->hardreturn x 2;
                }
            }
            else {
                # otherwise it's in a different frame
                if ( $pagebreak or $current_frame > $frame ) {
                    print $ttfh $IDT->pagebreak;
                    $current_frame = 0;
                }
                my $framebreaks = $frame - $current_frame;
                print $ttfh ( $IDT->boxbreak x $framebreaks );
                $current_frame += $framebreaks;
            }
            print $ttfh $table->as_indesign( @{$width} );
            $firsttable = 0;

        } ## tidy end: foreach my $table_assignment...

        # End matter, if there is any, goes here

        close $ttfh;

    } ## tidy end: foreach my $pubtt (@pubtt_contents)

    emit_done;

} ## tidy end: sub _output_m_pubtts

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
my @maximum_table_dimensions = (
    { width => _width_in_halfcols( 15, 0 ), height => 42 },
    { width => _width_in_halfcols( 11, 0 ), height => 59 }
);

for my $frameset_r ( @shortpage_framesets, @page_framesets ) {
    shift @{$frameset_r};    # remove the description
    for my $frame_r ( @{$frameset_r} ) {
        $frame_r->{width} = _width_in_halfcols { $frame_r->{widthpair} };
    }
}

sub _width_in_halfcols {
    my $width = shift;
    return $width->[0] * 2 + $width->[1];
}

const my $EXTRA_TABLE_HEIGHT => 9;
# add 9 for each additional table in a stack -- 1 for blank line,
# 4 for timepoints and 4 for the color bar. This is inexact and can mess up...
# not sure how to fix it at this point, I'd need to measure the headers

sub _assign_frames {

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
                my $fits = _check_page( $frameset, $tables_on_this_page_r );

            }
        }
    }

    ...;

} ## tidy end: sub _assign_frames

sub _check_page {

    my @frames = @{ +shift };
    my @tables = @{ +shift };

    return 0 if ( @frames > @tables );
    # If there are more frames than there are tables,
    # this cannot be the best fit

    # will this set of tables fit on this page?

    if ( @frames == 1 ) {
        my ( $height, $width ) = _get_stacked_measurement(@tables);
        return (  $height <= $frames[0]{height}
              and $width <= $frames[0]{width} );
    }

    if ( @frames == @tables ) {
        for my $i ( 0 .. @frames ) {
            return 0
              if $frames[$i]{height} < $tables[$i]->height
              or $frames[$i]{width} < $tables[$i]->width_in_halfcols;
            # doesn't fit if frame's height or width aren't big enough
        }
        return 1;    # all frames fit
    }
    
    
    
       #### FIX HERE NEXT
       
       
       
       

    # more tables than frames. Divide tables up into appropriate sets,
    # and then try them

} ## tidy end: sub _check_page

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
    # and returns the subsets.

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

    }

    return @table_permutations;

} ## tidy end: sub _table_permutations

sub _get_stacked_measurement {
    my @tables = @_;

    my @widths  = map { $_->width_in_halfcols } @tables;
    my @heights = map { $_->height } @tables;

    my $maxwidth = max(@widths);
    my $sumheight = sum(@heights) + ( $EXTRA_TABLE_HEIGHT * $#heights );

    return ( $sumheight, $maxwidth );

}

sub _page_permutations {
    # This creates the sets of tables that could possibly fit across pages

    my @tables = @_;
    my @page_permutations;

    # for now I am just going to add these in groups of two,
    # from the sortable order
    # eventually this will need to be much more thorough

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

#

sub _every_table_fits_on_a_page {
    my @tables = @_;

    foreach my $table ( 0 .. $#tables ) {
        my ( $height, $width ) = ( $table->height, $table->width_in_halfcols );

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

1;

__END__

removed from _assign_frames

my @one_frame_test = (
    { widthpair => [ 10, 0 ], height => 42, shortpage => 1, frame => 0 },
    { widthpair => [ 11, 0 ], height => 36, shortpage => 1, frame => 4 },
    { widthpair => [ 15, 0 ], height => 42, shortpage => 0, frame => 0 },
    { widthpair => [ 11, 0 ], height => 59, shortpage => 0, frame => 4 }
    ,
);

 ## CHECK TO SEE IF ALL FIT IN SINGLE FRAME

    my $max_width_in_halfcols = max @{$widths_in_halfcols_r};
    my $sum_height            = sum( @{$heights_r} );

    $sum_height += $#{$heights_r} * $EXTRA_TABLE_HEIGHT;

    foreach my $test_r (@one_frame_test) {

        my $test_widthpair         = $test_r->{widthpair};
        my $test_width_in_halfcols = _width_in_halfcols($test_widthpair);
        my $test_height            = $test_r->{height};
        next
          if $test_width_in_halfcols < $max_width_in_halfcols
          or $test_height < $sum_height;

        # if it fits on a single frame -- either on the first short page,
        # or on the first regular page -- it will go here

        my $firsttable = shift @tables;
        my $frame      = $test_r->{frame};
        my @frames     = (
            {   table     => $firsttable,
                width     => $test_widthpair,
                pagebreak => not( $test_r->{shortpage} ),
                frame     => $frame,
            }
        );

        foreach my $table (@tables) {
            push @frames,
              { table     => $table,
                width     => $test_widthpair,
                pagebreak => 0,
                frame     => $frame,
              };
        }

        return @frames;

    } ## tidy end: foreach my $test_r (@one_frame_test)
    
    
sub _get_table_sizes {
    my $tables_r = shift;

    my ( @heights, @widths_in_halfcols );

    foreach my $table (@$tables_r) {
        push @heights,            $table->height;
        push @widths_in_halfcols, $table->width_in_halfcols;

    }

    return \@heights, \@widths_in_halfcols;

}

## stuff that assigns them into chunks

    my @chunks = [ \@tables ] ; # first chunk: everything together

    # then a chunk divided by day, then one divided by direction

    foreach my $codetype ( qw(daycode dircode)) {
        my $index = 0;
        my %order;
        my %tables_of;
        my @thischunk;
        
        foreach my $table (@tables) {

            my $code = $table->$codetype;

            if ( not exists $order{$code} ) {
                $order{$code} = ++$index;
            }

            push @{ $tables_of{$code} }, $table;
        }
        
        foreach my $code ( sort { $order{$a} <=> $order{$b} } keys %order ) {
           push @thischunk, $tables_of{$code};
        }
        
        push @chunks, \@thischunk;
        
    }

    push @chunks, [ map { [$_] } @tables ]; # finally, one chunk per table
    
    
    
    ### another attempt
    
        my @chunksets;
#    foreach my $count ( reverse( 2 .. @tables ) ) {
#        next if is_odd($count) and is_even( scalar @tables );
#        push @chunksets, [ chunks( $count, @tables ) ];
#    }
#    push @chunksets,
#      [ map { [$_] } @tables ];    # one at a time
#    # those are always the sortable order, from greatest to smallest
#    # TODO: add acceptable permutations of the original order
#
#    foreach my $chunks_r (@chunksets) {
#
#        my @chunks;
#        foreach my $chunk ( chunks( 2, @tables ) ) {
#            my @thesetables = @{$chunk};
#            my @heights     = map { $_->height } @thesetables;
#            my @widths      = map { $_->width_in_halfcols } @thesetables;
#
#            my $maxwidth  = max(@widths);
#            my $maxheight = max(@heights);
#            my $sumheight = sum(@heights) + ( $EXTRA_TABLE_HEIGHT * $#heights );
#
#            push @chunks,
#              { tables    => \@thesetables,
#                maxwidth  => max(@widths),
#                maxheight => max(@heights),
#                sumheight => sum(@heights) + ( $EXTRA_TABLE_HEIGHT * $#heights )
#              };
#        }
#
#    } ## tidy end: foreach my $chunks_r (@chunksets)
#
