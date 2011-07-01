# Actium/Tabula.pm

# Produces InDesign tag files that represent timetables.

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.012;

package Actium::Tabula 0.001;

use English '-no_match_vars';
use autodie;
use Text::Trim;
use Actium::EffectiveDate ('effectivedate');
use Actium::Sorting ( 'sortbyline', 'byline' );
use Actium::Constants;
use Actium::Text::InDesignTags;
use Actium::Text::CharWidth ('char_width');
use Actium::Signup;
use Actium::Term;
use Actium::Sked;
use Actium::Sked::Timetable;
use Readonly;
use List::Util      ('max');
use List::MoreUtils ('uniq');

Readonly my $idt => 'Actium::Text::InDesignTags';
# saves typing

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
tabula. Reads schedules and makes tables out of them.
HELP

    Actium::Term::output_usage();

    return;
}

sub START {

    my $signup         = Actium::Signup->new();
    my $tabulae_folder = $signup->subfolder('tabulae-test');
    my $pubtt_folder   = $tabulae_folder->subfolder('pubtt');

    my $xml_db = $signup->load_xml;

    my $prehistorics_folder = $signup->subfolder('skeds');

    chdir( $signup->path );

    my %front_matter = _get_configuration($signup);

    emit "Loading prehistoric schedules";

    my @skeds
      = Actium::Sked->load_prehistorics( $prehistorics_folder, $xml_db );

    emit_done;

    @skeds = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->sortable_id() ] } @skeds;

    emit "Creating timetable texts";

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

    emit_done;

    _output_all_tables( $tabulae_folder, \@alltables );
    _output_pubtts( $pubtt_folder, \%front_matter, \%tables_of, $signup );

} ## tidy end: sub START

sub _output_all_tables {

    emit "Outputting all tables into all.txt";

    my $tabulae_folder = shift;
    my $alltables_r    = shift;

    #$alltables_r =  [ (@{$alltables_r})[0..50] ]; # debug

    open my $allfh, '>', $tabulae_folder->make_filespec('all.txt');

    print $allfh $idt->start;
    foreach my $table ( @{$alltables_r} ) {
        print $allfh $table->as_indesign, $idt->boxbreak;
    }

    close $allfh;

    emit_done;

} ## tidy end: sub _output_all_tables

sub _get_configuration {

    my $signup   = shift;
    my $filespec = $signup->make_filespec('tabula-config.txt');

    open my $config_h, '<', $filespec
      or die "Can't open $filespec for reading: $OS_ERROR";

    my %front_matter;
    my $timetable;

  LINE:
    while ( my $line = <$config_h> ) {
        chomp $line;
        next LINE unless $line;
        if ( substr( $line, 0, 1 ) eq '[' ) {
            $timetable = ( substr( $line, 1 ) );
        }
        else {
            next LINE unless $timetable;
            push @{ $front_matter{$timetable} }, $line;
        }
    }

    close $config_h
      or die "Can't close $filespec for writing: $OS_ERROR";

    return %front_matter;

} ## tidy end: sub _get_configuration

sub _output_pubtts {

    emit "Outputting public timetable files";

    my $pubtt_folder = shift;
    my %front_matter = %{ +shift };
    my %tables_of    = %{ +shift };
    my $signup       = shift;

    my $effectivedate = effectivedate($signup);

    foreach my $pubtt ( sortbyline( keys %front_matter ) ) {

        my $file = $pubtt;
        $file =~ s/ /_/g;

        emit_prog "$file ";

        open my $ttfh, '>', $pubtt_folder->make_filespec("$file.txt");

        print $ttfh Actium::Text::InDesignTags->start;

        my @lines = sortbyline( split( ' ', $pubtt ) );

        my %minimums_of_line;

        my @tables;
        foreach my $line (@lines) {
            next unless $tables_of{$line};
            my @these_tables = sort { $a->sortable_id cmp $b->sortable_id }
              @{ $tables_of{$line} };

            $minimums_of_line{$line}{half_columns}
              = max( map { $_->half_columns } @these_tables );
            $minimums_of_line{$line}{columns}
              = max( map { $_->columns } @these_tables );

            push @tables, @these_tables;

        }

        my $days_obj_of_r = _figure_days( \%tables_of, @lines );

        _output_pubtt_front_matter( $ttfh, \@lines, $front_matter{$pubtt},
            $days_obj_of_r, $effectivedate );

        print $ttfh $idt->boxbreak;

        my @tabletexts;
        foreach my $table (@tables) {
            my $min_half_columns
              = $minimums_of_line{ $table->linegroup }{half_columns};
            my $min_columns = $minimums_of_line{ $table->linegroup }{columns};

            if ( $min_columns * 2 + $min_half_columns <= 9 ) {

                $min_half_columns = 1;
                $min_columns      = 4;

            }

            push @tabletexts,
              $table->as_indesign( $min_columns, $min_half_columns );
        }

        print $ttfh join( ( $idt->hardreturn x 2 ), @tabletexts );

        # End matter, if there is any, goes here

        close $ttfh;

    } ## tidy end: foreach my $pubtt ( sortbyline...)

    emit_done;

} ## tidy end: sub _output_pubtts

sub _figure_days {

    my $tables_of_r = shift;
    my @lines       = @_;

    my %days_obj_of;

    foreach my $line (@lines) {
        my @daycodes
          = uniq( map { $_->days_obj->daycode } @{ $tables_of_r->{$line} } );
        my @schooldaycodes = uniq( map { $_->days_obj->schooldaycode }
              @{ $tables_of_r->{line} } );

        my $catschooldaycode;
        if ( @schooldaycodes == 1 ) {
            $catschooldaycode = $schooldaycodes[0];
        }
        else { $catschooldaycode = 'B'; }

        my $catdaycode = join( $EMPTY_STR, sort @daycodes );
        $catdaycode = join $EMPTY_STR, ( uniq sort ( split //, $catdaycode ) );
        $days_obj_of{$line}
          = Actium::Sked::Days->new( $catdaycode, $catschooldaycode );

    }

    return \%days_obj_of;

} ## tidy end: sub _figure_days

my %front_style_of = (
    '>' => 'CoverCity',
    '}' => 'CoverCitySm',
    ':' => 'CoverLineInDesc',
    ';' => 'CoverLineInDesc',
    '|' => 'CoverNote',
    '*' => 'CoverLocalPax',

);

sub _output_pubtt_front_matter {

    my $ttfh          = shift;
    my @lines         = @{ +shift };
    my @front_matter  = @{ +shift };
    my %days_obj_of   = %{ +shift };
    my $effectivedate = shift;

    # ROUTES

    my $length;

    if ( @lines == 1 ) {
        $length = length( $lines[0] );
    }
    else {
        #$length = max( map {length} @lines, scalar @lines );

        $length = max( map { char_width($_) } @lines, scalar @lines );

        # longest line number in ems, or if more routes than the number of
        # characters, use that instead

    }

    print $ttfh $idt->parastyle("CoverLine$length");
    print $ttfh join( $idt->hardreturn, @lines ), $idt->boxbreak;

    # EFFECTIVE DATE

    print $ttfh $idt->parastyle('CoverEffectiveBlack'), 'Effective:',
      $idt->hardreturn;
    print $ttfh $idt->parastyle('CoverDate'), $effectivedate;

    # NO LOCALS AND COVER DAYS

    my %has_local_value;
    foreach my $line (@lines) {
        if ( @TRANSBAY_NOLOCALS ~~ $line ) {
            $has_local_value{NoLocals} = 1;
        }
        else {
            $has_local_value{LocalsOK} = 1;
        }
    }
    my $mixed_locals = ( scalar keys %has_local_value ) > 1;
    my @days         = uniq( map { $_->as_sortable } values %days_obj_of );
    my $mixed_days   = @days > 1;

    # COVER MATERIALS

    foreach my $front_text (@front_matter) {
     
        print $ttfh $idt->hardreturn;
        
        my $leading_char = substr( $front_text, 0, 1 );

        if ( not $front_style_of{$leading_char} ) {
            print $ttfh $idt->parastyle('CoverPlace'), $front_text ;
            next;
        }

        $front_text = substr( $front_text, 1 );
        trim($front_text);

        print $ttfh $idt->parastyle( $front_style_of{$leading_char} ),
          $front_text;
          

        if ( $leading_char eq ':' ) {

            print $ttfh _local_text($front_text)
              if $mixed_locals;
            print $ttfh $idt->parastyle('CoverNote'),
              $days_obj_of{$front_text}->as_plurals
              if $mixed_days;
        } elsif ($leading_char eq '*') { $mixed_locals = 1 }
         

    } ## tidy end: foreach my $front_text (@front_matter)

    print $ttfh $idt->boxbreak;

    print $ttfh _local_text( $lines[0] )
      unless $mixed_locals;
    print $ttfh $idt->parastyle('CoverNote'),
      $days_obj_of{ $lines[0] }->as_plurals
      unless $mixed_days;

    return;

} ## tidy end: sub _output_pubtt_front_matter

sub _local_text {
    my $linegroup = shift;

    if ( $linegroup ~~ @TRANSBAY_NOLOCALS ) {
        return $idt->parastyle('CoverLocalPax') . 'No Local Passengers Allowed';
    }

    if ( $linegroup eq '800' or $linegroup =~ /\A [A-Z]/sx ) {
        return $idt->parastyle('CoverLocalPax') . 'Local Passengers Permitted';
    }

    return $EMPTY_STR;

}

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




