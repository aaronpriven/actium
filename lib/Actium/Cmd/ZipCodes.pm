# /Actium/Cmd/ZipCodes.pm

# Gets zip codes for stops from geonames.org

package Actium::Cmd::ZipCodes 0.010;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM     ('actiumdb');
use Actium::Cmd::Config::GeonamesAuth ('geonames_username');
use Actium::Geo('get_zip_for_stops');

use REST::Client;    ### DEP ###
use JSON;            ### DEP ###

sub HELP {
    say 'Using the geonames.org server, gets zip codes for stops'
      . q{that don't have them.};
    return;
}

sub OPTIONS {

    my ( $class, $env ) = @_;
    return (
        Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        Actium::Cmd::Config::GeonamesAuth::OPTIONS($env),
    );
}

sub START {
    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);
    my $username = geonames_username($env);

    my $zip_code_of_r = get_zip_for_stops(
        actiumdb => $actiumdb,
        username => $username,
    );

    # TODO: specify sleep and max with options

    say "h_stp_511_id\tp_zip_code";

    foreach my $stopid ( sort keys %{$zip_code_of_r} ) {
        say "$stopid\t", $zip_code_of_r->{$stopid};
    }

    return;

} ## tidy end: sub START

1;