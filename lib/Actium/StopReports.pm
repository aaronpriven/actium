package Actium::StopReports 0.012;
use Actium::Preamble;
use Excel::Writer::XLSX;    ### DEP ###
use Actium::Sorting::Travel(qw<travelsort>);
use Actium::Sorting::Line(qw/linekeys sortbyline/);

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

    #my %params   = u::validate(
    #    @_,
    #    {
    #        actiumdb => { can => 'all_in_columns_key' },
    #    }
    #);

    my $stops_r = $actiumdb->all_in_columns_key(
        {   TABLE   => 'Stops_Neue',
            COLUMNS => [
                qw/c_description_fullabbr h_stp_identifier
                  h_loca_latitude h_loca_longitude p_active p_lines
                  p_linedirs u_connections u_flex_route/
            ],
        }
    );

    my $lines_r = $actiumdb->all_in_columns_key(
        {   TABLE   => 'Lines',
            COLUMNS => [qw/LineGroupType/],
        }
    );

    my %folders;

    foreach my $stopid ( sort keys %{$stops_r} ) {
        
        #next if $stopid > "52000";

        my %stp        = %{ $stops_r->{$stopid} };
        my $active     = $stp{p_active};
        #my $flex     = $stp{u_flex_route};
        #next unless ($flex and $flex eq '448');
        
        my $foldername = $active ? 'Active' : 'Inactive';

        my $description = _kml_stop_description( \%stp );

        my $text
          = "<Placemark>\n"
          . "<name>$stopid</name>\n"
          . "<styleUrl>#stop${foldername}Style</styleUrl>\n"
          . "<description>$description</description>\n";

        if ($active) {
            my @lines = split( ' ', $stp{p_lines} );
            my $color = _kml_color( $lines_r, @lines );

            $text
              .= "<Style>\n"
              . "<IconStyle>\n"
              . "<color>$color</color>\n"
              . "</IconStyle>\n"
              . "<LabelStyle>\n"
              . "<color>$color</color>\n"
              . "</LabelStyle>\n"
              . "</Style>\n";
        }

        my ( $lat, $long ) = @stp{qw/h_loca_latitude h_loca_longitude/};

        $text
          .= "<Point>\n"
          . "<coordinates>$long, $lat</coordinates>\n"
          . "</Point>\n"
          . "</Placemark>\n";

        $folders{$foldername} .= $text;

    } ## tidy end: foreach my $stopid ( sort keys...)

    foreach my $foldername ( keys %folders ) {
        $folders{$foldername}
          = "<Folder>\n"
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

} ## tidy end: sub stops2kml

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
        $connections_text
          = "<br>\n"
          . "<u>Connections:</u> "
          . u::joinseries_ampersand(@connections);
    }

    my $text
      = "<p><b><u>$stop_id\x{2003}$hastus_id</u></b><br>\n"
      . "${activestar}$desc</p>\n"
      . "$linetext"
      . "${connections_text}";

    require HTML::Entities;    ### DEP ###
    return HTML::Entities::encode_entities_numeric($text);

} ## tidy end: sub _kml_stop_description

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
        my $priority = u::min( map { _kml_priority( $lines_r, $_ ) } @lines );
        return $color_of_priority{$priority};
    }

}


sub linesbycity {

    my %params = u::validate( @_, { actiumdb => { can => 'each_row_eq' }, } );

    my $actiumdb = $params{actiumdb};

    my %type_of;
    foreach my $line ( $actiumdb->line_keys ) {
        \my %row = $actiumdb->line_row_r($line);
        if ( u::feq( $row{agency_id}, 'ACTransit' ) ) {
            # note that is not agency name. Name has spaces.
            # ID does not
            $type_of{$line} = $row{LineGroupType};
        }
        else {
            $type_of{$line} = $EMPTY;
        }
    }

    #my $eachstop = $actiumdb->each_row_eq( 'Stops_Neue', 'p_active', '1' );

    my $eachstop = $actiumdb->each_columns_in_row_where(
        table   => 'Stops_Neue',
        columns => [qw/h_stp_511_id p_lines c_city/],
        where   => 'WHERE p_active = 1'
    );

    # build lines by city and type struct
    my %lines_of;
    while ( my $colref = $eachstop->() ) {
        \my @cols = $colref;
        my ( undef, $p_lines, $c_city ) = @cols;

        my @lines = split( /\s+/, $p_lines );
        foreach my $line (@lines) {
            my $type = $type_of{$line};
            $lines_of{$c_city}{$type}{$line} = 1;
        }
    }

    open my $html_fh, '>', \my $html_text
      or die "Can't open output to scalar: $OS_ERROR";

    print $html_fh "\n<!--\n    Do not edit this file! "
      . "It is automatically generated from a program.\n-->\n";

    my @all_lgtypes = $actiumdb->linegrouptypes_in_order;

    foreach my $city ( sort keys %lines_of ) {
        my $city_h = u::encode_entities($city);
        print $html_fh
          qq{<h4 style="text-transform:uppercase;" id="$city_h">$city_h</h4>}
          ;

        #        foreach my $type ( sort keys %{ $lines_of{$city} } ) {
        foreach my $type (@all_lgtypes) {
            next unless exists $lines_of{$city}{$type};
            my $type_h = u::encode_entities($type);
            print $html_fh "<p><strong>$type_h:</strong>";

            my @lines = sortbyline keys %{ $lines_of{$city}{$type} };

            foreach my $line (@lines) {
                my $url = $actiumdb->linesked_url($line);
                $line = qq{<a href="$url">$line</a>};
            }
            
            my $separator = '&nbsp;&nbsp;&nbsp; ';

            say $html_fh $separator, join( $separator , @lines ), '</p>';

        }
        #say $html_fh '</dl>';

    } ## tidy end: foreach my $city ( sort keys...)

    return ( struct => \%lines_of, html => $html_text );

} ## tidy end: sub linesbycity

1;
