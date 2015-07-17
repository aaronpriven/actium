# Actium/Cmd/Config/GeonamesAuth.pm

# Configuration and command-line options for Geonames authentification

package Actium::Cmd::Config::GeonamesAuth 0.010;

use Actium::Preamble;
use Actium::Term;
use Actium::O::Photos::Flickr::Auth;

use Sub::Exporter ( -setup => { exports => [qw(geonames_username)] } );
# Sub::Exporter  ### DEP ###

my %description_of_option = ( username => 'Geonames API username', );

sub OPTIONS {
    my @optionlist;

    foreach ( keys %description_of_option ) {
        push @optionlist, [ "geonames_$_=s", $description_of_option{$_} ];
    }

    return @optionlist;

}

const my $CONFIG_SECTION => 'Geonames';

sub geonames_username {

    my $env = shift;
    my $config_obj = $env->config;
    my %config = $config_obj->section($CONFIG_SECTION);

    my %params;
    foreach ( keys %description_of_option ) {

        my $optname = "geonames_$_";
        $params{$_} = $env->option($optname) // $config{$_}
          // Actium::Term::term_readline( $description_of_option{$_} . ':' );
    }

    return $params{username};

} ## tidy end: sub geonames_username

1;

__END__
