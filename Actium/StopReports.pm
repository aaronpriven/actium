# /Actium/StopReports.pm

# Create the crew list and other reports from stop database

package Actium::StopReports 0.010;
use Actium::Preamble;
use Excel::Writer::XLSX; ### DEP ###
use Actium::Sorting::Travel(qw<travelsort>);
use Actium::Sorting::Line(qw/linekeys sortbyline/);
use Actium::Util('joinseries_ampersand');

use Sub::Exporter -setup => { exports => [qw(crewlist_xlsx stops2kml)] };
# Sub::Exporter ### DEP ###

##################################################################
### KML output for Google Earth etc.

const my $KML_START => <<'KMLSTART';
<?xml version="1.0" encoding="utf-8"?>
<kml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Style id="highlightInactivePlacemark">
       <BalloonStyle><text>$[description]</text>
          <bgColor>FFCCCCCC</bgColor></BalloonStyle>
       <LabelStyle><scale>.7</scale></LabelStyle>
      <IconStyle>
         <scale>.7</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/shapes/placemark_square.png</href>
        </Icon>
      </IconStyle>
    </Style>
       <Style id="highlightActivePlacemark">
       <LabelStyle><scale>.9</scale></LabelStyle>
      <IconStyle>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href>
        </Icon>
      </IconStyle>
    <BalloonStyle><text>$[description]</text></BalloonStyle>
    </Style>
    <Style id="normalInactivePlacemark">
       <LabelStyle><scale>.7</scale></LabelStyle>
      <IconStyle>
         <scale>.7</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/shapes/placemark_square.png</href>
        </Icon>
      </IconStyle>
    <BalloonStyle><text>$[description]</text></BalloonStyle>
    </Style>
    <Style id="normalActivePlacemark">
       <LabelStyle><scale>.9</scale></LabelStyle>
      <IconStyle>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href>
        </Icon>
      </IconStyle>
    <BalloonStyle><text>$[description]</text>
    <bgColor>FFCCCCCC</bgColor></BalloonStyle>
    </Style>
        <StyleMap id="stopInactiveStyle">
      <Pair>
        <key>normal</key>
        <styleUrl>#normalInactivePlacemark</styleUrl>
      </Pair>
      <Pair>
        <key>highlight</key>
        <styleUrl>#highlightInactivePlacemark</styleUrl>
      </Pair>
    </StyleMap>
    <StyleMap id="stopActiveStyle">
      <Pair>
        <key>normal</key>
        <styleUrl>#normalActivePlacemark</styleUrl>
      </Pair>
      <Pair>
        <key>highlight</key>
        <styleUrl>#highlightActivePlacemark</styleUrl>
      </Pair>
    </StyleMap>
KMLSTART

const my $KML_END => <<'KMLEND';
  </Document>
</kml>
KMLEND

sub stops2kml {
    my $actiumdb = shift;

    #my %params   = validate(
    #    @_,
    #    {
    #        actiumdb => { can => 'all_in_columns_key' },
    #    }
    #);

    my $stops_r = $actiumdb->all_in_columns_key(
        {
            TABLE   => 'Stops_Neue',
            COLUMNS => [
                qw/c_description_fullabbr h_stp_identifier
                  h_loca_latitude h_loca_longitude
                  p_active p_lines p_linedirs u_connections/
            ],
        }
    );

    my $lines_r = $actiumdb->all_in_columns_key(
        {
            TABLE   => 'Lines',
            COLUMNS => [qw/LineGroupType/],
        }
    );

    my %folders;

    foreach my $stopid ( sort keys %{$stops_r} ) {

        #next if $stopid > "52000";

        my %stp        = %{ $stops_r->{$stopid} };
        my $active     = $stp{p_active};
        my $foldername = $active ? 'Active' : 'Inactive';

        my $description = _kml_stop_description( \%stp );

        my $text =
            "<Placemark>\n"
          . "<name>$stopid</name>\n"
          . "<styleUrl>#stop${foldername}Style</styleUrl>\n"
          . "<description>$description</description>\n";

        if ($active) {
            my @lines = split( ' ', $stp{p_lines} );
            my $color = _kml_color( $lines_r, @lines );

            $text .=
                "<Style>\n"
              . "<IconStyle>\n"
              . "<color>$color</color>\n"
              . "</IconStyle>\n"
              . "<LabelStyle>\n"
              . "<color>$color</color>\n"
              . "</LabelStyle>\n"
              . "</Style>\n";
        }

        my ( $lat, $long ) = @stp{qw/h_loca_latitude h_loca_longitude/};

        $text .=
            "<Point>\n"
          . "<coordinates>$long, $lat</coordinates>\n"
          . "</Point>\n"
          . "</Placemark>\n";

        $folders{$foldername} .= $text;

    }

    foreach my $foldername ( keys %folders ) {
        $folders{$foldername} =
            "<Folder>\n"
          . "<name>$foldername</name>\n"
          . "$folders{$foldername}\n"
          . "</Folder>\n";
    }

    my $alltext = $KML_START;
    $alltext .= $folders{Active};
    $alltext .= $folders{Inactive};
    $alltext .= $KML_END;
    return $alltext;

    #return $KML_START . $folders{active} . $folders{inactive} . $KML_END;

}

sub _kml_stop_description {

    my %stp = %{ +shift };

    my $stop_id    = $stp{h_stp_511_id};
    my $desc       = $stp{c_description_fullabbr};
    my $hastus_id  = $stp{h_stp_identifier};
    my $lines      = $stp{p_linedirs};
    my $linetext   = $lines ? "<u>Lines:</u> $lines" : 'Inactive stop';
    my $activestar = $stp{p_active} ? $EMPTY_STR : '*';

    my $connections      = $stp{u_connections};
    my $connections_text = $EMPTY_STR;
    if ($connections) {
        my @connections = split( /\r/, $connections );
        $connections_text =
            "<br>\n"
          . "<u>Connections:</u> "
          . joinseries_ampersand(@connections);
    }

    my $text =
        "<p><b><u>$stop_id\x{2003}$hastus_id</u></b><br>\n"
      . "${activestar}$desc</p>\n"
      . "$linetext" . "${connections_text}";

    require HTML::Entities; ### DEP ###
    return HTML::Entities::encode_entities_numeric($text);

}

{

    const my @KML_LINE_TYPES => (
        'Rapid', 'Transbay',
        'Dumbarton Express',
        'Broadway Shuttle',
        'All Nighter', 'Local', 'Supplementary', $EMPTY_STR,
    );

    const my $LOWEST_PRIORITY => scalar @KML_LINE_TYPES;

    const my %KML_LINE_COLORS => (
        Rapid               => 'FF4040FF',
        Transbay            => 'FF00FF00',
        'Dumbarton Express' => 'FFFF6060',
        'Broadway Shuttle'  => 'FF00FFC0',
        'All Nighter'       => 'FFFFFF00',
        Local               => 'FFFFFF00',
        Supplementary       => 'FF80FFFF',
        $EMPTY_STR          => 'FF80FFFF',
    );

    my %color_of_priority;
    my %priority_of_type;
    foreach my $idx ( 0 .. $#KML_LINE_TYPES ) {
        my $line_type = $KML_LINE_TYPES[$idx];
        $priority_of_type{$line_type} = $idx;
        $color_of_priority{$idx}      = $KML_LINE_COLORS{$line_type};
    }

    sub _kml_priority {
        my $lines_r = shift;
        my $line    = shift;
        return $LOWEST_PRIORITY unless $line;
        return $priority_of_type{Rapid} if $line =~ /\A \d+ R \z/sx;
        my $type = $lines_r->{$line}{LineGroupType};
        return $LOWEST_PRIORITY
          unless $type and defined $priority_of_type{$type};
        return $priority_of_type{$type};
    }

    sub _kml_color {
        my $lines_r  = shift;
        my @lines    = @_;
        my $priority = min( map { _kml_priority( $lines_r, $_ ) } @lines );
        return $color_of_priority{$priority};
    }

}

##################################################################
### CREW LIST

const my @HEADERS    => (qw/Group Order StopID Location Decals/);
const my $PAPER_SIZE => 1;                                          # letter

const my @COLUMN_WIDTHS => 6.5, 7.5, 5.5, 47.5, 14;

sub crewlist_xlsx {

    my %params = validate(
        @_,
        {
            actiumdb         => { can  => 'all_in_columns_key' },
            outputfile       => { type => $PV_TYPE{SCALAR} },
            stops_of_linedir => { type => $PV_TYPE{HASHREF} },
            signup_display =>
              { type => $PV_TYPE{SCALAR}, default => $EMPTY_STR },
        }
    );
    my $actiumdb       = $params{actiumdb};
    my $signup_display = $params{signup_display};

    my $promote_lines_r = $actiumdb->all_in_column_key(
        {
            TABLE  => 'Lines',
            COLUMN => 'crewlist_promote',
            WHERE  => q{Active = 'Yes' AND crewlist_promote = 1},
        }
    );

    my @promote_lines = sortbyline keys %{$promote_lines_r};

    my $stops_r = $actiumdb->all_in_columns_key(
        {
            TABLE   => 'Stops_Neue',
            COLUMNS => [qw/c_description_fullabbr c_crew_assignment p_decals/],
            WHERE   => 'p_active = 1',
        }
    );

    my %stops_of_assignment;

    foreach my $stopid ( keys %{$stops_r} ) {
        my $stop_record = $stops_r->{$stopid};
        next if not defined $stop_record->{c_crew_assignment};
        next if $stop_record->{c_description_fullabbr} =~ /Virtual/i;
        my $crew_assignment = $stop_record->{c_crew_assignment};
        push @{ $stops_of_assignment{$crew_assignment} }, $stopid;
    }

    my $outputfile = $params{outputfile};
    $outputfile .= '.xlsx' unless $outputfile =~ /[.]xlsx\z/si;

    my $workbook = Excel::Writer::XLSX->new($outputfile);

    my @common_formats = ( valign => 'top', num_format => '@' );
    my $data_format = $workbook->add_format( text_wrap => 1, @common_formats );
    my $header_format = $workbook->add_format( bold => 1, @common_formats );

    foreach my $crew_assignment ( sort keys %stops_of_assignment ) {

        my @travelsorted = travelsort(
            stops            => $stops_of_assignment{$crew_assignment},
            stops_of_linedir => $params{stops_of_linedir},
            promote          => \@promote_lines,
            demote600s       => 1,
        );

        #@sorted = sort { $a->[0] cmp $b->[0] } @sorted;

        my @to_line_sort;
        foreach my $linedir_and_stops (@travelsorted) {
            my $linedir = $linedir_and_stops->[0];
            my ( $line, $dir ) = split( /-/, $linedir );
            push @to_line_sort, [ $linedir_and_stops, linekeys($line), $dir ];
        }

        # creates new array @to_line_sort, where first element is ref to
        # original array, second element is the line to be sorted,
        # third element is the direction to be sorted

        @to_line_sort =
          sort { $a->[1] cmp $b->[1] or $a->[2] cmp $b->[2] } @to_line_sort;

        # sort that, first by the line, then by the direction

        my @sorted = map { $_->[0] } @to_line_sort;

        # make @sorted just the original arrays
        # So this is basically an exploaded Schwarzian transform

        #@sorted = map { $_->[0] }
        #  sort { $a->[1] cmp $b->[1] }
        #  map { [ $_, linekeys( $_->[0] ) ] } @sorted;

        my @output_stops;

        while ( my $ref = shift @sorted ) {
            my ( $linedir, @stops ) = @{$ref};
            my $numstops = scalar @stops;
            foreach my $i ( 1 .. $numstops ) {
                my $stopid = $stops[ $i - 1 ];
                my $decals = doe( $stops_r->{$stopid}{p_decals} );
                $decals =~ s/-/\x{2011}/g;

                push @output_stops,
                  [
                    $linedir, "$i of $numstops",
                    $stopid,  $stops_r->{$stopid}{c_description_fullabbr},
                    $decals,
                  ];

            }
        }

        my $sheet = $workbook->add_worksheet("Assignment $crew_assignment");

        $sheet->write_row( 0, 0, \@HEADERS, $header_format );
        $sheet->write_col( 1, 0, \@output_stops, $data_format );

        for my $column ( 0 .. @COLUMN_WIDTHS ) {
            $sheet->set_column( $column, $column, $COLUMN_WIDTHS[$column] );
        }

        $sheet->set_page_view;
        $sheet->set_paper($PAPER_SIZE);
        $sheet->set_header("&LAssignment #$crew_assignment");
        $sheet->set_footer("&L&D&C$signup_display&R&P of &N");
        $sheet->repeat_rows(0);
        $sheet->hide_gridlines(0);

    }

    for my $worksheet ( $workbook->sheets() ) {

    }

    return $workbook->close;

}

1;
