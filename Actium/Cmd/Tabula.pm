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
use Actium::Folders::Signup;
use Actium::Term;
use Actium::Sked;
use Actium::Sked::Timetable;
use Actium::Util(qw/doe in/);
use Const::Fast;
use List::Util ('max');
use List::MoreUtils ( 'uniq', 'each_arrayref' );

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

    my $signup         = Actium::Folders::Signup->new();
    my $tabulae_folder = $signup->subfolder('tabulae');
    my $pubtt_folder   = $tabulae_folder->subfolder('pubtt');

    my $xml_db = $signup->load_xml;

    my $prehistorics_folder = $signup->subfolder('skeds');

    chdir( $signup->path );

    # my %front_matter = _get_configuration($signup);


    my @skeds = Actium::Sked->load_prehistorics( $prehistorics_folder, $xml_db );

    #my @all_lines = map { $_->lines } @skeds;
    my @all_lines = _get_all_lines(@skeds);

    @all_lines = sortbyline uniq @all_lines;
    my $pubtt_contents_r = _get_pubtt_contents( $xml_db, \@all_lines );


    @skeds = _sort_skeds(@skeds);

    my ( $alltables_r, $tables_of_r )
      = _create_timetable_texts( $xml_db, @skeds );

    _output_all_tables( $tabulae_folder, $alltables_r );
    _output_pubtts( $pubtt_folder, $pubtt_contents_r, $tables_of_r, $signup );

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

        my $table = Actium::Sked::Timetable->new_from_sked( $sked, $xml_db );
        push @{ $tables_of{$linegroup} }, $table;
        push @alltables, $table;
    }

    emit_over $EMPTY_STR;
    emit_done;

    return \@alltables, \%tables_of;

} ## tidy end: sub _create_timetable_texts

sub _get_all_lines {
    my @skeds = @_;
    my @all_lines = map { $_->lines } @skeds;
    return @all_lines;
}

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

    @pubtt_contents = sort { byline( $a->[0], $b->[0] ) } @pubtt_contents;
    
    require Data::Dumper;
    
    return \@pubtt_contents;

} ## tidy end: sub _get_pubtt_contents

#sub _get_configuration {
#
#    my $signup   = shift;
#    my $filespec = $signup->make_filespec('tabula-config.txt');
#
#    open my $config_h, '<', $filespec
#      or die "Can't open $filespec for reading: $OS_ERROR";
#
#    my %front_matter;
#    my $timetable;
#
#  LINE:
#    while ( my $line = <$config_h> ) {
#        chomp $line;
#        next LINE unless $line;
#        if ( substr( $line, 0, 1 ) eq '[' ) {
#            $timetable = ( substr( $line, 1 ) );
#        }
#        else {
#            next LINE unless $timetable;
#            push @{ $front_matter{$timetable} }, $line;
#        }
#    }
#
#    close $config_h
#      or die "Can't close $filespec for writing: $OS_ERROR";
#
#    return %front_matter;
#
#} ## tidy end: sub _get_configuration

#sub _debug_remove_all_but_l {
#
#    return grep { $_->[0] =~ /^L/} @_;
#
#}

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

        print $ttfh $IDT->boxbreak;

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
    
    if ($lines[0] eq 'FS') {
       emit_prog '.'; ## DEBUG
    }

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
        $days_obj_of{$line} = Actium::Sked::Days->union( @{$days_objs_r} );
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

1;

__END__

# initialization

    my $boxwidth  = 4.5;        # table columns in box
    my $boxheight = 49 * 12;    # points in box

    
        my $size = 'small';

        given ( scalar @heights ) {
            when (1) {
                $size = 'big'
                  if $heights[0] > $boxheight
                      or $widths[0] > $boxwidth;
            }
            when (2) {

                $size = 'big'
                  unless $heights[0] + $heights[1] + 18 < $boxheight
                      and $widths[0] < $boxwidth * 2
                      and $widths[1] < $boxwidth * 2

                      # they fit up and down
                      or $widths[0] + $widths[1] < $boxwidth
                      and $heights[0] < $boxheight
                      and $heights[1] < $boxheight;

                # or they fit side by side
            }
            default {    # TODO - figure out for larger sizes
                $size = 'big';
            }
        } ## tidy end: given

    $maxheight = $maxheight / 72;    # inches instead of points

    say "Maximum height in inches: $maxheight; maximum columns: $maxwidth";

} ## tidy end: sub START


    $table{HEIGHT} = ( 3 * 12 ) + 6.136    # 3p6.136 height of color header
      + ( 3 * 12 ) + 10.016                # 3p10.016 four-line timepoint header
      + ( $timerows * 10.516 );            # p10.516 time cell

    return \%table;
} ## tidy end: sub make_table




