# Actium/Cmd/Config/GeonamesAuth.pm

# Configuration and command-line options for Geonames authentification

package Actium::Cmd::Config::GeonamesAuth 0.010;

use Actium::Preamble;
use Actium::Options qw(option add_option);
use Actium::Term;
use Actium::O::Photos::Flickr::Auth;

use Sub::Exporter -setup => { exports => [qw(geonames_username)] };

my %description_of_option = ( username => 'Geonames API username', );

foreach ( keys %description_of_option ) {
    add_option "geonames_$_=s", $description_of_option{$_};
}

const my $CONFIG_SECTION => 'Geonames';

sub geonames_username {

    my $config_obj = shift;
    my %config     = $config_obj->section($CONFIG_SECTION);

    my %params;
    foreach ( keys %description_of_option ) {

        my $optname = "geonames_$_";
        $params{$_} = option($optname) // $config{$_}
          // Actium::Term::term_readline( $description_of_option{$_} . ':' );
    }

    return $params{username};

}

1;

__END__
