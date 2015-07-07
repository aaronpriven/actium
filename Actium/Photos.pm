# Actium/Photos.pm

# Library to work on photos

# Subversion: $Id: Photos.pm 483 2014-10-25 00:07:17Z aaronpriven $

package Actium::Photos 0.007;

use Actium::Preamble;
use Flickr::API2;
use Actium::Term;

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

    emit_text " ";

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
