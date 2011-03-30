# Actium::Headways.pm

# Routines to read headway sheets

# Subversion: $Id$

use strict;
use warnings;

package Actium::Headways;

use utf8;
our $VERSION = '0.001';
$VERSION = eval $VERSION;

use 5.010;

use Actium::Term qw<:all>;
use Actium::Files qw<:all>;
use Actium::Signup;
use Actium::Constants;
use Actium::Union(':all');
use Actium::HeadwayPage;
use Actium::Trip;
use Actium::SkedNote;
use Actium::Util qw<j>;

# use Term::Emit qw/:all/, {-closestat => "ERROR"};

use List::MoreUtils qw(any true first_index pairwise);
use Text::Trim();

use Carp;

use English qw(-no_match_vars);

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium headways -- read headway sheets and dump out schedules.
HELP

    Actium::Term::output_usage();

    return;

}

sub START {

    # Term::Emit::setopts { -closestat => 'ERROR' };

    my $headwaysdir = Actium::Signup->new('headways');

    my @files = $headwaysdir->glob_plain_files();

    #### DEBUG ONLY
    #@files = ( $files[1] );
    unshift @files, pop @files;    # reorder for debugging

    ####

    my ( $skeds_r, $notes_r ) = read_headways(@files);

    writefileswithmethod( $skeds_r, 'headskeds', 'txt', 'dump' );
    writefileswithmethod( $notes_r, 'headnotes', 'txt', 'dump' );

    # this probably should be a separate program, but for now, isn't

    write_prehistorics($skeds_r);

 #    my $headskedsdir = Actium::Signup->new('headskeds');
 #    my $headnotesdir = Actium::Signup->new('headnotes');
 #
 #    emit 'Writing headskeds';
 #
 #    foreach my $sked ( @{$skeds_r} ) {
 #
 #        my $out;
 #
 #        my $skedfile = $headskedsdir->make_filespec( $sked->skedid . '.txt' );
 #        unless ( open $out, '>', $skedfile ) {
 #            emit_error;
 #            die "Can't open $skedfile for writing: $OS_ERROR";
 #        }
 #
 #        print $out $sked->dump() or die "Can't print to $skedfile: $OS_ERROR";
 #
 #        unless ( close $out ) {
 #            emit_error;
 #            die "Can't close $skedfile for writing: $OS_ERROR";
 #        }
 #
 #    }
 #
 #    emit_done;
 #
 #    emit 'Writing headnotes';
 #
 #    foreach my $note ( @{$notes_r} ) {
 #
 #        my $notefile = $headnotesdir->make_filespec( $note->noteid . '.txt' );
 #
 #        my $out;
 #
 #        unless ( open $out, '>', $notefile ) {
 #            emit_error;
 #            die "Can't open $notefile for writing: $OS_ERROR";
 #        }
 #
 #        print $out $note->dump() or die "Can't print to $notefile: $OS_ERROR";
 #
 #        unless ( close $out ) {
 #            emit_error;
 #            die "Can't close $notefile for writing: $OS_ERROR";
 #        }
 #
 #    }
 #
 #    emit_done;

    return;

} ## <perltidy> end sub START

sub read_headways {
    my @files = @_;
    my ( @schedules, @notes );

    emit 'Reading headway sheets';

    foreach my $file (@files) {

        my ( $schedules_r, $notes_r ) = read_headway_file($file);

        push @schedules, @{$schedules_r};
        push @notes,     @{$notes_r};

    }
    emit_done;

    return \@schedules, \@notes;

    # note that what is returned has not merged the days

} ## <perltidy> end sub read_headways

{    # this block is for scoping - variables about each headway sheet file

    my %indexes;
    my $days;
    my $file;
    my $dispfile;
    my ( @leading_fieldnames, $leading_template, $leading_chars );
    my ( @trailing_fieldnames, $trailing_template );
    my @remaining_fieldnames;
    my @notes;
    my @pages;

    sub read_headway_file {

        $file     = shift;
        $dispfile = Actium::Files::filename($file);
        emit 'Reading ' . $dispfile;

        @notes = ();

        load_pages();

        assemble_wide_pages();

        parse_pages();

        assemble_tall_pages();

        combine_identical_trips(@pages);

        combine_duplicate_timepoints(@pages);

        my $schedules_r = create_skeds_from_pages(@pages);

        emit_done;

        return $schedules_r, \@notes;

    } ## <perltidy> end sub read_headway_file

    sub load_pages {

        open( my $fh, '<', $file )
          or die("Can't open $file: $OS_ERROR");

        emit 'Loading first page';

        my @lines_in_this_page = load_a_page($fh);

        determine_header_indexes(@lines_in_this_page);
        determine_days(@lines_in_this_page);
        determine_columns(@lines_in_this_page);

        @pages = ( new_page(@lines_in_this_page) );

        emit_done;

        emit 'Loading remaining pages';

        my $page_count = 1;

        while ( my @lines_in_this_page = load_a_page($fh) )
        {    ## no critic (ProhibitReusedNames)
            emit_over $page_count++;
            push @pages, new_page(@lines_in_this_page);
        }

        close $fh
          or die("Can't close $file: $OS_ERROR");

        emit_done;

        return;

    } ## <perltidy> end sub load_pages

    sub new_page {
        my @lines_in_this_page = @_;

        my $newpage = Actium::HeadwayPage->new(@lines_in_this_page);

        # set origlinegroup , line description , days

        my $routeline = $newpage->line( $indexes{route} );

        $routeline =~ s/.*?oute:\s+//sx;
        my ( $origlinegroup, $linedescrip )
          = Text::Trim::trim( split( $SPACE, $routeline, 2 ) );

        $newpage->set_origlinegroup($origlinegroup);
        $newpage->set_linedescrip($linedescrip);
        $newpage->set_days($days);

        # set direction

        my $directionline = $newpage->line( $indexes{direction} );

        my $dir;
        given ($directionline) {
            when (/North/is)            { $dir = 'NB'; }
            when (/South/is)            { $dir = 'SB'; }
            when (/East/is)             { $dir = 'EB'; }
            when (/West/is)             { $dir = 'WB'; }
            when (/Counterclockwise/is) { $dir = 'CC'; }
            when (/Clockwise/is)        { $dir = 'CW'; }
            default                     { $dir = 'DEFAULT'; }
        }

        $newpage->set_direction($dir);

        return $newpage;

    } ## <perltidy> end sub new_page

    sub load_a_page {
        my $fh = shift;

        my @lines_in_this_page;

        while ( my $this_line = readline($fh) ) {

            chomp $this_line;
            $this_line =~ s/\cL//gsx;    # strip end of page markers.
            $this_line =~ s/\cM//gsx;    # strip carriage returns, if present

            # We actually don't use the end of page markers because they're
            # not always there. Instead we use the line beginning "HASTUS 2006"
            # at the end of each page.

            last if $this_line =~ /^HASTUS\s+2006\s+/sx;

            if ( scalar @lines_in_this_page or $this_line =~ /\S/sx ) {

                # if this isn't the first line in the page, or this line
                # isn't blank, then

                # Change lines with just hyphens, spaces, underlines, and equals
                # into blank lines.
                $this_line =~ s/^ [-\s_=]* \z //sx;

                # Save this line

                push @lines_in_this_page, $this_line;

            }

        } ## <perltidy> end while ( my $this_line = readline...)

        return @lines_in_this_page;

    } ## <perltidy> end sub load_a_page

    sub determine_header_indexes {

        my @lines = @_;

        emit 'Determining where the headers are';

        my $first_idx = ( first_index { our $_; /^EXC /s } @lines ) - 1;
        my $schedule_idx = first_index { our $_; /^\w+\s+schedule:/isx } @lines;
        my $route_idx    = first_index { our $_; /^(?:R|^Public\sr)oute/isx } @lines;
        my $direction_idx = first_index { our $_; /^Direction:/isx } @lines;

## no critic (ProhibitMagicNumbers)
        if (   $first_idx < 0
            or $schedule_idx == -1
            or $route_idx == -1
            or $direction_idx == -1 )
        {
## use critic

            emit_fatal { -reason =>
qq{Can't identify the route, schedule, direction, and column header lines at "$file"}
                  . qq{ line $INPUT_LINE_NUMBER: $route_idx/$schedule_idx/$direction_idx/$first_idx}
            };
            die("Unable to parse $file");
        }

        $indexes{first}     = $first_idx;
        $indexes{schedule}  = $schedule_idx;
        $indexes{route}     = $route_idx;
        $indexes{direction} = $direction_idx;

        emit_done;

        return;

    } ## <perltidy> end sub determine_header_indexes

    sub determine_days {

        emit 'Determining days';

        my @lines = @_;

        my $line = $lines[ $indexes{schedule} ];

        given ($line) {
            when (/Saturday/s) { $days = 'SA'; }
            when (/Sunday/s)   { $days = 'SU'; }
            when (/Weekday/s)  { $days = 'WD'; }
            default            { $days = 'DEFAULT'; }
        }

        if ( $days eq 'DEFAULT' ) {

            $days = 'WD';

            emit_warn {
                -reason => "No days found in $file; assuming weekdays" };

        }
        else {
            emit_prog ($days);
            emit_ok;
        }

        return;

    } ## <perltidy> end sub determine_days

    sub determine_columns {

        ## no critic (ProhibitMagicNumbers)

        # This really lame routine just chooses between the
        # Crew Schedule report and the Vehicle Schedule report.
        # In an better world it would be more flexible.

        my $reporttype;

        my @lines = @_;

        my $line = $lines[ $indexes{first} ];

        my $totest = substr( $line, 13, 3 );

        given ($totest) {
            when ('RUN') {
                $reporttype = 'Crew';
            }

            when ('LOC') {    # from "BLOCK"
                $reporttype = 'Vehicle';
            }

            default {
                emit_fatal {
                    -reason => "Unknown report type: unable to parse $dispfile"
                };
                die("Couldn't parse $file");
            }
        }

        if ( $reporttype eq 'Crew' ) {
            @leading_fieldnames
              = qw[ exceptions routenum runid blockid vehicletype from noteletter ];
            $leading_template
              = q[  A4         A6       A10   A11     A4          A10  A8 ];
            $leading_chars = 53;
        }
        else {    # type eq 'Vehicle'
            @leading_fieldnames
              = qw[ exceptions routenum blockid vehicletype from noteletter ];
            $leading_template
              = q[  A4         A6       A10     A4          A10  A8 ];
            $leading_chars = 42;
        }

        @trailing_fieldnames  = qw< to stopleave >;
        $trailing_template    = q[    A9 A*];
        @remaining_fieldnames = ( @leading_fieldnames, @trailing_fieldnames );

        return;

    } ## <perltidy> end sub determine_columns

    sub assemble_wide_pages {

        emit 'Assembling wide pages';

        my $prev_page_idx = 0;
        my $next_page_idx = 1;

      PAGE:
        while ( $next_page_idx < scalar(@pages) ) {

            my $prev_page = $pages[$prev_page_idx];
            my $next_page = $pages[$next_page_idx];

            my $prev_first = $prev_page->line( $indexes{first} );

            # If the previous page has the proper characters in the first line,
            # it's good; go to the next line.
            if (   $prev_first =~ /DIV-IN\s\sSTOP\z/sx
                or $prev_first =~ /^Notes:/sx )
            {
                emit_over $next_page_idx;

                $prev_page_idx = $next_page_idx;
                $next_page_idx++;

                next PAGE;
            }

            # Otherwise, add the current page to the previous page, and delete
            # the current page.

            for my $line_idx ( $indexes{first} .. $next_page->line_count() - 1 )
            {

                # for all lines for the column headings, and afterwards

                my $prevline = $prev_page->line($line_idx);

                my $newline;

                if ( $prevline =~ /\S/sx ) {
                    $newline = $prevline . q{ } . $next_page->line($line_idx);
                }
                else {
                    $newline = $next_page->line($line_idx);
                }

                $prev_page->set_line( $line_idx, $newline );

            }

            splice( @pages, $next_page_idx, 1 ); # delete page at $next_page_idx

        } ## <perltidy> end while ( $next_page_idx < ...)

        emit_done;

        return;

    } ## <perltidy> end sub assemble_wide_pages

    sub parse_pages {

        emit 'Parsing pages by linegroup';

        my %seen_origlinegroup;

      PAGE:
        for my $page (@pages) {

            # get origlinegroup - this is just for display
            my $origlinegroup = $page->origlinegroup();
            emit_over $origlinegroup unless $seen_origlinegroup{$origlinegroup}++;
            
            my $firstline = $page->line( $indexes{first} );

            if ( $firstline =~ /^Notes:/s ) {
                parse_notes( $page, $indexes{first} );
                next PAGE;

            }

            my $chars_per_timepoint = 9;    ## no critic (ProhibitMagicNumbers)
            my $number_of_timepoints
              = ( index( $firstline, 'DIV-IN' ) - $leading_chars )
              / $chars_per_timepoint;
            my $template
              = $leading_template . ( 'A9' x $number_of_timepoints ) . 'A9 A*';

            my @colheads = Text::Trim::trim( unpack( $template, $firstline ) );
            my @colheads_secondline = Text::Trim::trim(
                unpack( $template, $page->line( $indexes{first} + 1 ) ) );

            my @place8s = splice( @colheads, scalar @leading_fieldnames,
                $number_of_timepoints );

            my @place8s_secondline
              = splice( @colheads_secondline, scalar @leading_fieldnames,
                $number_of_timepoints );

            our ( $a, $b );    ## no critic 'ProhibitPackageVars'

            @place8s = pairwise { sprintf '%-4s%s', $a, $b } @place8s,
              @place8s_secondline;

            # sprintf ensures that place8 always has enough spaces to
            # turn into a place9

            @colheads = pairwise { $a . $b } @colheads, @colheads_secondline;

            # code before
            #my @place8s = splice( @colheads, scalar @leading_fieldnames,
            #    $number_of_timepoints );

            $page->set_place8_r( \@place8s );

          LINE:
            for my $this_line_idx (
                $indexes{first} + 2 .. $page->line_count() - 1 )
            {

                my $thisline = $page->line($this_line_idx);

                if ( $thisline =~ /^Notes:/s ) {
                    parse_notes( $page, $this_line_idx );
                    next PAGE;
                }

                next LINE unless $thisline =~ /\S/sx;

                my @fields = unpack( $template, $thisline );

                Text::Trim::trim(@fields);

                # separate fields...
                my @times = splice( @fields, scalar @leading_fieldnames,
                    $number_of_timepoints );

                my %fields;
                @fields{@remaining_fieldnames} = @fields;    # hash slice
                
                next LINE
                  if ( true { /\d/ } @times ) < 2;

                my $trip
                  = Actium::Trip->new( { placetime_r => \@times, %fields } );

                $page->push_trips($trip);

            } ## <perltidy> end for my $this_line_idx (...)

        } ## <perltidy> end for my $page (@pages)

        emit_done;

        emit 'Dropping note-only pages: reduced from ' . scalar(@pages);

        @pages = grep {
            my $firstline = $_->line( $indexes{first} );
            $firstline !~ /^Notes:/s;
        } @pages;

        emit_prog( 'to ' . scalar(@pages) . ' pages' );

        emit_done;

        # keep only those pages where the first line is not Notes --
        # that is, drop all pages with no actual times

        return;

    } ## <perltidy> end sub parse_pages

    sub parse_notes {

        my $page         = shift;
        my $starting_idx = shift;

        my $prevnoteletter = '...';

        my %thispages_notes;

        for my $idx ( $starting_idx .. $page->line_count - 1 ) {
            my $line = $page->line($idx);
            next unless $line =~ /[^\s_=-]/s;
            my ( $noteletter, $notetext ) = unpack( 'x7A8x5A*', $line );

            if ($noteletter) {
                $thispages_notes{$noteletter} = $notetext;
                $prevnoteletter = $noteletter;
            }
            else {
                $thispages_notes{$prevnoteletter} .= " $notetext";
            }

        }

        foreach my $noteletter ( keys %thispages_notes ) {
            my $note_obj = Actium::SkedNote->new(
                {   origlinegroup => $page->origlinegroup(),
                    days          => $days,
                    noteletter    => $noteletter,
                    note          => $thispages_notes{$noteletter},
                }
            );

            push @notes, $note_obj;

        }

        return;

    } ## <perltidy> end sub parse_notes

    sub assemble_tall_pages {

        emit 'Combining pages with the same schedule';

        # I didn't add the "=2", "=3" etc. to the place8s, which was done
        # here in the old newsignup code.

        my $page_idx = 0;

      PAGE:
        while ( $page_idx < $#pages ) {

            # looks from page(0) to page(-2) -- never looks at page(-1), because
            # on page(-1) there are no further pages to assemble

         # I write "ld" meaning "origlinegroup_and_dir" here because, well, it's
         # shorter.

            my $page = $pages[$page_idx];
            my $ld   = $page->origlinegroup_and_dir();

            my $pages_to_combine = 0;

          NEXTPAGE:
            for my $nextpage_idx ( $page_idx + 1 .. $#pages ) {
                last NEXTPAGE
                  if (
                    ( $pages[$nextpage_idx] )->origlinegroup_and_dir() ne $ld );

                $pages_to_combine++;
            }

            # NEXTPAGE

            if ( not $pages_to_combine ) {
                $page_idx++;
                next PAGE;
            }

            my @thesepages
              = @pages[ $page_idx .. $page_idx + $pages_to_combine ];

            # array slice

            my @place8_refs = map {
                grep {defined}
                  $_->place8_r()
            } @thesepages;
            my @union_place8s = ordered_union(@place8_refs);

          EXPANDTPS:
            foreach my $pagetoexpand (@thesepages) {

                next unless defined( $pagetoexpand->place8_r() );

                my @theseplace8s = $pagetoexpand->place8s();

                next EXPANDTPS
                  if join( $EMPTY_STR, @theseplace8s ) eq
                      join( $EMPTY_STR, @union_place8s );

                my $current_place8_idx = 0;
                my $final_place8_idx   = $#theseplace8s;
                my $current_column     = 0;

              PLACE:
                foreach my $place_to_process (@union_place8s) {

                    # pad out the columns at the end
                    if ( $current_place8_idx > $final_place8_idx ) {
                        $page->insert_blank_final_column($current_place8_idx);
                        next PLACE;
                    }

                    my $current_place = $theseplace8s[$current_place8_idx];

                    if ( $place_to_process eq $current_place ) {
                        $current_place8_idx++;
                        $current_column++;
                    }
                    else {
                        $page->insert_blank_column_before($current_column);
                        $current_column++;
                    }

                } ## <perltidy> end foreach my $place_to_process...
                    # PLACE

            } ## <perltidy> end foreach my $pagetoexpand (@thesepages)
                    # EXPANDTPS

            # Combine pages

            $page->push_trips( $_->trips ) for @thesepages[ 1 .. $#thesepages ];
            $page->push_lines( $_->lines ) for @thesepages[ 1 .. $#thesepages ];
            splice( @pages, $page_idx + 1, $pages_to_combine );
            $page_idx++;

        } ## <perltidy> end while ( $page_idx < $#pages)
                    # PAGE

        emit_done;

        return;

    } ## <perltidy> end sub assemble_tall_pages

}    # block for scoping

sub combine_identical_trips {

    my @pages = @_;

    emit 'Combining identical trips';

    foreach my $page (@pages) {

        # go through each trip, from last to second-from-first. If the
        # one just before that is the same, delete the trip, and replace
        # the previous one with the new, combined trip

        my $i = $page->trip_count;
        while ( $i > 1 ) {
            $i--;    # so the last run will be when $i is 1

            my $trip     = $page->trip($i);
            my $prevtrip = $page->trip( $i - 1 );

            if ( j( $trip->placetimes ) eq j( $prevtrip->placetimes ) 
                 and $trip->routenum() eq $prevtrip->routenum() ) {

                # if the route number and all the placetimes 
                # are the same, the trip is the same.

                my $combined_trip
                  = Actium::Trip->merge_trips( $prevtrip, $trip );
                $page->set_trip( $i - 1, $combined_trip );
                $page->delete_trip($i);

            }

        }

    } ## <perltidy> end foreach my $page (@pages)

    emit_done;

    return;

} ## <perltidy> end sub combine_identical_trips

sub combine_duplicate_timepoints {

    # when you have two place names in a row, usually for
    # arrival / departure times

    my @pages = @_;

    my %seen_linegroups;

    emit 'Combining duplicate timepoints, by linegroup';

    foreach my $page (@pages) {

        my $lg = $page->origlinegroup();
        emit_over $lg unless $seen_linegroups{$lg}++;

        my @places = $page->place8s;

        my @runs_of_dupes = create_duplicate_timepoint_runs(@places);

        shrink_duplicate_timepoint_runs( $page, @runs_of_dupes );

        #  Now go through each set.

    }

    emit_done;

    return;

} ## <perltidy> end sub combine_duplicate_timepoints

sub create_skeds_from_pages {
    my @pages = @_;
    emit 'Making schedules from pages, by linegroup';
    my @skeds;
    
    my %seen;
    foreach my $page (@pages) {
        my $lg = $page->origlinegroup();
        emit_over $lg unless $seen{$lg}++;
        
        my $sked = $page->sked();
        push @skeds, $sked->divide_sked();
    }
    emit_done;
    return \@skeds;
}

sub create_duplicate_timepoint_runs {
    my @places = @_;

    # assemble runs of identical times
    my $prevplace         = $places[0];
    my $in_a_run_of_dupes = 0;

    my @runs;

  PLACE:
    for my $i ( 1 .. $#places ) {
        if ( $places[$i] ne $prevplace ) {
            $in_a_run_of_dupes = 0;
            $prevplace         = $places[$i];
            next PLACE;
        }

        if ( not $in_a_run_of_dupes ) {
            push @runs, { FIRSTCOL => $i - 1, LASTCOL => $i };
        }
        else {
            $runs[-1]{LASTCOL} = $i;
        }

        $in_a_run_of_dupes = 1;
    }

    return @runs;

} ## <perltidy> end sub create_duplicate_timepoint_runs

sub shrink_duplicate_timepoint_runs {
    my $page = shift;
    my @runs = @_;

    foreach my $run ( reverse @runs ) {

        my $firstcolumn = $run->{FIRSTCOL};
        my $lastcolumn  = $run->{LASTCOL};
        my $numcolumns  = $lastcolumn - $firstcolumn + 1;

        my $place = $page->place8($firstcolumn);

        my $has_double = 0;

        my ( @single_list, @double_list );

      TRIP:
        foreach my $trip ( $page->trips ) {

            my @alltimes = $trip->placetimes();

            my @thesetimes = sort { $a <=> $b }
              grep { defined($_) } @alltimes[ $firstcolumn .. $lastcolumn ];

            # so @thesetimes contains all the nonblank times
            # for this timepoint

            if ( not scalar @thesetimes ) {

                # no valid times
                push @single_list, undef;
                push @double_list, [ undef, undef ];
                next TRIP;
            }
            
            if ( scalar @thesetimes != 1 ) {

                @thesetimes
                  = @thesetimes[ 0, -1 ];    ## no critic 'ProhibitMagicNumbers'
                     # first and last only -- discard any middle times.
                     # Unlikely to actually happen

                if ( $thesetimes[0] == $thesetimes[1] ) {
                    @thesetimes = ( $thesetimes[0] ) ;

                    # if they're the same, just keep one.
                }

            }

            # now @thesetimes contains one time 
            # or two times that are different.

            if ( scalar @thesetimes == 2 ) {
                push @single_list, $thesetimes[1];
                push @double_list, [ @thesetimes ];
                $has_double = 1;
                next TRIP;
            }

            push @single_list, $thesetimes[0];

            # if this isn't the last column, and there are any times
            # defined later...
            if ( $#alltimes > $lastcolumn
                and any { defined($_) }
                @alltimes[ $lastcolumn + 1 .. $#alltimes ] )
            {
                # Then set the single time to be the departure time
                @thesetimes = ( undef, $thesetimes[0] );
            }
            else {
                # otherwise set it to be the arrival time
                @thesetimes = ( $thesetimes[0], undef );
            }

            push @double_list, [ @thesetimes ];

        } ## <perltidy> end foreach my $trip ( $page->trips)

        if ($has_double) {
            $page->splice_place8s( $firstcolumn, $numcolumns, $place, $place );
            foreach my $trip ( $page->trips ) {
               my $thesetimes_r = shift @double_list;
               my @thesetimes   = @{$thesetimes_r};
                $trip->splice_placetimes( $firstcolumn, $numcolumns, @thesetimes );
            }
        }
        else {
            $page->splice_place8s( $firstcolumn, $numcolumns, $place );
            foreach my $trip ( $page->trips ) {
                $trip->splice_placetimes( $firstcolumn, $numcolumns, shift @single_list );
            }
        }

    } ## <perltidy> end foreach my $run ( reverse @runs)

    return;

} ## <perltidy> end sub shrink_duplicate_timepoint_runs

sub write_prehistorics {

    emit 'Preparing prehistoric sked files';

    my $skeds_r = shift;

    my %prehistorics_of;

    emit 'Creating prehistoric file data';

    foreach my $sked ( @{$skeds_r} ) {
        my $group_dir = $sked->linegroup . q{_} . $sked->direction;
        my $days      = $sked->days();
        emit_over "${group_dir}_$days";
        $prehistorics_of{$group_dir}{$days} = $sked->prehistoric_skedsfile();
    }

    emit_done;

    # so now %{$prehistorics_of{$group_dir}} is a hash:
    # keys are days (WD, SU, SA)
    # and values are the full text of the prehistoric sked

    my %allprehistorics;

    my @comparisons
      = ( [qw/SA SU WE/], [qw/WD SA WA/], [qw/WD SU WU/], [qw/WD WE DA/], );

    emit 'Merging days';

    foreach my $group_dir ( sort keys %prehistorics_of ) {

        emit_over $group_dir;

        # merge days
        foreach my $comparison_r (@comparisons) {
            my ( $first_days, $second_days, $to ) = @{$comparison_r};

            next
              unless $prehistorics_of{$group_dir}{$first_days}
                  and $prehistorics_of{$group_dir}{$second_days};

            my $prefirst  = $prehistorics_of{$group_dir}{$first_days};
            my $presecond = $prehistorics_of{$group_dir}{$second_days};

            my ( $idfirst,  $bodyfirst )  = split( /\n/s, $prefirst,  2 );
            my ( $idsecond, $bodysecond ) = split( /\n/s, $presecond, 2 );

            if ( $bodyfirst eq $bodysecond ) {
                my $new = "${group_dir}_$to\n$bodyfirst";
                $prehistorics_of{$group_dir}{$to} = $new;
                delete $prehistorics_of{$group_dir}{$first_days};
                delete $prehistorics_of{$group_dir}{$second_days};
            }

        } ## <perltidy> end foreach my $comparison_r (@comparisons)

        # copy to overall list

        foreach my $days ( keys %{ $prehistorics_of{$group_dir} } ) {
            $allprehistorics{"${group_dir}_$days"}
              = $prehistorics_of{$group_dir}{$days};
        }

    } ## <perltidy> end foreach my $group_dir ( sort...)

    emit_done;

    writefilesfromhash( \%allprehistorics, 'prehistoric', 'txt' );

    emit_done;

    return;

} ## <perltidy> end sub write_prehistorics

1;

