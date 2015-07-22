# Actium/Cmd/Config/Flickr_Auth.pm

# Configuration and command-line options for Flickr authentification

# legacy stage 4

package Actium::Cmd::Config::Flickr_Auth 0.010;

use Actium::Preamble;
use Actium::O::Photos::Flickr::Auth;

use Sub::Exporter ( -setup => { exports => [qw(flickr_auth)] } );    ### DEP ###

my %description_of_option = (
    key    => 'Flickr API key',
    secret => 'Flickr API secret',
);

sub OPTIONS {
    my @optionlist;

    foreach ( keys %description_of_option ) {
        push @optionlist, [ "flickr_$_=s", $description_of_option{$_} ];
    }

    return @optionlist;

}

const my $CONFIG_SECTION => 'Flickr';

sub flickr_auth {
    
    my $env = shift;
    my $config_obj = $env->config;

    my %config     = $config_obj->section($CONFIG_SECTION);

    my %params;
    foreach ( keys %description_of_option ) {

        my $optname = "flickr_$_";
        $params{$_} = $env->option($optname) // $config{$_}
          // Actium::Cmd::term_readline( $description_of_option{$_} . ':' );

    }

    my $flickr_auth = Actium::O::Photos::Flickr::Auth->new(%params);
    return $flickr_auth;

}

1;

__END__
