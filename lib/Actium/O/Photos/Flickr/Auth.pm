# Actium/O/Photos/Flickr/Auth.pm

# Object representing Flickr authentication information (api key, & secret, 
# OAuth user [consumer] keys and secrets )

package Actium::O::Photos::Flickr::Auth 0.010;

use Actium::Moose;

has [qw/key secret/]  => (
   isa => 'Str',
   is => 'ro',
   required => 1,
);

# TO DO : User info

1;

__END__
