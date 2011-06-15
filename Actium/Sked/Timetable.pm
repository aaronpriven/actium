# Actium/Sked/Timetable.pm

# Object representing the data in a displayed timetable.
# Designed to take an Actium::Sked object and make it displayable.

# Subversion:  $Id$

# legacy status: 4 (mostly)

use 5.012;
use warnings;

package Actium::Sked::Timetable 0.001;

use Moose;
use MooseX::StrictConstructor;

has [qw <half_columns columns trailing_halves trailing_columns>] => {
    isa => 'Int',
    is  => 'ro',
};

has 'header_route_r' => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Str]',
    required => 1,
    handles  => { header_routes => 'elements', },
);

has [qw <header_dirtext header_daytext>] => {
    is  => 'ro',
    isa => 'Str',
};

has header_columntext_r => {
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Str]',
    required => 1,
    handles  => { header_columntexts => 'elements', },
};

has body_rowtext_rs => {
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[ArrayRef[Str]]',
    required => 1,
    handles  => { body_row_rs => 'elements' },
};

sub new_from_sked {

    my $class            = shift;
    my $sked             = shift;
    my $xml_db           = shift;
    my $minimum_columns  = shift || 0;
    my $minimum_halfcols = shift || 0;

    my %dimensions
      = get_dimensons( $sked, $minimum_columns, $minimum_halfcols );

}

sub get_dimensions {

    my ( $sked, $minimum_columns, $minimum_halfcols ) = @_;

    my %dimensions;

    my $halfcols = 0;
    $halfcols++ if $sked->has_multiple_routes;
    $halfcols++ if $sked->has_multiple_daysexceptions;

    $dimensions{LEADINGHALF} = $halfcols;
    $dimensions{TRAILINGHALF}
      = $minimum_halfcols > $halfcols ? $minimum_halfcols : 0;

    my $columns = $sked->place_count;
    $dimensions{TRAILINGCOLS}
      = $minimum_columns > $columns ? $minimum_columns - $columns : 0;
    $dimensions{COLUMNS} = $columns;

    $dimensions{ROWS} = $sked->trip_count;

    return %dimensions;

} ## tidy end: sub get_dimensions

__END__
    
    
    
    my $routechars
      = length( join( '', @seenroutes ) ) + ( 3 * ($#seenroutes) ) + 1;

    # number of characters in routes, plus three characters -- space bullet
    # space -- for each route except the first one, plus a final space

    my $bullet
      = '<0x2009><CharStyle:SmallRoundBullet><0x2022><CharStyle:><0x2009>';
    my $routetext = join( $bullet, @seenroutes );

    my $dayname = $self->days_obj->as_plurals;
    

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



1;
