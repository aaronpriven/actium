# /Actium/OrderStopsByRoute.pm

# Takes a list of stops and order it so that people can drive down a
# particular bus route and hit as many stops as possible.

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::OrderStopsByRoute 0.001;

use sort ('stable');

# add the current program directory to list of files to include

use Carp;
use Storable();

use Actium::Sorting(qw<travelsort>);
use Actium::Constants;

use Actium::Options;
use Actium::Signup;

sub sortbytravelroute {
    my $linedirs_of_r = shift;

    # keys - stop IDs, values - arrayref of linee/dir combinations

    my $slistsdir = Actium::Signup->new('slists');

    # retrieve data
    my $stops_of_r = $slistsdir->retrieve('line.storable')
      or die "Can't open line.storable file: $!";

    travelsort( $linedirs_of_r, $stops_of_r );

}

1;

__END__

