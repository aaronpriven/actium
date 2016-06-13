# /Actium/Geo.pm

# Geocoding, geodesy, etc.

package Actium::Geo 0.010;

use Actium::Preamble;

use REST::Client; ### DEP ###
use JSON; ### DEP ###
use Math::Trig   (qw(deg2rad asin ));   ### DEP ###

use Sub::Exporter -setup => {
    exports => [
        qw(
          get_zip_for_stops zip_code_request distance_feet
          )
    ]
};
# Sub::Exporter ### DEP ###

# This arguably should be replaced with GIS::Distance or something

const my $RADIUS => 3956.6 * 5280;  # feet

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

sub get_zip_for_stops {

    my %params = u::validate(
        @_,
        {
            client   => { isa  => 'REST::Client',   optional => 1 },
            actiumdb => { can  => 'all_in_columns_key' },
            username => { type => $PV_TYPE{SCALAR} },
            sleep    => { type => $PV_TYPE{SCALAR}, optional => 1 },
            max      => { type => $PV_TYPE{SCALAR}, optional => 1 },
        }
    );

    my $client    = $params{client} // REST::Client->new();
    my $username  = $params{username};
    my $actium_db = $params{actiumdb};
    my $sleep     = $params{sleep};
    my $max       = $params{max};

    my $stopinfo_r = $actium_db->all_in_columns_key(
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

    }

    return \%zip_code_of;

}

sub zip_code_request {
    my %params = u::validate(
        @_,
        {
            client   => { isa  => 'REST::Client', optional => 1 },
            lat      => { type => $PV_TYPE{SCALAR} },
            lng      => { type => $PV_TYPE{SCALAR} },
            username => { type => $PV_TYPE{SCALAR} },
        }
    );

    my $client = $params{client} // REST::Client->new();
    my $lat    = $params{lat};
    my $lng    = $params{lng};

    my $request = 'http://api.geonames.org/findNearbyPostalCodesJSON?';

    my @args =
      ( "lat=$lat", "lng=$lng", 'maxRows=1', "username=$params{username}" );

    $request .= join( "&", @args );

    $params{client}->GET($request);
    my $json   = $client->responseContent();
    my $struct = decode_json($json);

    my $zipcode = $struct->{postalCodes}[0]{postalCode};

    return $zipcode;

}

1;

__END__
