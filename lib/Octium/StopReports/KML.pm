package Octium::StopReports::KML 0.016;

use Actium;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

##################################################################
### KML output for Google Earth etc.

#const my %KML_ICON_PADDLES => (
#    $EMPTY    => 'http://maps.google.com/mapfiles/kml/paddle/wht-blank.png',
#    Polesign  => 'http://maps.google.com/mapfiles/kml/paddle/wht-circle.png',
#    Shelter   => 'http://maps.google.com/mapfiles/kml/paddle/wht-square.png',
#    Other     => 'http://maps.google.com/mapfiles/kml/paddle/wht-diamond.png',
#    'Sort of' => 'http://maps.google.com/mapfiles/kml/paddle/wht-stars.png',
#);

const my $KML_ICON_DEFAULT =>
  'http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png';

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

func stops2kml ( :$actiumdb , :$option, :$save_file, :$icon_file ) {

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

    \my ( %signtype_text_of, %signclassification_of )
      = signinfo( actiumdb => $actiumdb );

    my ( %folders, %icons );

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

        \my %stp = $stops_r->{$stopid};
        next if $stp{c_city} eq 'Virtual';
        my $active   = $stp{p_active};
        my $workzone = $stp{u_work_zone};
        my $lines    = $stp{p_lines};
        my $city     = $stp{c_city};

        my $activity = $active ? 'Active' : 'Inactive';

        my $description
          = _kml_stop_description( \%stp, $signtype_text_of{$stopid} );

        my $text;
        my $icon = $EMPTY;

        if ( not exists $signclassification_of{$stopid} ) {
            $icon = 'rectangle';
        }
        else {
            my $signclass = $signclassification_of{$stopid};
            if ( $signclass eq 'Polesign' ) {
                $icon = 'capsule';
            }
            elsif ( $signclass eq 'Shelter' ) {
                $icon = 'pentagon';
            }
            else { $icon = 'octagon' }
        }
        $icon .= "-italic" unless $active;
        $icon .= "/$stopid.png";
        $icons{$icon} = 1;

        my $icon_text = "<Icon>$icon</Icon>";

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
        else {    # by stops

            my ( $color, $linetext );

            if ($active) {
                $linetext = $stp{p_lines};
                my @lines = split( ' ', $linetext );
                $color = _kml_line_color( $lines_r, @lines );
            }
            else {
                $linetext = '*';
                $color    = _kml_inactive_color();
            }

            $text
              = "<Placemark>\n"
              . "<name>$linetext</name>\n"
              . "<styleUrl>#stop${activity}Style</styleUrl>\n"
              . "<description>$description</description>\n";

            if ($active) {

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

        }

        my ( $lat, $long ) = @stp{qw/h_loca_latitude h_loca_longitude/};

        $text
          .= "<Point>\n"
          . "<coordinates>$long, $lat</coordinates>\n"
          . "</Point>\n"
          . "</Placemark>\n";

        my $foldername;

        if ( $option eq 'w' ) {
            $foldername = "$workzone-$activity";
        }
        else {
            $foldername = "$city-$activity";
        }

        $folders{$foldername} .= $text;

    }

    foreach my $foldername ( keys %folders ) {
        $folders{$foldername}
          = "<Folder>\n"
          . "<name>$foldername</name>\n"
          . "$folders{$foldername}\n"
          . "</Folder>\n";
    }

    my $kmltext = $KML_START;

    my @keys;
    {
        no warnings 'numeric';
        @keys = sort { $a <=> $b || $a cmp $b } keys %folders;
    }
    $kmltext .= join( $EMPTY, @folders{@keys} );
    $kmltext .= $KML_END;

    my $kmz             = Archive::Zip->new();
    my $kml_text_member = $kmz->addString( $kmltext, 'doc.kml' );
    $kml_text_member->desiredCompressionMethod(COMPRESSION_DEFLATED);

    my $icon_zip = Archive::Zip->new();
    unless ( $icon_zip->read($icon_file) == AZ_OK ) {
        die 'read error';
    }
    foreach my $icon ( sort keys %icons ) {
        my $iconmember = $icon_zip->memberNamed($icon);
        $kmz->addMember($iconmember);
    }

    # Save the Zip file
    unless ( $kmz->writeToFileNamed($save_file) == AZ_OK ) {
        die 'write error on file' . $save_file;
    }

    return;

}

sub _kml_stop_description {

    \my %stp = shift;
    my $signtype = shift // '';

    my $stop_id   = $stp{h_stp_511_id};
    my $desc      = $stp{c_description_fullabbr};
    my $hastus_id = $stp{h_stp_identifier};
    my $lines     = $stp{p_linedirs};
    #my $zip        = $stp{p_zip_code};
    my $linetext   = $lines         ? "<u>Lines:</u> $lines" : 'Inactive stop';
    my $activestar = $stp{p_active} ? $EMPTY                 : '*';
    my $workzone   = $stp{u_work_zone};

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

}

{

    const my @KML_LINE_TYPES => (
        'Tempo',              'Flex',
        'Rapid',              'Transbay',
        'Dumbarton Express',  'Broadway Shuttle',
        'All Nighter',        'Local',
        'Service to Schools', 'Early Bird',
        $EMPTY,
    );

    const my $LOWEST_PRIORITY => scalar @KML_LINE_TYPES;

    const my %KML_LINE_COLORS => (
        Tempo                => 'FFC8AB00',
        Rapid                => 'FF4040FF',
        Transbay             => 'FF00FF00',
        'Dumbarton Express'  => 'FFFF8000',
        'Broadway Shuttle'   => 'FF00FFC0',
        'All Nighter'        => 'FF80FFFF',
        Local                => 'FF80FFFF',
        'Service to Schools' => 'FFC0A0FF',
        'Early Bird'         => 'FFD09300',
        # flex is 301DAF - multiplied by 1.46
        Flex   => 'FF462AFF',
        $EMPTY => 'FF80FFFF',
    );

    func _kml_inactive_color { $KML_LINE_COLORS{$EMPTY} }

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

    sub _kml_line_color {
        my $lines_r = shift;
        my @lines   = @_;
        my $priority
          = Actium::min( map { _kml_priority( $lines_r, $_ ) } @lines );
        return $color_of_priority{$priority};
    }

}

func signinfo (:$actiumdb) {

    # set up database query

    \my %signs = $actiumdb->all_in_columns_key(
        {   TABLE   => 'Signs',
            COLUMNS => [qw/stp_511_id Active SignType/],
        }
    );

    \my %classification_of_type = $actiumdb->all_in_column_key(
        {   TABLE  => 'SignTypes',
            COLUMN => ['SignClassification'],
        }
    );

    my ( %signtypes_of, %signtype_texts_of );

    foreach my $signid ( keys %signs ) {
        my $stopid = $signs{stp_511_id};
        push $signtypes_of{$stopid}->@*, $signs{SignType};
        push $signtype_texts_of{$stopid}->@*,
          $signs{SignType} . ( $signs{Active} eq 'Sort of' ? '*' : '' );
    }

    my ( %signtype_text_of, %classification_of );

    foreach my $stopid ( keys %signtypes_of ) {
        my @signtypes = $signtypes_of{$stopid}->@*;
        my @classifications
          = Actium::uniq( map { $classification_of_type{$_} } @signtypes );
        $classification_of{$stopid}
          = @classifications == 1 ? $classifications[0] : 'Multiple';
        $signtype_text_of{$stopid}
          = join( " / ", sort %signtype_texts_of{$stopid} );
    }

    return \%signtype_text_of, \%classification_of;

}

{
    # colors for  workzone hash

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

    const my @HASH_COLORS =>
      map { '#FF' . join( $EMPTY, reverse( $_ =~ /../g ) ) } @RGBS;
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

}

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

