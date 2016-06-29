# Actium/Cmd/Flickr_Stops.pm

# work with photos in flickr

# legacy stage 4

package Actium::Cmd::Flickr_Stops 0.010;

use Actium::Preamble;
use Actium::Photos;

sub OPTIONS {
   return 'flickr';
}

sub START {
    
    my $cry = cry( 'Processing Flickr photos');

    my $class      = shift;
    my $env = shift;
    
    my $flickr_auth = $env->flickr_auth;
    
    Actium::Photos::flickr_stops($flickr_auth);
    
    $cry->done;

}

1;

__END__
