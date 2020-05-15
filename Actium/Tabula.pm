# Actium/Tabula.pm

# Produces InDesign tag files that represent timetables.

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.012;

package Actium::Tabula 0.001;

use English '-no_match_vars';
use autodie;
use Actium::EffectiveDate ('effectivedate');
use Actium::Sorting ( 'sortbyline', 'byline' );
use Actium::Constants;
use Actium::Text::InDesignTags;
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

        my @tables;
        foreach my $line (@lines) {
            next unless $tables_of{$line};
            push @tables,
              sort { $a->sortable_id cmp $b->sortable_id }
              @{ $tables_of{$line} };
        }

        my $days_obj_of_r = _figure_days( \%tables_of, @lines );

        _output_pubtt_front_matter( $ttfh, \@lines, $front_matter{$pubtt},
            $days_obj_of_r, $effectivedate );

        my @tabletexts = map { $_->as_indesign } @tables;

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
          = uniq( map { $_->days_obj->daycode } @{ $tables_of_r->{line} } );
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

    return %days_obj_of;

} ## tidy end: sub _figure_days

my %front_style_of = ( '>' => 'CoverCity', );

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
        $length = max( map {length} @lines, scalar @lines );
        # longest line number, or if more routes than the number of
        # characters, use that instead

    }

    print $ttfh $idt->parastyle("CoverLine$length");
    print $ttfh join( $idt->boxbreak, @lines ), $idt->boxbreak;

    # EFFECTIVE DATE

    print $ttfh $idt->parastyle('CoverEffectiveBlack'), 'Effective:',
      $idt->hardreturn;
    print $ttfh $idt->parastyle('CoverDate'), $effectivedate, $idt->hardreturn;

    # WORK OUT NO LOCALS AND COVER DAYS

    my %has_local_value;
    foreach my $line (@lines) {
        if ( @TRANSBAY_NOLOCALS ~~ $line ) {
            $has_local_value{NoLocals} = 1;
        }
        else {
            $has_local_value{LocalsOK} = 1;
        }
    }
    my $mixed_locals = scalar keys %has_local_value > 1 ? 0 : 1;
    my @days = uniq( map { $_->as_sortable } values %days_obj_of );
    my $mixed_days = @days > 1;

    # COVER MATERIALS

    foreach my $front_text (@front_matter) {
        my $leading_char = substr( $front_text, 0, 1 );

        if ( not $front_style_of{$leading_char} ) {
            print $ttfh $idt->parastyle( 'CoverPlace', $front_text ),
              $idt->hardreturn;
            next;
        }

        $front_text = substr( $front_text, 1 );

        given ($leading_char) {
            when (':') {
                print $ttfh $idt->parastyle('CoverLineInDesc'), $front_text,
                  $idt->hardreturn;
                print $ttfh _local_text($front_text) if $mixed_locals;
                print $ttfh $days_obj_of{$front_text}->as_plurals 
                  if $mixed_days;
            }
            when ('>') {
                print $ttfh $idt->parastyle( $front_style_of{$leading_char} ),
                  $idt->hardreturn;
            }
        }

    } ## tidy end: foreach my $front_text (@front_matter)

    print $ttfh $idt->boxbreak;

    print $ttfh _local_text( $lines[0] ) unless $mixed_locals;
    print $ttfh $days_obj_of{$lines[0]}->as_plurals  unless $mixed_days;

    return;

} ## tidy end: sub _output_pubtt_front_matter

sub _local_text {
    my $linegroup = shift;

    if ( $linegroup ~~ @TRANSBAY_NOLOCALS ) {
        return $idt->parastyle('CoverLocalPax')
          . 'No Local Passengers Permitted';
    }

    if ( $linegroup eq '800' or $linegroup =~ /\A [A-Z]/sx ) {
        return $idt->parastyle('CoverLocalPax') . 'Local Passengers Allowed';
    }

    return $EMPTY_STR;

}

1;

__END__

# initialization

use IDTags (qw<boxbreak parastyle charstyle>);
use Skedfile qw(Skedread getfiles GETFILES_PUBLIC_AND_DB);
use Skedvars qw(%longerdaynames %daydirhash %dirhash %dayhash %specdaynames);
use Array::Transpose;
use Actium::Signup;
use Actium::Sorting('sortbyline');
use List::Util ('max');
use List::MoreUtils('uniq');
use Actium::Files::Merge::FPMerge qw(FPread_simple);
use Actium::Time          ('timenum');
use Actium::EffectiveDate ('effectivedate');
use Actium::Constants;
use Actium::Sked::Days;

#use Data::Dumper;

use constant CR => "\r";


sub START {

    my $signup     = Actium::Signup->new();
    my $tabulaedir = $signup->subfolder('tabulae');
    my $bigdir     = $tabulaedir->subfolder('big');
    my $smalldir   = $tabulaedir->subfolder('small');

    chdir( $signup->path );

    my %front_matter = _get_configuration($signup);

    my ( @timepoints, %timepoints );
    FPread_simple( 'Timepoints.csv', \@timepoints, \%timepoints, 'Abbrev9' );

    my @files = getfiles(GETFILES_PUBLIC_AND_DB);

    my %tags = indesign_tags();

    my %tables_of_line;

    foreach my $file (@files) {
        my $table_r   = make_table( $file, \%timepoints );
        my $linegroup = $table_r->{LINEGROUP};
        my $dirday    = $table_r->{DIRDAY};
        $tables_of_line{$linegroup}{$dirday} = $table_r;
    }

    my $boxwidth  = 4.5;        # table columns in box
    my $boxheight = 49 * 12;    # points in box

    for my $linegroup ( sortbyline keys %tables_of_line ) {
        print "$linegroup ";

        my @texts;
        my @heights;
        my @widths;
        my $specdayscol;
        my %days_of_linegroup;

        foreach my $dirday ( keys %{ $tables_of_line{$linegroup} } ) {

            $tables_of_line{$linegroup}{$dirday}{SORTBY}
              = _sort_by( \%tables_of_line, $linegroup, $dirday );

            $days_of_linegroup{$linegroup} = figure_days(
                map { $tables_of_line{$linegroup}{$_}{DAY} }
                  keys %{ $tables_of_line{$linegroup} }
            );

        }

        foreach my $dirday (

            #sort { $daydirhash{$a} <=> $daydirhash{$b} }

            sort {
                $tables_of_line{$linegroup}{$a}{SORTBY}
                  cmp $tables_of_line{$linegroup}{$b}{SORTBY}
            }

            keys %{ $tables_of_line{$linegroup} }
          )
        {

            push @texts,   $tables_of_line{$linegroup}{$dirday}{TEXT};
            push @heights, $tables_of_line{$linegroup}{$dirday}{HEIGHT};
            push @widths,  $tables_of_line{$linegroup}{$dirday}{WIDTH};
            $specdayscol = 1
              if $tables_of_line{$linegroup}{$dirday}{SPECDAYSCOL};
        }

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

        open my $out, '>', "tabulae/$size/$linegroup.txt"
          or die "Can't open tabulae/$size/$linegroup.txt: $!";
        print $out $tags{start};

        my ($lglength) = length($linegroup);
        print $out parastyle( "CoverLine$lglength", $linegroup );
        print $out boxbreak;

        if ( exists $front_matter{$linegroup} ) {
            print $out parastyle( 'CoverEffectiveBlack', 'Effective:', CR );
            print $out parastyle( 'CoverDate', effectivedate($signup), CR );

            foreach my $front_line ( @{ $front_matter{$linegroup} } ) {
                if ( substr( $front_line, 0, 1 ) eq '>' ) {
                    print $out parastyle( 'CoverCity',
                        substr( $front_line, 1 ) );
                }
                else {
                    print $out parastyle( 'CoverPlace', $front_line );
                }
                print $out CR;
            }

        }
        else {
            print $out parastyle( 'CoverPlace', 'No front matter defined' );
        }
        print $out boxbreak;

        my $days = $days_of_linegroup{$linegroup};
        $days =~ s/except/\rExcept/sx;

        print $out parastyle( 'CoverNote', $days ), CR;

        #        print $out parastyle(
        #            'CoverNote',
        #            join(
        #                CR,
        #                'Monday through Friday',
        #                'Except holidays',
        #                #                'Commute hours only' )
        #            )
        #          ),
        #          CR;

        if ( $linegroup ~~ @TRANSBAY_NOLOCALS ) {
            print $out parastyle( 'CoverLocalPax',
                'No Local Passengers Permitted' );
        }
        elsif ( $linegroup =~ /\A [A-Z]/sx ) {
            print $out parastyle( 'CoverLocalPax', 'Local Passengers Allowed' );
        }

        print $out boxbreak;

        print $out join( CR, @texts );
        close $out;

    } ## tidy end: for my $linegroup ( sortbyline...)

    print "\n";

    my @texts;

    my $maxwidth  = 0;
    my $maxheight = 0;

    for my $linegroup ( sortbyline keys %tables_of_line ) {

        foreach my $dirday (

            #            sort { $daydirhash{$a} <=> $daydirhash{$b} }
            sort {
                $tables_of_line{$linegroup}{$a}{SORTBY}
                  cmp $tables_of_line{$linegroup}{$b}{SORTBY}
            }
            keys %{ $tables_of_line{$linegroup} }
          )
        {
            push @texts, $tables_of_line{$linegroup}{$dirday}{TEXT};
            $maxwidth
              = max( $maxwidth, $tables_of_line{$linegroup}{$dirday}{WIDTH} );
            $maxheight
              = max( $maxheight, $tables_of_line{$linegroup}{$dirday}{HEIGHT} );
        }

    } ## tidy end: for my $linegroup ( sortbyline...)

    open my $out, '>', "tabulae/all.txt"
      or die "Can't open tabulae/all.txt: $!";
    print $out $tags{start}, join( IDTags::boxbreak, @texts );
    close $out;

    $maxheight = $maxheight / 72;    # inches instead of points

    say "Maximum height in inches: $maxheight; maximum columns: $maxwidth";

} ## tidy end: sub START

sub make_all_tables {
 
  
 
}

sub make_table {
    my $file       = shift;
    my %timepoints = %{ +shift };

    # open files and print InDesign start tag
    my %sked      = %{ Skedread($file) };
    my $skedname  = $sked{SKEDNAME};
    my $linegroup = $sked{LINEGROUP};
    my $dir       = $sked{DIR};
    my $day       = $sked{DAY};

    my %specdays_used;

    # get number of columns and rows

    my @tps = @{ $sked{TP} };

    s/=[0-9]+$// foreach @tps;

    my $tpcount = scalar @tps;

    my $halfcols = 0;

    my ( $has_route_col, $has_specdays_col );

    my %seenroutes;
    $seenroutes{$_} = 1 foreach @{ $sked{ROUTES} };
    my @seenroutes = sortbyline keys %seenroutes;

    if ( ( scalar @seenroutes ) != 1 ) {
        $halfcols++;
        $has_route_col = 1;
    }

    my $routechars
      = length( join( '', @seenroutes ) ) + ( 3 * ($#seenroutes) ) + 1;

    # number of characters in routes, plus three characters -- space bullet
    # space -- for each route except the first one, plus a final space

    my $bullet
      = '<0x2009><CharStyle:SmallRoundBullet><0x2022><CharStyle:><0x2009>';
    my $routetext = join( $bullet, @seenroutes );

    my $dayname = $longerdaynames{ $sked{DAY} };

    my %seenspecdays;
    $seenspecdays{$_} = 1 foreach @{ $sked{SPECDAYS} };
    if ( ( scalar keys %seenspecdays ) != 1 ) {
        $halfcols++;
        $has_specdays_col = 1;
    }
    else {
        my ( $specdays, $count ) = each %seenspecdays;    # just one
        if ($specdays) {
            $dayname = $specdaynames{$specdays};
        }
    }

    my $colcount = $tpcount + $halfcols ;
    # +1 for end column, added to allow more space

    my %tpname_of;
    $tpname_of{$_} = $timepoints{$_}{TPName} foreach (@tps);
    my $destination = $timepoints{ $tps[-1] }{DestinationF} || $tps[-1];

    my $timerows = scalar( @{ $sked{ROUTES} } );

    print $skedname ;
    print " (", join( " ", sort keys %seenroutes ), ")"
      if scalar keys %seenroutes > 1;
    print ", $tpcount";
    print "+$halfcols" if $halfcols;
    say " x $timerows";

    my $rowcount = $timerows + 2;    # headers

    my $tabletext;
    open my $th, '>', \$tabletext
      or die "Can't open table scalar for writing: $!";

    # Table Start
    print $th IDTags::parastyle('UnderlyingTables');
    print $th '<TableStyle:TimeTable>';
    print $th "<TableStart:$rowcount,$colcount,2,0<tCellDefaultCellType:Text>>";
    print $th '<ColStart:<tColAttrWidth:24>>'
      for ( 1 .. $halfcols );
    print $th '<ColStart:<tColAttrWidth:48>>'
      for ( 1 .. $tpcount );

    # Header Row (line, days, dest)
    print $th '<RowStart:<tRowAttrHeight:43.128692626953125>>';
    print $th '<CellStyle:ColorHeader><StylePriority:2>';
    print $th "<CellStart:1,$colcount>";
    print $th IDTags::parastyle('dropcaphead');
    print $th "<pDropCapCharacters:$routechars>$routetext ";
    print $th IDTags::charstyle('DropCapHeadDays');
    print $th $dayname;
    print $th IDTags::nocharstyle, '<0x000A>';
    print $th IDTags::charstyle( 'DropCapHeadDest', "\cGTo $destination" )
      ;                                          # control-G is "Insert to Here"
    print $th IDTags::nocharstyle, '<CellEnd:>';

    for ( 2 .. $colcount ) {
        print $th '<CellStyle:ColorHeader><CellStart:1,1><CellEnd:>';
    }
    print $th '<RowEnd:>';

    # Timepoint Name Row

    print $th
      '<RowStart:<tRowAttrHeight:35.5159912109375><tRowAttrMinRowSize:3>>';

    if ($has_route_col) {
        print $th
'<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>Line<CellEnd:>';
    }
    if ($has_specdays_col) {
        print $th
'<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>Note<CellEnd:>';
    }
    for my $i ( 0 .. $#tps ) {
        my $tp = $tps[$i];
        my $tpname = $timepoints{$tp}{TPName} || $tp;
        if ( $i != 0 and $tps[ $i - 1 ] eq $tp ) {
            $tpname = "Leaves $tpname";
        }
        elsif ( $i != $#tps and $tps[ $i + 1 ] eq $tp ) {
            $tpname = "Arrives $tpname";
        }
        print $th
"<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>$tpname<CellEnd:>";
    }

    print $th '<RowEnd:>';

    # Time Rows

    my @timerows = Array::Transpose::transpose $sked{TIMES};

    for my $i ( 0 .. $#timerows ) {
        my @row = @{ $timerows[$i] };

        print $th '<RowStart:<tRowAttrHeight:10.5159912109375>>';

        if ($has_route_col) {
            my $route = $sked{ROUTES}[$i];
            print $th
"<CellStyle:LineNote><StylePriority:20><CellStart:1,1><ParaStyle:Time>$route<CellEnd:>";
        }
        if ($has_specdays_col) {
            my $specdays = $sked{SPECDAYS}[$i];
            print $th
"<CellStyle:LineNote><StylePriority:20><CellStart:1,1><ParaStyle:Time>$specdays<CellEnd:>";
            $specdays_used{$specdays} = 1;
        }

        for my $j ( 0 .. $#row ) {
            my $time      = $row[$j];
            my $parastyle = 'Time';
            if ($time) {
                substr( $time, -3, 0 ) = ":";    # add colon
            }
            else {
                $time      = IDTags::emdash;
                $parastyle = 'LineNote';
            }
            print $th
"<CellStyle:Time><StylePriority:20><CellStart:1,1><ParaStyle:$parastyle>";
            if ( $time =~ /p\z/ ) {
                print $th IDTags::bold($time);
            }
            else {
                print $th $time;
            }
            print $th '<CellEnd:>';
        } ## tidy end: for my $j ( 0 .. $#row )

        print $th '<RowEnd:>';

    } ## tidy end: for my $i ( 0 .. $#timerows)

    # Table End
    print $th "<TableEnd:>\r";

    foreach my $specdays ( keys %specdays_used ) {
        given ($specdays) {
            when ('SD') {
                print $th "\rSD - School days only";
            }
            when ('SH') {
                print $th "\rSH - School holidays only";
            }

        }

    }

    close $th;

    my $dirday = "${dir}_$day";

    my %table;

    $table{LINEGROUP} = $linegroup;
    $table{DIRDAY}    = $dirday;

    $table{DAY}          = $day;
    $table{DIR}          = $dir;
    $table{EARLIESTTIME} = timenum( Skedfile::earliest_time( \%sked ) );
    $table{TEXT}         = $tabletext;
    $table{SPECDAYSCOL}  = $has_specdays_col;
    $table{ROUTECOL}     = $has_route_col;
    $table{WIDTH}        = $tpcount + ( $halfcols / 2 );
    $table{HEIGHT} = ( 3 * 12 ) + 6.136    # 3p6.136 height of color header
      + ( 3 * 12 ) + 10.016                # 3p10.016 four-line timepoint header
      + ( $timerows * 10.516 );            # p10.516 time cell

    return \%table;
} ## tidy end: sub make_table

sub indesign_tags {

    my %tags;
    $tags{start}
      = "<ASCII-MAC>\r<Version:6><FeatureSet:InDesign-Roman><DefineParaStyle:Time=><DefineParaStyle:dropcaphead=><DefineTableStyle:TimeTable=><DefineCellStyle:ColorHeader=><DefineCharStyle:DropCapHeadDays=>";

    return %tags;

}

sub _sort_by {
    my $tables_of_line_r = shift;
    my $linegroup        = shift;
    my $dirday           = shift;

    my $dir = $tables_of_line_r->{$linegroup}{$dirday}{DIR};
    my $day = $tables_of_line_r->{$linegroup}{$dirday}{DAY};

    my $time;
    if ( exists( $tables_of_line_r->{$linegroup}{"${dir}_WD"} ) ) {
        $time = $tables_of_line_r->{$linegroup}{"${dir}_WD"}{EARLIESTTIME};
    }
    else {
        $time = $tables_of_line_r->{$linegroup}{$dirday}{EARLIESTTIME};
    }

    my $dayval = $dayhash{$day} // '00';

    return
      join( "\0", Actium::Sorting::linekeys( $dayval, $time, $dirhash{$dir} ) );

} ## tidy end: sub _sort_by




1;

__END__

