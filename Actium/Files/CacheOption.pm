#!/Actium/Files/CacheOption.pm

# All this does is have a single place to ensure that option('cache') exists
# and isn't duplicated

# Subversion: $Id$

# legacy status: 4

use 5.012;
use warnings;

package Actium::Files::CacheOption 0.001;

use Actium::Options('add_option');

add_option( 'cache=s',
        'Cache directory. Files (like SQLite files) that cannot be stored '
      . 'on network filesystems are stored here.' );

1;

__END__
