package Actium::IDTables 0.012;

use 5.020;
use warnings;    ### DEP ###

use English '-no_match_vars';
use autodie;
use Text::Trim;    ### DEP ###
use Actium::Crier(qw/cry last_cry/);
use Actium::O::DateTime;
use Actium::Sorting::Line ( 'sortbyline', 'byline' );
use Actium::Sorting::Skeds('skedsort');
use Actium::Constants;
use Actium::Text::InDesignTags;
use Actium::Text::CharWidth ( 'ems', 'char_width' );
use Actium::O::Sked;
use Actium::O::Sked::Timetable;
use Actium::Util(qw/in jointab population_stdev/);
use Const::Fast;    ### DEP ###
use List::Util ( 'max', 'sum' );    ### DEP ###
use List::MoreUtils (qw<uniq pairwise natatime each_arrayref>);    ### DEP ###
use Algorithm::Combinatorics ('combinations');                     ### DEP ###

const my $IDT        => 'Actium::Text::InDesignTags';
const my $SOFTRETURN => $IDT->softreturn;
# saves typing

use Actium::IDTables::PageAssignments;

sub create_timetable_texts {

    my $cry = cry("Creating timetable texts");

    my $db_obj = shift;
    my @skeds  = @_;

    my ( %tables_of, @alltables );
    my $prev_linegroup = $EMPTY;
    foreach my $sked (@skeds) {

        my $linegroup = $sked->linegroup;
        if ( $linegroup ne $prev_linegroup ) {
            $cry->over("$linegroup ");
            $prev_linegroup = $linegroup;
        }

        my $table = Actium::O::Sked::Timetable->new_from_sked( $sked, $db_obj );
        push @{ $tables_of{$linegroup} }, $table;
        push @alltables, $table;

    }

    $cry->over($EMPTY);
    $cry->done;

    return \@alltables, \%tables_of;

} ## tidy end: sub create_timetable_texts

sub output_all_tables {

    my $cry = cry("Outputting all tables into all.txt");

    my $tabulae_folder = shift;
    my $alltables_r    = shift;

    #$alltables_r =  [ (@{$alltables_r})[0..50] ]; # debug

    open my $allfh, '>', $tabulae_folder->make_filespec('all.txt');

    print $allfh $IDT->start;
    foreach my $table ( @{$alltables_r} ) {
        print $allfh $table->as_indesign(
            minimum_columns  => 4,
            minimum_halfcols => 0
          ),
          $IDT->boxbreak;
    }
    # minimum 4 columns, no half columns

    close $allfh;

    $cry->done;

} ## tidy end: sub output_all_tables

sub get_pubtt_contents_with_dates {
    my $db_obj  = shift;
    my $lines_r = shift;

    $db_obj->ensure_loaded('Lines');
    my $on_timetable_from_db_r
      = $db_obj->all_in_columns_key(qw/Lines PubTimetable TimetableDate/);

    my %on_timetable_of;

    foreach my $line (@$lines_r) {
        my $fromdb = $on_timetable_from_db_r->{$line}{'PubTimetable'};
        if ( defined $fromdb and $fromdb ne $EMPTY ) {
            push @{ $on_timetable_of{$fromdb} }, $line;
        }
        else {
            push @{ $on_timetable_of{$line} }, $line;
        }
    }

    my @pubtt_contents_with_dates;

    for my $lines_r ( values %on_timetable_of ) {
        my @lines = @{$lines_r};

        my $date_obj = $db_obj->effective_date( lines => \@lines );

        my $date      = $date_obj->long_en;
        my $file_date = $date_obj->ymd('_');
        push @pubtt_contents_with_dates,
          { lines     => [ sortbyline @lines ],
            date      => $date,
            file_date => $file_date
          };

    }

    $db_obj->ensure_loaded('PubTimetables');

    my @pubtimetable_cols = $db_obj->columns_of_table('PubTimetables');

    my $pubtimetables_r
      = $db_obj->all_in_columns_key( 'PubTimetables', @pubtimetable_cols );

    return [ sort { byline( $a->{lines}->[0], $b->{lines}->[0] ) }
          @pubtt_contents_with_dates ], $pubtimetables_r;

} ## tidy end: sub get_pubtt_contents_with_dates

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

    #@tables = sort { $a->sortable_id cmp $b->sortable_id } @tables;
    @tables = skedsort @tables;
    # skedsort makes sure that all timetables with same line & direction
    # are sorted the same way

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
    my $effectivedate = shift // $EMPTY;

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

    print $ttfh $per_line_texts_r->{$EMPTY}
      if exists $per_line_texts_r->{$EMPTY};

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
        return { $EMPTY => $days_obj_of{ $lines[0] } };
    }

    my @days_objs = values %days_obj_of;
    my @days_codes = uniq( map { $_->as_sortable } @days_objs );

    if ( @days_codes == 1 ) {
        return { $EMPTY => $days_objs[0] };
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
        return { $EMPTY => $locals[0] };
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

    return $EMPTY;

}

sub _make_length {

    my @lines = @_;

    my $ems = max( ( map { ems($_) } @lines ) );

    my $length;
    for ($ems) {
        if ( $_ <= 1 ) {    # two digits are 1.112
            $length = 1;
            next;
        }
        if ( $_ <= 1.5 ) {    # three digits are 1.332
            $length = 2;
            next;
        }
        if ( $_ <= 1.8 ) {    # NXC is 2, NX3 1.95
            $length = 3;
            next;
        }

        $length = 4;

    }

    return max( $length, scalar @lines );
} ## tidy end: sub _make_length

sub output_a_pubtts {

    my $cry = cry("Outputting public timetable files for Applescript");

    my $pubtt_folder              = shift;
    my @pubtt_contents_with_dates = @{ +shift };
    my $pubtimetables_r           = shift;
    my %tables_of                 = %{ +shift };
    my $signup                    = shift;

    my %script_entries;
    my @over_eight_pages;

    foreach my $pubtt_content_r (@pubtt_contents_with_dates) {
        my $pubtt         = $pubtt_content_r->{lines};
        my $linegroup     = $pubtt->[0];
        my $effectivedate = $pubtt_content_r->{date} // $EMPTY;
        my $file_date     = $pubtt_content_r->{file_date} // $EMPTY;
        my $dbentry       = $pubtimetables_r->{$linegroup};
        my $leave_cover_for_map
          = ( ( $dbentry->{LeaveCoverForMap} // 'No' ) eq 'Yes' );

        my ( $tables_r, $lines_r ) = _tables_and_lines( $pubtt, \%tables_of );
        next unless @$tables_r;

        my $file = join( "_", @{$lines_r} );
        $cry->over(" $file");

        my ( $portrait_chars, @table_assignments )
          = Actium::IDTables::PageAssignments::assign( $tables_r,
            $leave_cover_for_map );

        if ( not @table_assignments ) {
            $cry->text("Can't place $file on pages (too many timepoints?)");
            next;
        }

        open my $ttfh, '>', $pubtt_folder->make_filespec("$file.txt");

        print $ttfh $IDT->start;

        _output_pubtt_front_matter( $ttfh, $tables_r, $lines_r, [],
            $effectivedate );

        my $firsttable      = 1;
        my $current_frame   = 0;
        my $pagebreak_count = 0;

        foreach my $table_assignment (@table_assignments) {

            my $table       = $table_assignment->{table};
            my $width       = $table_assignment->{width};
            my $frame       = $table_assignment->{frame};
            my $pagebreak   = $table_assignment->{pagebreak};
            my $compression = $table_assignment->{compression};

            $pagebreak_count++ if $pagebreak;

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

            print $ttfh $table->as_indesign(
                minimum_columns  => $width->[0],
                minimum_halfcols => $width->[1],
                compression      => $compression,
            );

            $firsttable = 0;

        } ## tidy end: foreach my $table_assignment...

        # End matter, if there is any, goes here

        close $ttfh;

        my $has_short_page = not( $table_assignments[0]{pagebreak} );

        $script_entries{$linegroup} = {
            file             => $file,
            effectivedate    => $file_date,
            pages            => $pagebreak_count,
            MapFile          => $dbentry->{MapFile} // $EMPTY,
            LeaveCoverForMap => $leave_cover_for_map,
            MasterPage       => $dbentry->{MasterPage} // $EMPTY,
            has_short_page   => $has_short_page,
            portrait_chars   => $portrait_chars,
        };

    } ## tidy end: foreach my $pubtt_content_r...

    my $listfh  = $pubtt_folder->open_write('_ttlist.txt');
    my @columns = qw<file effectivedate pages MapFile LeaveCoverForMap
      MasterPage has_short_page portrait_chars>;
    say $listfh jointab(@columns);
    for my $linegroup ( sortbyline keys %script_entries ) {
        say $listfh jointab( @{ $script_entries{$linegroup} }{@columns} );
    }
    close $listfh;

    $cry->over($EMPTY);
    $cry->done;

    # $cry->text( "Has more than eight pages: @over_eight_pages");
    $cry->done;

} ## tidy end: sub output_a_pubtts

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

