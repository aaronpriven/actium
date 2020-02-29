package Octium::Geo 0.012;

# Geocoding, geodesy, etc.

use Actium;
use Octium;

use REST::Client;    ### DEP ###
use JSON;            ### DEP ###
use Math::Trig (qw(deg2rad asin ));    ### DEP ###

use Sub::Exporter -setup => {
    exports => [
        qw(
          get_zip_for_stops zip_code_request distance_feet
          )
    ]
};
# Sub::Exporter ### DEP ###

# This arguably should be replaced with GIS::Distance or something

const my $RADIUS => 3956.6 * 5280;    # feet

sub distance_feet {

    # Haversine, from http://www.perlmonks.org/?node_id=150054
    my ( $lat1, $long1, $lat2, $long2 ) = @_;

    my $dlong = deg2rad($long1) - deg2rad($long2);
    my $dlat  = deg2rad($lat1) - deg2rad($lat2);

    my $a = sin( $dlat / 2 )**2
      + cos( deg2rad($lat1) ) * cos( deg2rad($lat2) ) * sin( $dlong / 2 )**2;
    my $c = 2 * ( asin( sqrt($a) ) );
    my $dist = $RADIUS * $c;

    return $dist;    # returns in feet

}

func get_zip_for_stops (
   REST::Client :$client  = REST::Client->new() ,
   Str :$username!,
   Int :$sleep,
   Int :$max,
   :$actiumdb! where { $_->can('all_in_columns_key') },
   ) {

    my $stopinfo_r = $actiumdb->all_in_columns_key(
        qw/Stops_Neue c_city p_zip_code h_loca_latitude h_loca_longitude/);

    my %zip_code_of;
    my $count = 0;
    foreach my $stopid ( keys %$stopinfo_r ) {
        next if $stopinfo_r->{$stopid}{p_zip_code};

        #next if $stopinfo_r->{$stopid}{c_city} ne 'Oakland';

        my $lat = $stopinfo_r->{$stopid}{h_loca_latitude};
        my $lng = $stopinfo_r->{$stopid}{h_loca_longitude};
        next unless $lat and $lng;

        if ($max) {
            $count++;
            last if $count > $max;
        }

        my $zipcode = zip_code_request(
            client   => $client,
            lat      => $lat,
            lng      => $lng,
            username => $username
        );

        $zip_code_of{$stopid} = $zipcode if $zipcode;

        sleep($sleep) if $sleep;

    }    ## tidy end: foreach my $stopid ( keys %$stopinfo_r)

    return \%zip_code_of;

}    ## tidy end: func get_zip_for_stops

func zip_code_request (
     REST::Client :$client = REST::Client->new() ,
     :$lat! ,
     :$lng! ,
     Str :$username!,
   ) {

    my $request = 'http://api.geonames.org/findNearbyPostalCodesJSON?';

    my @args = ( "lat=$lat", "lng=$lng", 'maxRows=1', "username=$username" );

    $request .= join( "&", @args );
    $client->GET($request);
    my $json   = $client->responseContent();
    my $struct = decode_json($json);

    my $zipcode = $struct->{postalCodes}[0]{postalCode};

    return $zipcode;

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

