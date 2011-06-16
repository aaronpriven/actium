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

use Actium::Time;
use Actium::Constants;

my $timesub = Actium::Time::timestr_sub();
# Someday it would be nice to make that configurable

has [qw <half_columns columns trailing_halves trailing_columns sum_of_columns>]
  => {
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

has [ qw <has_route_col has_note_col> ]  => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
);

has [qw <header_dirtext header_daytext>] => {
    is  => 'ro',
    isa => 'Str',
    required => 1,
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
    handles  => {
        body_row_rs    => 'elements',
        body_row_count => 'count',
    },
};

sub new_from_sked {

    my $class  = shift;
    my $sked   = shift;
    my $xml_db = shift;

    my $minimum_columns  = shift || 0;
    my $minimum_halfcols = shift || 0;

    my %spec;

    # ASCERTAIN COLUMNS

    my $has_multiple_routes         = $sked->has_multiple_routes;
    my $has_multiple_daysexceptions = $sked->has_multiple_daysexceptions;
    
    $spec{has_note_col} = $has_multiple_daysexceptions;
    $spec{has_route_col} = $has_multiple_routes;

    # TODO allow for other timepoint notes

    my $halfcols = 0;
    $halfcols++ if $has_multiple_routes;
    $halfcols++ if $has_multiple_daysexceptions;

    my $sum = ( $spec{half_columns} = $halfcols );

    my $trailing_halves = $minimum_halfcols > $halfcols ? $minimum_halfcols : 0;
    $sum += ( $spec{trailing_halves} = $trailing_halves );

    my $columns = $sked->place_count;
    my $trailing_columns
      = $minimum_columns > $columns ? $minimum_columns - $columns : 0;

    $sum += ( $spec{trailing_columns} = $trailing_columns );
    $sum += ( $spec{columns}          = $columns );
    $spec{sum_of_columns} = $sum;

    # HEADERS

    $spec{header_route_r} = [ $sked->routes ];

    $spec{header_daytext} = $sked->days_obj->as_plurals;

    my @timepoint_structs = $xml_db->timepoints_structs;
    my %timepoint_row_of  = $timepoint_structs[2];         # Abbrev9
    my @header_columntexts;

    push @header_columntexts, 'Line' if $has_multiple_routes;
    push @header_columntexts, 'Note' if $has_multiple_daysexceptions;

    my @place9s = $sked->place9s;

    # TODO - allow for place4 or at least place8 instead of place9
    
    # TODO - Add arrives/departs text
    foreach my $place9 (@place9s) {
        push @header_columntexts, $timepoint_row_of{$place9}{TPName};
    }
    
#            if ( $i != 0 and $tps[ $i - 1 ] eq $tp ) {
#            $tpname = "Leaves $tpname";
#        }
#        elsif ( $i != $#tps and $tps[ $i + 1 ] eq $tp ) {
#            $tpname = "Arrives $tpname";
#        }

    push @header_columntexts,
      ($EMPTY_STR) x ( $spec{trailing_halves} + $spec{trailing_columns} );

    $spec{header_columntext_r} = \@header_columntexts;

    $spec{header_dirtext}
      = $sked->to_text 
      . $SPACE
      . $timepoint_row_of{ $place9s[-1] }{DestinationF};

    # BODY

    my @body_rows;

    foreach my $trip ( $sked->trips ) {
        my @row;
        if ($has_multiple_routes) {
            push @row, $trip->routenum;
        }

        if ($has_multiple_daysexceptions) {
            push @row, $trip->dayexception;
        }

        foreach my $timenum ( $trip->placetimes ) {
            push @row, $timesub->($timenum);
        }

        push @row,
          ($EMPTY_STR) x ( $spec{trailing_halves} + $spec{trailing_columns} );
    }

    $spec{body_rowtext_rs} = \@body_rows;

    return $class->new( \%spec );

} ## tidy end: sub new_from_sked

use IDTags;

sub as_indesign {

    my $self = shift;
    my $tabletext;
    open my $th, '>', \$tabletext
      or die "Can't open table scalar for writing: $!";

    my $rowcount = $self->body_row_count + 2; # 2 header rows
    my $colcount = $self->sum_of_columns;
    
    ##############
    # Table Start

    print $th IDTags::parastyle('UnderlyingTables');
    print $th '<TableStyle:TimeTable>';
    print $th
      "<TableStart:$self->$rowcount,$colcount,2,0<tCellDefaultCellType:Text>>";
    print $th '<ColStart:<tColAttrWidth:24>>' for ( 1 .. $self->half_columns );
    print $th '<ColStart:<tColAttrWidth:48>>'
      for ( 1 .. $self->columns + $self->trailing_columns );
    print $th '<ColStart:<tColAttrWidth:24>>'
      for ( 1 .. $self->trailing_halves );

    ##############
    # Header Row (line, days, dest)
    
    my @routes = $self->header_routes;
    my $routechars = length( join( '', @routes ) ) + ( 3 * ($#routes) ) + 1;

    # number of characters in routes, plus three characters -- space bullet
    # space -- for each route except the first one, plus a final space

    my $bullet
      = '<0x2009><CharStyle:SmallRoundBullet><0x2022><CharStyle:><0x2009>';
    my $routetext = join( $bullet, @routes );

    print $th '<RowStart:<tRowAttrHeight:43.128692626953125>>';
    print $th '<CellStyle:ColorHeader><StylePriority:2>';
    print $th "<CellStart:1,$colcount>";
    print $th IDTags::parastyle('dropcaphead');
    print $th "<pDropCapCharacters:$routechars>$routetext ";
    print $th IDTags::charstyle('DropCapHeadDays');
    print $th $self->header_daytext;
    print $th IDTags::nocharstyle, '<0x000A>';
    print $th IDTags::charstyle( 'DropCapHeadDest', '\cG',
        $self->header_dirtext );    # control-G is "Insert to Here"
    print $th IDTags::nocharstyle, '<CellEnd:>';

    for ( 2 .. $colcount ) {
        print $th '<CellStyle:ColorHeader><CellStart:1,1><CellEnd:>';
    }
    print $th '<RowEnd:>';
    
    ##############
    # Column Header Row (line, note, timepoints)
    
    my $has_route_col = $self->has_route_col;
    my $has_note_col = $self->has_note_col;
    
    my @header_columntexts = $self->header_columntexts;
    
    print $th
      '<RowStart:<tRowAttrHeight:35.5159912109375><tRowAttrMinRowSize:3>>';

    if ($has_route_col) {
        my $header = shift @header_columntexts;
        print $th
"<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>$header<CellEnd:>";
    }
    
    if ($has_note_col) {
        my $header = shift @header_columntexts;
        print $th
"<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>$header<CellEnd:>";
    }
    
    for my $headertext (@header_columntexts) {
        print $th
"<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>$headertext<CellEnd:>";
    }

    print $th '<RowEnd:>';
    

} ## tidy end: sub as_indesign

__END__
    
    


    

    my $timerows = scalar( @{ $sked{ROUTES} } );

    print $skedname ;
    print " (", join( " ", sort keys %seenroutes ), ")"
      if scalar keys %seenroutes > 1;
    print ", $tpcount";
    print "+$halfcols" if $halfcols;
    say " x $timerows";

    my $rowcount = $timerows + 2;    # headers



    # Timepoint Name Row

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
