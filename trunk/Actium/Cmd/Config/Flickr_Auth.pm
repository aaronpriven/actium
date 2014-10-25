# Actium/Cmd/Config/Flickr_Auth.pm

# Configuration and command-line options for Flickr authentification

# Subversion: $Id$

# legacy stage 4

package Actium::Cmd::Config::Flickr_Auth 0.007;

use Actium::Preamble;
use Actium::Options qw(option add_option);
use Actium::Term;
use Actium::O::Photos::Flickr::Auth;

use Sub::Exporter -setup => { exports => [qw(flickr_auth)] };

my %description_of_option = (
    key    => 'Flickr API key',
    secret => 'Flickr API secret',
);

foreach ( keys %description_of_option ) {
    add_option "flickr_$_=s", $description_of_option{$_};
}

const my $CONFIG_SECTION => 'Flickr';

sub flickr_auth {

    my $config_obj = shift;
    my %config     = $config_obj->section($CONFIG_SECTION);
    
    my %params;
    foreach ( keys %description_of_option ) {

        my $optname = "flickr_$_";
        $params{$_} = option($optname) // $config{$_}
          // Actium::Term::term_readline( $description_of_option{$_} . ':' );

    }

    my $flickr_auth = Actium::O::Photos::Flickr::Auth->new(%params);
    return $flickr_auth;

}

1;

__END__
