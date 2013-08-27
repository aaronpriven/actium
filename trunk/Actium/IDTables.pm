# Actium/IDTables.pm

# Produces InDesign tag files that represent timetables.

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.012;

package Actium::IDTables 0.001;

use English '-no_match_vars';
use autodie;
use Text::Trim;
use Actium::EffectiveDate ('effectivedate');
use Actium::Sorting::Line ( 'sortbyline', 'byline' );
use Actium::Sorting::Skeds('skedsort');
use Actium::Constants;
use Actium::Text::InDesignTags;
use Actium::Text::CharWidth ( 'ems', 'char_width' );
use Actium::O::Folders::Signup;
use Actium::Term;
use Actium::O::Sked;
use Actium::O::Sked::Timetable;
use Actium::Util(qw/doe in chunks population_stdev/);
use Const::Fast;
use List::Util ( 'max', 'sum' );
use List::MoreUtils (qw<uniq pairwise natatime each_arrayref>);
use Algorithm::Combinatorics ('combinations');

const my $IDT        => 'Actium::Text::InDesignTags';
const my $SOFTRETURN => $IDT->softreturn;

use Actium::IDTables::PageAssignments;

# saves typing

sub create_timetable_texts {

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

} ## tidy end: sub create_timetable_texts

sub output_all_tables {

    emit "Outputting all tables into all.txt";

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

    emit_done;

} ## tidy end: sub output_all_tables

sub get_pubtt_contents {
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

} ## tidy end: sub get_pubtt_contents

sub output_pubtts {

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
              $table->as_indesign(
                minimum_columns  => $min_columns,
                minimum_halfcols => $min_half_columns
              );
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

} ## tidy end: sub output_pubtts

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

sub output_m_pubtts {

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

        my @table_assignments
          = Actium::IDTables::PageAssignments::assign($tables_r);

        if ( not @table_assignments ) {
            emit_prog "*";
            next;
        }

        open my $ttfh, '>', $pubtt_folder->make_filespec("$file.txt");

        print $ttfh $IDT->start;

        _output_pubtt_front_matter( $ttfh, $tables_r, $lines_r, [],
            $effectivedate );

        my $firsttable    = 1;
        my $current_frame = 0;

        foreach my $table_assignment (@table_assignments) {

            my $table      = $table_assignment->{table};
            my $width      = $table_assignment->{width};
            my $frame      = $table_assignment->{frame};
            my $pagebreak  = $table_assignment->{pagebreak};
            my $compressed = $table_assignment->{compressed};

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
                compressed       => $compressed,
            );

            $firsttable = 0;

        } ## tidy end: foreach my $table_assignment...

        # End matter, if there is any, goes here

        close $ttfh;

    } ## tidy end: foreach my $pubtt (@pubtt_contents)

    emit_done;

} ## tidy end: sub output_m_pubtts

1;

__END__

