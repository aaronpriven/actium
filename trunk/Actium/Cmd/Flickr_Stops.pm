# Actium/Cmd/Flickr_Stops.pm

# work with photos in flickr

# Subversion: $Id: Flickr_Stops.pm 483 2014-10-25 00:07:17Z aaronpriven $

# legacy stage 4

package Actium::Cmd::Flickr_Stops 0.007;

use Actium::Preamble;
use Actium::Photos;
use Actium::Term;
use Actium::Cmd::Config::Flickr_Auth('flickr_auth');

sub HELP {
    say "Help not implemented.";
}

sub START {
    
    emit 'Processing Flickr photos';

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};
    
    my $flickr_auth = flickr_auth($config_obj);
    
    Actium::Photos::flickr_stops($flickr_auth);
    
    emit_done;

}

1;

__END__