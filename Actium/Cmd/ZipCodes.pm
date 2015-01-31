# /Actium/Cmd/ZipCodes.pm

# Gets zip codes for stops from geonames.org

# Subversion: $Id$

package Actium::Cmd::ZipCodes 0.009;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM     ('actiumdb');
use Actium::Cmd::Config::GeonamesAuth ('geonames_username');
use Actium::Geo('get_zip_for_stops');

use REST::Client;
use JSON;

sub HELP {
    say "Using the geonames.org server, gets zip codes for stops"
      . q{that don't have them.};
}

sub START {
    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};
    my $actium_db  = actiumdb($config_obj);
    my $username   = geonames_username($config_obj);

    my $zip_code_of_r = get_zip_for_stops(
        actiumdb => $actium_db,
        username => $username,
    );

    # TODO: specify sleep and max with options

    say "h_stp_511_id\tp_zip_code";

    foreach my $stopid ( sort keys %{$zip_code_of_r} ) {
        say "$stopid\t", $zip_code_of_r->{$stopid};
    }

    return;

}

1;

__END__

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};
    my $actium_db  = actiumdb($config_obj);
    my $username   = geonames_username($config_obj);

    my $client = REST::Client->new();

    my $stopinfo_r = $actium_db->all_in_columns_key(
        qw/Stops_Neue c_city p_zip_code h_loca_latitude h_loca_longitude/);

    my $count = 0;
    
    say "h_stp_511_id\tp_zip_code";
    
    foreach my $stopid ( keys %$stopinfo_r ) {
        next if $stopinfo_r->{$stopid}{p_zip_code};
        #next if $stopinfo_r->{$stopid}{c_city} ne 'Oakland';

        my $lat  = $stopinfo_r->{$stopid}{h_loca_latitude};
        my $lng = $stopinfo_r->{$stopid}{h_loca_longitude};
        next unless $lat and $lng;

        $count++;
        last if $count > 800;    # testing

        my $request = 'http://api.geonames.org/findNearbyPostalCodesJSON?';

        my @args =
          ( "lat=$lat", "lng=$lng", 'maxRows=1', "username=$username" );

        $request .= join( "&", @args );

        #say $request;

        $client->GET($request);
        my $json   = $client->responseContent();
        my $struct = decode_json($json);
        
        my $zipcode = $struct->{postalCodes}[0]{postalCode};
        
        say "$stopid\t$zipcode"
           if $zipcode;

    }

    return;

}

1;

__END__
