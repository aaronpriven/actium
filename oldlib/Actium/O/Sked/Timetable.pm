package Actium::O::Sked::Timetable 0.012;

# Object representing the data in a timetable to be displayed to the user.
# Designed to take an Actium::O::Sked object and make it displayable.

use Actium ('class');

use Actium::Time;
use Actium::Text::InDesignTags;

const my $idt => 'Actium::Text::InDesignTags';

use HTML::Entities;    ### DEP ###

has sked_obj => (
    isa      => 'Actium::O::Sked',
    is       => 'ro',
    required => 1,
    handles  => {
        linegroup => 'linegroup',
        #has_note_col                    => 'has_multiple_daysexceptions',
        has_note_col                    => 'has_multiple_specdays',
        specday_count                   => 'specday_count',
        has_route_col                   => 'has_multiple_lines',
        header_routes                   => 'lines',
        lines                           => 'lines',
        sortable_id                     => 'sortable_id',
        id                              => 'id',
        earliest_timenum                => 'earliest_timenum',
        days_obj                        => 'days_obj',
        dircode                         => 'dircode',
        should_preserve_direction_order => 'should_preserve_direction_order',
        linedir                         => 'linedir',
        linedays                        => 'linedays',
        daycode                         => 'daycode',
        sortable_id_with_timenum        => 'sortable_id_with_timenum',
      }

);

# At one point I thought this object could be contained by the sked object
# rather than the other way around, but it can't because I need info from the
# Actium database to make this object, and the sked object doesn't know it.

has [qw <half_columns columns>] => (
    isa      => 'Int',
    is       => 'ro',
    required => 1,
);

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

has height => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    builder => '_build_height',
);

sub _build_height {
    my $self = shift;
    return $self->body_row_count;

}

has width_in_halfcols => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    builder => '_build_width_in_halfcols'
);

sub _build_width_in_halfcols {
    my $self = shift;
    return ( 2 * $self->columns + $self->half_columns );
}

#has [qw<sortable_id earliest_timenum days_obj>] => (
#   is => 'ro',
#   required => 1,
#   );

sub dimensions_for_display {
    my $self          = shift;
    my $displaywidth  = sprintf( '%.1f', $self->width_in_halfcols / 2 );
    my $displayheight = $self->height;
    return "$displaywidth columns x $displayheight rows";
}

has linegrouptype => (
    is  => 'ro',
    isa => 'Str',
);

has linegrouptype_rgbhex => (
    is  => 'ro',
    isa => 'Str',
);

my %note_definition_of = (

    MZ => 'MZ - Mondays, Wednesdays, and Fridays only',
    TT => 'TT - Tuesdays and Thursdays only',
    F  => 'F - Fridays only',
    SD => 'SD - School days only',
    SH => 'SH - School holidays only',

);

sub new_from_sked {

    my $class    = shift;
    my $sked     = shift;
    my $actiumdb = shift;

    my %spec;

    $spec{sked_obj} = $sked;

    # ASCERTAIN COLUMNS

    my $has_multiple_lines    = $sked->has_multiple_lines;
    my $has_multiple_specdays = $sked->has_multiple_specdays;

    # TODO allow for other timepoint notes

    my @place4s = $sked->place4s;

    my $halfcols = 0;
    $halfcols++ if $has_multiple_lines;

    my @note_definitions;

    if ($has_multiple_specdays) {
        $halfcols++;
        foreach my $specday_definition ( $sked->specday_definitions ) {
            push @note_definitions, $specday_definition;
        }

    }

    $spec{note_definitions_r} = \@note_definitions;

    $spec{half_columns} = $halfcols;
    $spec{columns}      = scalar @place4s;

    # HEADERS

    #    $spec{header_route_r} = [ $sked->routes ];

    #$spec{days_obj} = $sked->days_obj;
    #$spec{linegroup} = $sked->linegroup;

    my $linegroup_row_r = $actiumdb->line_row_r( $sked->linegroup );
    my $linegrouptype   = $linegroup_row_r->{LineGroupType};
    $spec{linegrouptype} = $linegrouptype;

    my $linegrouptype_row_r = $actiumdb->linegrouptype_row_r($linegrouptype);
    $spec{linegrouptype_rgbhex} = $linegrouptype_row_r->{RGBHex};

    $spec{header_daytext} = $sked->days_obj->as_plurals;

    my $places_r = $actiumdb->all_in_columns_key(
        qw/Places_Neue c_description c_destination /);

    my @header_columntexts;

    push @header_columntexts, 'Line' if $has_multiple_lines;
    push @header_columntexts, 'Note' if $has_multiple_specdays;

    for my $i ( 0 .. $#place4s ) {
        my $place4 = $place4s[$i];
        my $tpname = $places_r->{$place4}{c_description};

        if ( $i != 0 and $place4s[ $i - 1 ] eq $place4 ) {
            $tpname = "Leaves $tpname";
        }
        elsif ( $i != $#place4s and $place4s[ $i + 1 ] eq $place4 ) {
            $tpname = "Arrives $tpname";
        }
        push @header_columntexts, $tpname;

    }

    $spec{header_columntext_r} = \@header_columntexts;

    $spec{header_dirtext}
      = $sked->to_text . $SPACE . $places_r->{ $place4s[-1] }{c_destination};

    # BODY

    #    $spec{earliest_timenum} = $sked->earliest_timenum;
    #    $spec{sortable_id} = $sked->sortable_id;

    my @body_rows;

    foreach my $trip ( $sked->trips ) {
        my @row;
        if ($has_multiple_lines) {
            push @row, $trip->line;
        }

        if ($has_multiple_specdays) {
            my ( $specdayletter, $specday ) = $trip->specday( $sked->days_obj );
            push @row, $specdayletter // $EMPTY;
        }

        foreach my $timenum ( $trip->placetimes ) {
            push @row, Actium::Time->from_num($timenum)->ap;
        }

        push @body_rows, \@row;

    }

    $spec{body_rowtext_rs} = \@body_rows;

    return $class->new( \%spec );

}    ## tidy end: sub new_from_sked

const my @COMPRESSION_SETTINGS => (
    # 0
    {   col_points     => 48,
        halfcol_points => 24,
        timestyle      => 'Time',
        timepointstyle => 'Timepoints',
    },
    # 1
    {   col_points     => 40,
        halfcol_points => 20,
        timestyle      => 'CompressedTime',
        timepointstyle => 'CompressedTimepoints',
    },
    # 2
    {   col_points     => 38.9,
        halfcol_points => 19.45,
        timestyle      => 'CompressedTime',
        timepointstyle => 'CompressedTimepoints',
    }
);

sub as_indesign {

    my $self = shift;

    my %params = u::validate(
        @_,
        {   minimum_columns  => 1,
            minimum_halfcols => 1,
            compression      => { default => 0 },
            lower_bound      => { default => 0 },
            upper_bound      => { default => ( $self->body_row_count - 1 ) },
            firstpage        => { default => 1 },
            finalpage        => { default => 1 },
        }
    );

    #my $minimum_columns  = $params{minimum_columns};
    #my $minimum_halfcols = $params{minimum_halfcols};

    \my %compression_setting = $COMPRESSION_SETTINGS[ $params{compression} ];

    my $halfcol_points = $compression_setting{halfcol_points};
    my $col_points     = $compression_setting{col_points};
    my $timestyle      = $compression_setting{timestyle};
    my $timepointstyle = $compression_setting{timepointstyle};

 #    my $halfcol_points = $compression ? 20                     : 24;
 #    my $col_points     = $compression ? 40                     : 48;
 #    my $timestyle      = $compression ? 'CompressedTime'       : 'Time';
 #    my $timepointstyle = $compression ? 'CompressedTimepoints' : 'Timepoints';

    my $columns  = $self->columns;
    my $halfcols = $self->half_columns;

    my ( $trailing_columns, $trailing_halves ) = _minimums(
        $columns, $halfcols,
        $params{minimum_columns},
        $params{minimum_halfcols}
    );

    my $trailing = $trailing_columns + $trailing_halves;
    my @trailers = ($EMPTY) x $trailing;

    #my $rowcount = $self->body_row_count + 2;          # 2 header rows
    my $header_rows = 2;
    my $rowcount
      = $header_rows + $params{upper_bound} - $params{lower_bound} + 1;

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
    print $th "<ColStart:<tColAttrWidth:$halfcol_points>>"
      for ( 1 .. $halfcols );
    print $th "<ColStart:<tColAttrWidth:$col_points>>"
      for ( 1 .. $columns + $trailing_columns );
    print $th "<ColStart:<tColAttrWidth:$halfcol_points>>"
      for ( 1 .. $trailing_halves );

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

    if ( $params{firstpage} ) {
        print $th $idt->parastyle('dropcaphead');
        print $th "<pDropCapCharacters:$routechars>$routetext ";
        print $th $idt->charstyle('DropCapHeadDays');
        print $th "\cG";    # control-G is "Indent to Here"

        #        my $header_daytext = $self->header_daytext;
        #
        #        if ($header_daytext =~ /except holidays/) {
        #            my $except = $idt->charstyle('DropCapHeadDaysSmall') .
        #              'except holidays' . $idt->charstyle('DropCapHeadDays');
        #            $header_daytext =~ s/except holidays/$except/;
        #
        #        }
        #
        #        print $th $header_daytext;

        print $th "\cG", $self->header_daytext;
        print $th $idt->nocharstyle, '<0x000A>';
        print $th $idt->charstyle('DropCapHeadDest'),
          , $self->header_dirtext;    # control-G is "Indent to Here"
        print $th $idt->nocharstyle;
    }    ## tidy end: if ( $params{firstpage...})
    else {
        print $th $idt->parastyle('nodrophead1');
        print $th "$routetext (continued)\r";
        print $th $idt->parastyle('nodrophead2');
        print $th $self->header_daytext, ". ", $self->header_dirtext;
    }
    print $th '<CellEnd:>';

    #    for ( 2 .. $colcount ) {
    #        print $th '<CellStyle:$header_style><CellStart:1,1><CellEnd:>';
    #    }
    print $th '<RowEnd:>';

    ##############
    # Column Header Row (line, note, timepoints)

    my $has_line_col = $self->has_route_col;
    my $has_note_col = $self->has_note_col;

    my @header_columntexts = ( $self->header_columntexts, @trailers );

    print $th
      '<RowStart:<tRowAttrHeight:35.5159912109375><tRowAttrMinRowSize:3>>';

    # The following is written this way so that in future, we can decide to
    # treat Note and Line with special graphic treatment (italics, color, etc.)
    # But I haven't created special styles for them yet.

    if ($has_line_col) {
        my $header = shift @header_columntexts;
        print $th
"<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:$timepointstyle>$header<CellEnd:>";
    }

    if ($has_note_col) {
        my $header = shift @header_columntexts;
        print $th
"<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:$timepointstyle>$header<CellEnd:>";
    }

    for my $headertext (@header_columntexts) {
        print $th
"<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:$timepointstyle>$headertext<CellEnd:>";
    }

    print $th '<RowEnd:>';

    ##############
    # Time Rows

    for my $body_row_r (
        ( $self->body_row_rs )[ $params{lower_bound} .. $params{upper_bound} ] )
    {
        my @body_row = @{$body_row_r};

        print $th '<RowStart:<tRowAttrHeight:10.5159912109375>>';

        if ($has_line_col) {
            my $route = shift @body_row;

            print $th
"<CellStyle:LineNote><StylePriority:20><CellStart:1,1><ParaStyle:LineNote>$route<CellEnd:>";
        }
        if ($has_note_col) {
            my $note = shift @body_row;

            if ( length($note) > 3 ) {
                $note = "<CharStyle:SmallNote>$note<CharStyle:>";
            }

            print $th
"<CellStyle:LineNote><StylePriority:20><CellStart:1,1><ParaStyle:LineNote>$note<CellEnd:>";
        }

        for my $time (@body_row) {

            my $parastyle;
            if ( !$time ) {
                $time      = $idt->emdash;
                $parastyle = 'LineNote';
            }
            else {
                $parastyle = $timestyle;
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
        }    ## tidy end: for my $time (@body_row)

        for ( 1 .. $trailing ) {
            print $th
"<CellStyle:Time><StylePriority:20><CellStart:1,1><ParaStyle:LineNote> <CellEnd:>";
        }

        print $th '<RowEnd:>';

    }    ## tidy end: for my $body_row_r ( ( ...))

    ###############
    # Table End

    print $th "<TableEnd:>";

    if ( $params{finalpage} ) {
        foreach my $note_definition ( $self->note_definitions ) {
            my $converted = $idt->encode_high_chars($note_definition);
            print $th "\r$converted";
        }
        # This prints note definitions only at the end of the whole table.
        # It would be better to keep track of which ones were seen and
        # print them underneath that part of the table.

    }
    else {
        print $th "\rContinued...";
    }

    close $th;

    return $tabletext;

}    ## tidy end: sub as_indesign

sub _get_header_style {

    # TODO - this shouldn't be here, it should be specified in a database
    # or something

    my $route = shift;

    return 'ColorHeader' if $route =~ /\A DB /sx;

    return 'GreyHeader' if $route =~ /\A 6\d\d \z/sx;
    return 'TransbayHeader'
      if $route =~ /\A [A-Z] /sx
      or $route eq '800'
      or $route eq '822';

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

}    ## tidy end: sub _minimums

my %name_of_bsh = (
    BSH => 'Broadway Shuttle',
    BSN => 'Broadway Shuttle (Nights)',
    BSD => 'Broadway Shuttle (Days)',
);

sub as_html {
    my $self       = shift;
    my $html_table = $self->html_table;
    return
        "<!DOCTYPE html>\n"
      . '<head><link rel="stylesheet" type="text/css" href="timetable.css">'
      . '</head><body>'
      . $html_table
      . '</body>';
}

has html_table => (
    is       => 'ro',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_html_table',
);

sub _build_html_table {

    require HTML::Entities;    ### DEP ###

    my $self = shift;

    my $columns  = $self->columns;
    my $halfcols = $self->half_columns;

    my $all_columns = $columns + $halfcols;

    my $tabletext;
    open my $th, '>', \$tabletext
      or die "Can't open table scalar for writing: $!";

    print $th '<table class="sked"><thead>';

    ### ROUTE NUMBERS

    my @header_routes = $self->header_routes;

    my $linegroup_rgbhex = $self->linegrouptype_rgbhex;
    $linegroup_rgbhex =~ s/^#*/#/;
    # add a hash if there isn't one already

    print $th
qq{<tr\n><th class="skedhead" style="background-color: $linegroup_rgbhex" colspan=$all_columns>};

    if ( $header_routes[0] =~ /^BS[DNH]/ ) {
        my $header_name = $name_of_bsh{ $header_routes[0] };
        print $th qq{<p class="bshtitle">$header_name</p>};
        print $th encode_entities( $self->header_daytext );
        print $th '<br />';
        print $th encode_entities( $self->header_dirtext );
    }
    else {

        print $th '<div class="skedheaddiv">';
        print $th '<div class="skedroute">';

        my @routes = map { encode_entities($_) } @header_routes;
        print $th join( ' &bull; ', @routes );
        print $th '</div>';
        # ROUTE DESTINATION AND DIRECTION

        print $th '<div class="skeddest">';

        print $th encode_entities( $self->header_daytext );
        print $th '<br />';
        print $th encode_entities( $self->header_dirtext );
        print $th '</div>';

    }

    print $th "</th></tr>";

    ##############
    # Service Alert Row

    foreach my $header_route (@header_routes) {
        print $th qq{<tr class=alertrow><th class=alerts colspan=$all_columns>};

        print $th
qq{<a href="http://www.actransit.org/line_alert/?quick_line=$header_route">};
        print $th "See service alerts for line $header_route.";
        print $th '</a></th></tr>';

    }

    print $th "</thead><tbody\n>";

    ##############
    # Column Header Row (line, note, timepoints)

    my $has_line_col = $self->has_route_col;
    my $has_note_col = $self->has_note_col;

    my @header_columntexts
      = map { encode_entities $_} ( $self->header_columntexts );

    print $th '<tr class="timepointheaders"\n>';

    # The following is written this way so that in future, we can decide to
    # treat Note and Line with special graphic treatment (italics, color, etc.)

    my @temp_header_columntexts = @header_columntexts;

    if ($has_line_col) {
        my $header = shift @temp_header_columntexts;
        print $th qq{<th class="lineheader">$header</th>};
    }

    if ($has_note_col) {
        my $header = shift @temp_header_columntexts;
        print $th qq{<th class="noteheader">$header</th>};
    }

    for my $headertext (@temp_header_columntexts) {
        print $th qq{<th class="timepointheader">$headertext</th>};
    }

    print $th "</tr\n>";

    ##############
    # Time Rows

    for my $body_row_r ( $self->body_row_rs ) {
        my @body_row = map { encode_entities($_) } @{$body_row_r};

        my @temp_header_columntexts = @header_columntexts;

        print $th qq{<tr class="times"\n>};

        if ($has_line_col) {
            my $line       = shift @body_row;
            my $data_title = shift @temp_header_columntexts;

            print $th qq{<td data-title="$data_title" class="line">$line</td>};

        }
        if ($has_note_col) {
            my $note       = shift @body_row;
            my $data_title = shift @temp_header_columntexts;
            my $class      = $note ? 'note' : 'blanktime';
            print $th
              qq{<td data-title="$data_title" class="$class">$note</td>};
        }

        for my $time (@body_row) {
            my $data_title = shift @temp_header_columntexts;

            if ( !$time ) {
                print $th
                  qq{<td data-title="$data_title" class='blanktime'>&mdash;};
            }
            elsif ( $time =~ /p\z/ ) {
                print $th qq{<td data-title="$data_title" class='pmtime'>$time};
            }
            else {
                print $th qq{<td data-title="$data_title" class='amtime'>$time};
            }
            print $th '</td>';
        }

        print $th "</tr\n>";

    }    ## tidy end: for my $body_row_r ( $self...)

    ###############
    # Table End

    print $th "</tbody></table>\n";

    foreach my $note_definition ( $self->note_definitions ) {
        my $enc = HTML::Entities::encode_entities_numeric($note_definition);
        print $th "<p>$enc</p>";
    }

    #print $th '</body>';

    close $th;

    return $tabletext;

}    ## tidy end: sub _build_html_table

sub as_public_json {

    # Public JSON needs access to the Timepoint table in Actium.fp7,
    # so has to be here in Timetable, even though most of the data comes from
    # the Actium::O::Sked object.

    my $self = shift;
    my $sked = $self->sked_obj;

    my @lines;
    my @notes;
    my @times;

    foreach my $trip ( $sked->trips ) {

        push @lines, $trip->line;
        push @notes, $trip->daysexceptions;
        push @times, [ $trip->placetimes ];

    }

    my @columntexts = $self->header_columntexts;
    while ( $columntexts[0] eq 'Line' or $columntexts[0] eq 'Name' ) {
        shift @columntexts;
    }

    my %json_data = (
        header_daytext     => $self->header_daytext,
        header_dirtext     => $self->header_dirtext,
        header_columntexts => \@columntexts,
        linegroup          => $self->linegroup,
        lines              => \@lines,
        notes              => \@notes,
        times              => \@times,
    );

    require JSON;    ### DEP ###

    my $json_text = JSON::encode_json( \%json_data );

    return $json_text;

}    ## tidy end: sub as_public_json

with 'Actium::O::Skedlike';

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

