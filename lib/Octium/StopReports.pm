package Octium::StopReports 0.012;

use Actium;
use Octium;
use Excel::Writer::XLSX;    ### DEP ###
use Octium::Sorting::Line(qw/linekeys sortbyline/);

use Sub::Exporter -setup => { exports => [qw(crewlist_xlsx stops2kml)] };
# Sub::Exporter ### DEP ###

##################################################################
### KML output for Google Earth etc.

const my $KML_ICON_DEFAULT =>
  'http://maps.google.com/mapfiles/kml/paddle/wht-blank.png';

const my %KML_ICON => (
    $EMPTY    => $KML_ICON_DEFAULT,
    Polesign  => 'http://maps.google.com/mapfiles/kml/paddle/wht-circle.png',
    Shelter   => 'http://maps.google.com/mapfiles/kml/paddle/wht-square.png',
    Other     => 'http://maps.google.com/mapfiles/kml/paddle/wht-diamond.png',
    'Sort of' => 'http://maps.google.com/mapfiles/kml/paddle/wht-stars.png',
);

const my $KML_START => <<"KMLSTART";
<?xml version="1.0" encoding="utf-8"?>
<kml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Style id="highlightInactivePlacemark">
       <BalloonStyle><text>\$[description]</text>
          <bgColor>FFCCCCCC</bgColor></BalloonStyle>
       <LabelStyle><scale>.7</scale></LabelStyle>
      <IconStyle>
         <scale>.7</scale>
        <Icon>
          <href>$KML_ICON_DEFAULT</href>
        </Icon>
      </IconStyle>
    </Style>
       <Style id="highlightActivePlacemark">
       <LabelStyle><scale>.9</scale></LabelStyle>
      <IconStyle>
        <Icon>
          <href>$KML_ICON_DEFAULT</href>
        </Icon>
      </IconStyle>
    <BalloonStyle><text>\$[description]</text></BalloonStyle>
    </Style>
    <Style id="normalInactivePlacemark">
       <LabelStyle><scale>.7</scale></LabelStyle>
      <IconStyle>
         <scale>.7</scale>
        <Icon>
          <href>$KML_ICON_DEFAULT</href>
        </Icon>
      </IconStyle>
    <BalloonStyle><text>\$[description]</text></BalloonStyle>
    </Style>
    <Style id="normalActivePlacemark">
       <LabelStyle><scale>.9</scale></LabelStyle>
      <IconStyle>
        <Icon>
          <href>$KML_ICON_DEFAULT</href>
        </Icon>
      </IconStyle>
    <BalloonStyle><text>\$[description]</text>
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

const my @RGBS => qw(
  6666FF
  0080FF
  00FF00
  00FF80
  8000FF
  8080FF
  80FF00
  80FF80
  80FFFF
  FF0000
  FF00FF
  FF8000
  FF8080
  FF80FF
  FFFF00
  FFFF80
  FFFFFF

);

const my @HASH_COLORS => map { '#FF' . join( $EMPTY, reverse( $_ =~ /../g ) ) }
  @RGBS;
# KML uses alpha + BGR for some insane reason

sub _hash_color {
    state $color_of_r;
    my $value = shift;
    return $color_of_r->{$value} if $color_of_r->{$value};
    state $count = 0;
    $count++;
    my $color = $HASH_COLORS[ $count % @HASH_COLORS ];
    return $color_of_r->{$value} = $color;

}

sub stops2kml {
    my $actiumdb = shift;
    my $option   = shift;

    my $stops_r = $actiumdb->all_in_columns_key(
        {   TABLE   => 'Stops_Neue',
            COLUMNS => [
                qw/c_description_fullabbr h_stp_identifier
                  h_loca_latitude h_loca_longitude p_active p_lines
                  p_linedirs u_connections u_flex_route u_work_zone
                  c_city /
            ],
        }
    );

    my $lines_r = $actiumdb->all_in_columns_key(
        {   TABLE   => 'Lines',
            COLUMNS => [qw/LineGroupType/],
        }
    );

    my ( %icon_of_stop, %signtype_of_stop );

    {

        const my @SIGNCOLUMNS =>
          qw[ stp_511_id  Active Signs.SignType SignTypes.SignClassification ];
        const my $SIGN_COLUMNS_SQL => join( ', ', @SIGNCOLUMNS );

        my $signquery = <<"EOT";
    SELECT $SIGN_COLUMNS_SQL
    FROM Signs
       LEFT JOIN Signtypes ON Signs.SignType = SignTypes.SignType
       WHERE Signs.Active <> 'No'
EOT

        my $sth = $actiumdb->dbh->prepare($signquery);
        $sth->execute();

      SIGNROW:
        while ( my $row_r = $sth->fetchrow_arrayref ) {
            foreach ( @{$row_r} ) {
                next SIGNROW unless defined;
                s/\s+\z//;    # trim trailing white space
            }

            my ( $stopid, $active, $signtype, $signclassification ) = @{$row_r};

            if ( exists $signtype_of_stop{$stopid} ) {
                $signtype_of_stop{$stopid} .= " / $signtype";
            }
            else {
                $signtype_of_stop{$stopid} = $signtype;
            }

            if ( Octium::feq( $active, 'Sort of' ) ) {
                $icon_of_stop{$stopid} = $KML_ICON{'Sort of'};
                next SIGNROW;
            }

            my $thisicon;

            if ( exists $KML_ICON{$signclassification} ) {
                $thisicon = $KML_ICON{$signclassification};
            }
            else {
                $thisicon = $KML_ICON{Other};
            }

            if ( exists $icon_of_stop{$stopid}
                and $icon_of_stop{$stopid} ne $thisicon )
            {
                $icon_of_stop{$stopid} = $KML_ICON{'Sort of'};
            }
            else {
                $icon_of_stop{$stopid} = $thisicon;
            }

        }    ## tidy end: SIGNROW: while ( my $row_r = $sth->...)

    }

    #my $signs_r = $actiumdb->all_in_columns_key(
    #   TABLE => 'Signs',
    #   COLUMNS => 'stp_511_id',
    #);

    my %folders;

    if ( $option eq 'w' ) {
        my %seen_workzone;
        foreach my $stopid ( sort keys %{$stops_r} ) {
            my $workzone = $stops_r->{$stopid}{u_work_zone};
            $seen_workzone{$workzone}++;
        }

        my @workzones = sort { $a <=> $b } keys %seen_workzone;
        my @colors    = map  { _hash_color($_) } @workzones;
        # colors is thrown away, but that seeds the hash color generator

    }

    foreach my $stopid ( sort keys %{$stops_r} ) {

        my %stp = %{ $stops_r->{$stopid} };
        next if $stp{c_city} eq 'Virtual';
        if ( $option eq 'v' and $stp{c_city} ne 'Oakland' ) {
            next;
        }
        my $active   = $stp{p_active};
        my $workzone = $stp{u_work_zone};
        my $lines    = $stp{p_lines};
        next if ( not $lines and $option eq 'v' );
        #my $flex     = $stp{u_flex_route};
        #next unless ($flex and $flex eq '448');

        my $activity = $active ? 'Active' : 'Inactive';
        my $foldername;

        if ( $option eq 'w' ) {
            $foldername = $workzone;
        }
        else {
            $foldername = $activity;
        }

        my $description = _kml_stop_description( \%stp, \%signtype_of_stop );

        my $text;
        my $icon_text = $EMPTY;
        if ( exists $icon_of_stop{$stopid} ) {
            $icon_text = "<Icon>" . $icon_of_stop{$stopid} . "</Icon>";
        }

        if ( $option eq 'w' ) {

            my $color = _hash_color($workzone);

            $text
              = "<Placemark>\n"
              . "<name>$workzone</name>\n"
              . "<styleUrl>#stop${activity}Style</styleUrl>\n"
              . "<description>$description</description>\n";

            $text
              .= "<Style>\n"
              . "<IconStyle>\n"
              . "<color>$color</color>\n"
              . $icon_text
              . "</IconStyle>\n"
              . "<LabelStyle>\n"
              . "<color>$color</color>\n"
              . "</LabelStyle>\n"
              . "</Style>\n";

        }
        elsif ( $option eq 'v' ) {

            #my $color = _hash_color($workzone);

            $text
              = "<Placemark>\n"
              . "<name>$lines</name>\n"
              . "<styleUrl>#stop${activity}Style</styleUrl>\n"
              . "<description>$description</description>\n";

            $text .= "<Style>\n" . "<IconStyle>\n"
              #              . "<color>$color</color>\n"
              . '<scale>.3</scale>'
              #
              . '<Icon>'
              . 'http://maps.google.com/mapfiles/kml/paddle/grn-blank-lv.png'
              . '</Icon>'
              . "</IconStyle>\n"
              . "<LabelStyle>\n"
              #              . "<color>$color</color>\n"
              . "</LabelStyle>\n" . "</Style>\n";

        }
        else {    # by stops

            $text
              = "<Placemark>\n"
              . "<name>$stopid</name>\n"
              . "<styleUrl>#stop${foldername}Style</styleUrl>\n"
              . "<description>$description</description>\n";

            if ($active) {
                my @lines = split( ' ', $stp{p_lines} );
                my $color = _kml_color( $lines_r, @lines );

                warn "unnknown color for " . $stp{p_lines}
                  unless defined $color;

                $text
                  .= "<Style>\n"
                  . "<IconStyle>\n"
                  . $icon_text
                  . "<color>$color</color>\n"
                  . "</IconStyle>\n"
                  . "<LabelStyle>\n"
                  . "<color>$color</color>\n"
                  . "</LabelStyle>\n"
                  . "</Style>\n";
            }

        }    ## tidy end: else [ if ($is_wz_kml) ]

        my ( $lat, $long ) = @stp{qw/h_loca_latitude h_loca_longitude/};

        $text
          .= "<Point>\n"
          . "<coordinates>$long, $lat</coordinates>\n"
          . "</Point>\n"
          . "</Placemark>\n";

        $folders{$foldername} .= $text;

    }    ## tidy end: foreach my $stopid ( sort keys...)

    foreach my $foldername ( keys %folders ) {
        $folders{$foldername}
          = "<Folder>\n"
          . "<name>$foldername</name>\n"
          . "$folders{$foldername}\n"
          . "</Folder>\n";
    }

    my $alltext = $KML_START;

    my @keys;
    {
        no warnings 'numeric';
        @keys = sort { $a <=> $b || $a cmp $b } keys %folders;
    }
    $alltext .= join( $EMPTY, @folders{@keys} );
    #$alltext .= $folders{Active};
    #$alltext .= $folders{Inactive};
    $alltext .= $KML_END;
    return $alltext;

}    ## tidy end: sub stops2kml

sub _kml_stop_description {

    \my %stp              = shift;
    \my %signtype_of_stop = shift;

    my $stop_id   = $stp{h_stp_511_id};
    my $desc      = $stp{c_description_fullabbr};
    my $hastus_id = $stp{h_stp_identifier};
    my $lines     = $stp{p_lines};
    #my $zip        = $stp{p_zip_code};
    my $linetext   = $lines         ? "<u>Lines:</u> $lines" : 'Inactive stop';
    my $activestar = $stp{p_active} ? $EMPTY                 : '*';
    my $workzone   = $stp{u_work_zone};
    my $signtype   = $signtype_of_stop{$stop_id};

    my $connections      = $stp{u_connections};
    my $connections_text = $EMPTY;
    my $signtype_text    = $EMPTY;
    if ($signtype) {
        $signtype_text = "<br>$signtype";
    }
    if ($connections) {
        my @connections = split( /\r/, $connections );
        $connections_text
          = "<br>\n"
          . "<u>Connections:</u> "
          . Actium::joinseries( conjunction => '&', items => \@connections );
    }

    my $text
      = "<p><b><u>$stop_id\x{2003}$hastus_id</u></b><br>\n"
      . "${activestar}$desc  [$workzone]</p>\n"
      . $linetext
      . $signtype_text
      . $connections_text;

    require HTML::Entities;    ### DEP ###
    return HTML::Entities::encode_entities_numeric($text);

}    ## tidy end: sub _kml_stop_description

{

    const my @KML_LINE_TYPES => (
        'Flex',             'Rapid',
        'Transbay',         'Dumbarton Express',
        'Broadway Shuttle', 'All Nighter',
        'Local',            'Service to Schools',
        'Early Bird',       $EMPTY,
    );

    const my $LOWEST_PRIORITY => scalar @KML_LINE_TYPES;

    const my %KML_LINE_COLORS => (
        Rapid                => 'FF4040FF',
        Transbay             => 'FF00FF00',
        'Dumbarton Express'  => 'FFFF8000',
        'Broadway Shuttle'   => 'FF00FFC0',
        'All Nighter'        => 'FFFFFF00',
        Local                => 'FFFFFF00',
        'Service to Schools' => 'FF80FFFF',
        'Early Bird'         => 'FFD09300',
        # flex is 301DAF - multiplied by 1.46
        Flex   => 'FF462AFF',
        $EMPTY => 'FF80FFFF',
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
        my $lines_r = shift;
        my @lines   = @_;
        my $priority
          = Octium::min( map { _kml_priority( $lines_r, $_ ) } @lines );
        return $color_of_priority{$priority};
    }

}

sub citiesbyline {

    my %params
      = Octium::validate( @_, { actiumdb => { can => 'each_row_eq' }, } );
    my $actiumdb = $params{actiumdb};

    my $eachstop = $actiumdb->each_columns_in_row_where(
        table   => 'Stops_Neue',
        columns => [qw/h_stp_511_id p_lines c_city/],
        where   => 'WHERE p_active = 1'
    );

    # build lines by city and type struct
    my %cities_of;
    while ( my $colref = $eachstop->() ) {
        \my @cols = $colref;
        my ( undef, $p_lines, $c_city ) = @cols;

        my @lines = split( /\s+/, $p_lines );
        foreach my $line (@lines) {
            $cities_of{$line}{$c_city} = 1;
        }
    }

    foreach my $line ( Octium::sortbyline keys %cities_of ) {

        my @cities = sort ( keys %{ $cities_of{$line} } );

        say $line;
        foreach my $city (@cities) {
            say "   $city";
        }
        say "";

    }

    return;

}    ## tidy end: sub citiesbyline

sub linesbycity {

    my %params
      = Octium::validate( @_, { actiumdb => { can => 'each_row_eq' }, } );

    my $actiumdb = $params{actiumdb};

    my %type_of;
    foreach my $line ( $actiumdb->line_keys ) {
        \my %row = $actiumdb->line_row_r($line);
        if ( Octium::feq( $row{agency_id}, 'ACTransit' ) ) {
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

        my @lines = split( ' ', $p_lines );
        foreach my $line (@lines) {
            my $type = $type_of{$line} // 'Local';
            $lines_of{$c_city}{$type}{$line} = 1;
        }
    }

    open my $html_fh, '>', \my $html_text
      or die "Can't open output to scalar: $OS_ERROR";

    print $html_fh "\n<!--\n    Do not edit this file! "
      . "It is automatically generated from a program.\n-->\n";

    my @all_lgtypes = $actiumdb->linegrouptypes_in_order;

    foreach my $city ( sort keys %lines_of ) {
        my $city_h = Octium::encode_entities($city);
        print $html_fh
          qq{<h4 style="text-transform:uppercase;" id="$city_h">$city_h</h4>};

        #        foreach my $type ( sort keys %{ $lines_of{$city} } ) {
        foreach my $type (@all_lgtypes) {
            next unless exists $lines_of{$city}{$type};
            my $type_h = Octium::encode_entities($type);
            print $html_fh "<p><strong>$type_h:</strong>";

            my @lines = sortbyline keys %{ $lines_of{$city}{$type} };

            foreach my $line (@lines) {
                my $url = $actiumdb->linesked_url($line);
                $line = qq{<a href="$url">$line</a>};
            }

            my $separator = '&nbsp;&nbsp;&nbsp; ';

            say $html_fh $separator, join( $separator, @lines ), '</p>';

        }
        #say $html_fh '</dl>';

    }    ## tidy end: foreach my $city ( sort keys...)

    return ( struct => \%lines_of, html => $html_text );

}    ## tidy end: sub linesbycity

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

