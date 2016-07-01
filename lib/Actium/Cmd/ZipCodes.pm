# /Actium/Cmd/ZipCodes.pm

# Gets zip codes for stops from geonames.org

package Actium::Cmd::ZipCodes 0.010;

use Actium::Preamble;
use Actium::Geo('get_zip_for_stops');

use REST::Client;    ### DEP ###
use JSON;            ### DEP ###

sub HELP {
    say 'Using the geonames.org server, gets zip codes for stops'
      . q{that don't have them.};
    return;
}

sub OPTIONS {
    return qw/geonames actiumdb/;
}

sub START {
    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;
    my $username = $env->geonames_username;

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
