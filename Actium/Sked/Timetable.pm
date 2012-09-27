# Actium/Sked/Timetable.pm

# Object representing the data in a timetable to be displayed to the user.
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

use HTML::Entities;

my $timesub = Actium::Time::timestr_sub();
# Uses default values. Someday it would be nice to make that configurable

has sked_obj => (
    isa      => 'Actium::Sked',
    is       => 'ro',
    required => 1,
    handles  => {
        linegroup        => 'linegroup',
        has_note_col     => 'has_multiple_daysexceptions',
        has_route_col    => 'has_multiple_lines',
        header_routes    => 'lines',
        sortable_id      => 'sortable_id',
        id => 'id',
        earliest_timenum => 'earliest_timenum',
        days_obj         => 'days_obj',
        dircode          => 'dircode',
        linedir          => 'linedir',
        linedays         => 'linedays',

      }

);
# At one point I thought this object could be contained by the sked object
# rather than the other way around, but it can't because I need the xml
# data to make this object, and the sked object doesn't know it.

has [qw <half_columns columns>] => (
    isa      => 'Int',
    is       => 'ro',
    required => 1,
);

#has 'linegroup' => (
#    isa => 'Str',
#    is => 'ro',
#    required => 1,
#    );

#has 'header_route_r' => (
#    traits   => ['Array'],
#    is       => 'bare',
#    isa      => 'ArrayRef[Str]',
#    required => 1,
#    handles  => { header_routes => 'elements', },
#);
#
#has [qw <has_route_col has_note_col>] => (
#    is       => 'ro',
#    isa      => 'Bool',
#    required => 1,
#);

has [qw <header_dirtext header_daytext>] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has header_columntext_r => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Str]',
    required => 1,
    handles  => { header_columntexts => 'elements', },
);

has note_definitions_r => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Str]',
    required => 1,
    handles  => { note_definitions => 'elements', },
);

has body_rowtext_rs => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[ArrayRef[Str]]',
    required => 1,
    handles  => {
        body_row_rs    => 'elements',
        body_row_count => 'count',
    },
);

#has [qw<sortable_id earliest_timenum days_obj>] => (
#   is => 'ro',
#   required => 1,
#   );

sub new_from_sked {

    my $class  = shift;
    my $sked   = shift;
    my $xml_db = shift;

    my %spec;

    $spec{sked_obj} = $sked;

    # ASCERTAIN COLUMNS

    my $has_multiple_lines          = $sked->has_multiple_lines;
    my $has_multiple_daysexceptions = $sked->has_multiple_daysexceptions;

    # TODO allow for other timepoint notes

    my @place9s = $sked->place9s;

    my $halfcols = 0;
    $halfcols++ if $has_multiple_lines;

    my @note_definitions;

    if ($has_multiple_daysexceptions) {
        $halfcols++;
        foreach my $daysexceptions ( $sked->daysexceptions ) {

            given ($daysexceptions) {
                when ('SD') {
                    push @note_definitions, 'SD - School days only';
                }
                when ('SH') {
                    push @note_definitions, 'SH - School holidays only';
                }

            }

        }

    }

    $spec{note_definitions_r} = \@note_definitions;

    $spec{half_columns} = $halfcols;
    $spec{columns}      = scalar @place9s;

    # HEADERS

    #    $spec{header_route_r} = [ $sked->routes ];

    #$spec{days_obj} = $sked->days_obj;
    #$spec{linegroup} = $sked->linegroup;

    $spec{header_daytext} = $sked->days_obj->as_plurals;

    my @timepoint_structs = $xml_db->timepoints_structs;
    my %timepoint_row_of  = %{ $timepoint_structs[2] };    # Abbrev9
    my @header_columntexts;

    push @header_columntexts, 'Line' if $has_multiple_lines;
    push @header_columntexts, 'Note' if $has_multiple_daysexceptions;

    # TODO - allow for place4 or at least place8 instead of place9

    for my $i ( 0 .. $#place9s ) {
        my $place9 = $place9s[$i];
        my $tpname = $timepoint_row_of{$place9}{TPName};

        if ( $i != 0 and $place9s[ $i - 1 ] eq $place9 ) {
            $tpname = "Leaves $tpname";
        }
        elsif ( $i != $#place9s and $place9s[ $i + 1 ] eq $place9 ) {
            $tpname = "Arrives $tpname";
        }
        push @header_columntexts, $tpname;

    }

    $spec{header_columntext_r} = \@header_columntexts;

    $spec{header_dirtext}
      = $sked->to_text
      . $SPACE
      . $timepoint_row_of{ $place9s[-1] }{DestinationF};

    # BODY

    #    $spec{earliest_timenum} = $sked->earliest_timenum;
    #    $spec{sortable_id} = $sked->sortable_id;

    my @body_rows;

    foreach my $trip ( $sked->trips ) {
        my @row;
        if ($has_multiple_lines) {
            push @row, $trip->line;
        }

        if ($has_multiple_daysexceptions) {
            push @row, $trip->daysexceptions;
        }

        foreach my $timenum ( $trip->placetimes ) {
            push @row, $timesub->($timenum);
        }

        push @body_rows, \@row;

    }

    $spec{body_rowtext_rs} = \@body_rows;

    return $class->new( \%spec );

} ## tidy end: sub new_from_sked

use Actium::Text::InDesignTags;

my $idt = 'Actium::Text::InDesignTags';

sub as_indesign {

    my $self = shift;

    my $minimum_columns  = shift || 0;
    my $minimum_halfcols = shift || 0;

    my $columns  = $self->columns;
    my $halfcols = $self->half_columns;

    my ( $trailing_columns, $trailing_halves )
      = _minimums( $columns, $halfcols, $minimum_columns, $minimum_halfcols );

    my $trailing = $trailing_columns + $trailing_halves;
    my @trailers = ($EMPTY_STR) x $trailing;

    my $rowcount = $self->body_row_count + 2;          # 2 header rows
    my $colcount = $columns + $halfcols + $trailing;

    ##############
    # Table Start

    my $tabletext;
    open my $th, '>', \$tabletext
      or die "Can't open table scalar for writing: $!";

    print $th $idt->parastyle('UnderlyingTables');
    print $th $idt->tablestyle('TimeTable');
    print $th '<TableStart:';
    print $th join( ',', $rowcount, $colcount, 2, 0 );
    print $th '<tCellDefaultCellType:Text>>';
    print $th '<ColStart:<tColAttrWidth:24>>' for ( 1 .. $halfcols );
    print $th '<ColStart:<tColAttrWidth:48>>'
      for ( 1 .. $columns + $trailing_columns );
    print $th '<ColStart:<tColAttrWidth:24>>' for ( 1 .. $trailing_halves );

    ##############
    # Header Row (line, days, dest)

    my @routes = $self->header_routes;
    my $routechars = length( join( '', @routes ) ) + ( 3 * ($#routes) ) + 1;

    # number of characters in routes, plus three characters -- space bullet
    # space -- for each route except the first one, plus a final space

    my $bullet
      = '<0x2009><CharStyle:SmallRoundBullet><0x2022><CharStyle:><0x2009>';
    my $routetext = join( $bullet, @routes );

    my $header_style = _get_header_style( $routes[0] );

    print $th '<RowStart:<tRowAttrHeight:43.128692626953125>>';
    print $th "<CellStyle:$header_style><StylePriority:2>";
    print $th "<CellStart:1,$colcount>";
    print $th $idt->parastyle('dropcaphead');
    print $th "<pDropCapCharacters:$routechars>$routetext ";
    print $th $idt->charstyle('DropCapHeadDays');
    print $th "\cG", $self->header_daytext;
    print $th $idt->nocharstyle, '<0x000A>';
    print $th $idt->charstyle('DropCapHeadDest'),
      , $self->header_dirtext;    # control-G is "Indent to Here"
    print $th $idt->nocharstyle, '<CellEnd:>';

    #    for ( 2 .. $colcount ) {
    #        print $th '<CellStyle:$header_style><CellStart:1,1><CellEnd:>';
    #    }
    print $th '<RowEnd:>';

    ##############
    # Column Header Row (line, note, timepoints)

    my $has_line_col = $self->has_route_col;
    my $has_note_col  = $self->has_note_col;

    my @header_columntexts = ( $self->header_columntexts, @trailers );

    print $th
      '<RowStart:<tRowAttrHeight:35.5159912109375><tRowAttrMinRowSize:3>>';

    # The following is written this way so that in future, we can decide to
    # treat Note and Line with special graphic treatment (italics, color, etc.)

    if ($has_line_col) {
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

    ##############
    # Time Rows

    for my $body_row_r ( $self->body_row_rs ) {
        my @body_row = @{$body_row_r};

        print $th '<RowStart:<tRowAttrHeight:10.5159912109375>>';

        if ($has_line_col) {
            my $route = shift @body_row;

            print $th
"<CellStyle:LineNote><StylePriority:20><CellStart:1,1><ParaStyle:LineNote>$route<CellEnd:>";
        }
        if ($has_note_col) {
            my $note = shift @body_row;
            print $th
"<CellStyle:LineNote><StylePriority:20><CellStart:1,1><ParaStyle:LineNote>$note<CellEnd:>";
        }

        for my $time (@body_row) {

            my $parastyle = 'Time';
            if ( !$time ) {
                $time      = $idt->emdash;
                $parastyle = 'LineNote';
            }
            print $th
"<CellStyle:Time><StylePriority:20><CellStart:1,1><ParaStyle:$parastyle>";
            if ( $time =~ /p\z/ ) {
                print $th $idt->char_bold, $time, $idt->nocharstyle;
            }
            else {
                print $th $time;
            }
            print $th '<CellEnd:>';
        }

        for ( 1 .. $trailing ) {
            print $th
"<CellStyle:Time><StylePriority:20><CellStart:1,1><ParaStyle:LineNote> <CellEnd:>";
        }

        print $th '<RowEnd:>';

    } ## tidy end: for my $body_row_r ( $self...)

    ###############
    # Table End

    print $th "<TableEnd:>";

    foreach my $note_definition ( $self->note_definitions ) {
        print $th "\r$note_definition";
    }

    close $th;

    return $tabletext;

} ## tidy end: sub as_indesign

sub _get_header_style {

    # TODO - this shouldn't be here, it should be specified in a database
    # or something

    my $route = shift;

    return 'ColorHeader' if $route =~ /\A DB /;

    return 'GreyHeader' if $route =~ /\A 6\d\d \z/sx;
    return 'TransbayHeader' if $route =~ /\A [A-Z] /sx or $route eq '800';

    return 'ColorHeader';

}

sub _minimums {

    my ( $columns, $halfcols, $minimum_columns, $minimum_halfcols ) = @_;

    # adjust so it's a proper fraction (no more than one halfcol)

    #$minimum_columns += int($minimum_halfcols/2);
    #$minimum_halfcols = $minimum_halfcols % 2;

    #$columns += int($halfcols/2);
    #$halfcols = $halfcols % 2;

    my $length         = $columns * 2 + $halfcols;
    my $minimum_length = $minimum_columns * 2 + $minimum_halfcols;

    return ( 0, 0 ) unless $minimum_length > $length;

    my $length_to_add = $minimum_length - $length;

    my $trailing_halves  = $length_to_add % 2;
    my $trailing_columns = int( $length_to_add / 2 );

    return ( $trailing_columns, $trailing_halves );

} ## tidy end: sub _minimums

sub as_html {
    my $self = shift;

    my $columns  = $self->columns;
    my $halfcols = $self->half_columns;
    
    my $all_columns = $columns + $halfcols;
    
    my $tabletext;
    open my $th, '>', \$tabletext
      or die "Can't open table scalar for writing: $!";
      
    print $th '<table class="sked"><thead>';
      
    ### ROUTE NUMBERS

    print $th qq{<tr\n><th class="skedhead" colspan=$all_columns>};
    print $th '<div class="skedheaddiv">';
    print $th '<div class="skedroute">';
    
    my @routes = map { encode_entities ($_) } $self->header_routes;
    print $th join (' &bull; ' , @routes) ;
    print $th '</div>';
    
    print $th '<div class="skeddest">';
    
    # ROUTE DESTINATION AND DIRECTION
    
    print $th encode_entities( $self->header_daytext);
    print $th '<br />';
    print $th encode_entities( $self->header_dirtext);
    print $th "</div></th></tr></thead><tbody\n>";
    
    ##############
    # Column Header Row (line, note, timepoints)

    my $has_line_col = $self->has_route_col;
    my $has_note_col  = $self->has_note_col;

    my @header_columntexts = map {encode_entities $_} ( $self->header_columntexts);

    print $th "<tr\n>";

    # The following is written this way so that in future, we can decide to
    # treat Note and Line with special graphic treatment (italics, color, etc.)

    if ($has_line_col) {
        my $header = shift @header_columntexts;
        print $th qq{<th class="lineheader">$header</th>};
    }

    if ($has_note_col) {
        my $header = shift @header_columntexts;
        print $th qq{<th class="noteheader">$header</th>};
    }

    for my $headertext (@header_columntexts) {
        print $th qq{<th class="timepointheader">$headertext</th>};
    }

    print $th "</tr\n>";

    ##############
    # Time Rows

    for my $body_row_r ( $self->body_row_rs ) {
        my @body_row = map {encode_entities($_) } @{$body_row_r};

        print $th "<tr\n>";

        if ($has_line_col) {
            my $line = shift @body_row;

            print $th qq{<td class="line">$line</td>};

        }
        if ($has_note_col) {
            my $note = shift @body_row;
            print $th qq{<td class="note">$note</td>};
        }

        for my $time (@body_row) {

            if ( !$time ) {
                $time      = '&mdash;';
            }
            
            if ( $time =~ /p\z/ ) {
                print $th "<td class='pmtime'>$time";
            }
            else {
                print $th "<td class='amtime'>$time";
            }
            print $th '</td>';
        }

        print $th "</tr\n>";

    } ## tidy end: for my $body_row_r ( $self...)

    ###############
    # Table End

    print $th "</tbody></table>\n";

    foreach my $note_definition ( $self->note_definitions ) {
        print $th "<p>$note_definition</p>";
    }

    close $th;
      
    return $tabletext;

}

1;

