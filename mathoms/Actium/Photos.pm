# Actium/Photos.pm

# Library to work on photos

package Actium::Photos 0.010;

__END__ 
# eliminate old dependency

use Actium::Preamble;
use Flickr::API2; ### DEP ###

sub flickr_stops {
    my $flickr_auth = shift;

    my $flickr = Flickr::API2->new(
        {   key    => $flickr_auth->key,
            secret => $flickr_auth->secret,
        }
    );

    my $nsid = $flickr->people->findByUsername('ac_service_info')->{NSID};
    
    my $result = $flickr->execute_method( 'flickr.photosets.getList',
        { user_id => $nsid } );


   # I got this far, and then I started looking into user authentication,
   # which should be needed when changing titles. And then it got complicated,
   # with OAuth.

}

1;

__END__

  my @photos = $flickr->people->findByUsername('wintrmute')
                   ->getPublicPhotos(per_page => 10);

  for my $photo (@photos) {
    say "Title is " . $photo->title;
  }

  #Individual photos can be retrieved by id like so:

  my $p = $flickr->photos->by_id(1122334455);
  say "Medium JPEG is " . $p->url_m;

  #To access the raw flickr API, use methods like:

  my $response = $flickr->execute_method('flickr.test.echo', {
        'foo' => 'bar',
        'baz' => 'quux',
    }
  );
