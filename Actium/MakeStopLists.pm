# Actium/MakeStopLists.pm

# Program for making stop lists

# Subversion: $Id$

# legacy status: 4

use 5.012;
use warnings;

package Actium::MakeStopLists 0.001;

use Actium::Signup;
use Actium::Patterns::Stop;
use Actium::Patterns::Route;
use Actium::Term;
use Actium::Sorting('sortbyline');

sub START {

    my $pattern_folder   = Actium::Signup->new('patterns');
    my $stoplists_folder = Actium::Signup->new('slists');

    my %stop_obj_of  = %{ $pattern_folder->retrieve('stops.storable') };
    my %route_obj_of = %{ $pattern_folder->retrieve('routes.storable') };
    
my %stops_of_line;

emit "Making stop lists";

}
__END__
# hidden behind END to allow committing without errors

foreach my $route_obj (sortbyline keys %route_obj_of) {
   my $route = $route_obj->route;
   emit_over($route);
      
   my @stoplist_objs;
   foreach my $dir ($route_obj->dircodes) {
      
      
    
      open my $fh , '>' , "slists/line/$route-$dir.txt" or die "Cannot open slists/line/$route-$dir.txt for output";
      print $fh jt( $route , $dir ) , "\n" ;
      foreach (@union) {
         print $fh jt($_, $stp{$_}{Description}) , "\n";
      }
      close $fh;
      
   
   }
}

print "\n\n";

Storable::nstore (\%stops_of_line , "slists/line.storable");
    
    
    
}
      
package Actium::MakeStopLists::DirList 0.001;



1;

__END__
