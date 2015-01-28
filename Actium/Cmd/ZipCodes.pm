# /Actium/Cmd/ZipCodes.pm

package Actium::Cmd::ZipCodes 0.009;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM     ('actiumdb');
use Actium::Cmd::Config::GeonamesAuth ('geonames_username');

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

    my $client = REST::Client->new();

    my $stopinfo_r = $actium_db->all_in_columns_key(
        qw/Stops_Neue p_zip_code h_loca_latitude h_loca_longitude/);

    #my $count = 0;
    foreach my $stopid ( keys %$stopinfo_r ) {
        next if $stopinfo_r->{$stopid}{p_zip_code};

        my $lat  = $stopinfo_r->{$stopid}{h_loca_latitude};
        my $long = $stopinfo_r->{$stopid}{h_loca_longitude};
        next unless $lat and $long;

        #$count++;
        #last if $count > 5;    # testing

        my $request = 'http://api.geonames.org/findNearbyPostalCodesJSON?';

        my @args =
          ( "lat=$lat", "lng=$long", 'maxRows=1', "username=$username" );

        $request .= join( "&", @args );

        #say $request;

        $client->GET($request);
        my $json   = $client->responseContent();
        my $struct = decode_json($json);

        my $zipcode = $struct->{postalCodes}[0]{postalCode};

        say "$stopid\t$zipcode";

        sleep( int( 1 + rand(2) ) );

    }

    return;

}

1;

__END__
