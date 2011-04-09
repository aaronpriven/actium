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

    my $signup           = Actium::Signup->new();
    my $pattern_folder   = $signup->subdir('patterns');
    my $stoplists_folder = $signup->subdir('slists');

    my %stop_obj_of  = %{ $pattern_folder->retrieve('stops.storable') };
    my %route_obj_of = %{ $pattern_folder->retrieve('routes.storable') };

    my $xml_db  = $signup->load_xml;
    my $hasi_db = $signup->load_hasi;

    emit "Making stop lists";

    my %stops_of_line;

    foreach my $route_obj ( sortbyline keys %route_obj_of ) {
        my $route = $route_obj->route;
        emit_over($route);

        my @stoplist_objs;
        foreach my $dir ( $route_obj->dircodes ) {

=for TODO
      
    
      open my $fh , '>' , "slists/line/$route-$dir.txt" or die "Cannot open slists/line/$route-$dir.txt for output";
      print $fh jt( $route , $dir ) , "\n" ;
      foreach (@union) {
         print $fh jt($_, $stp{$_}{Description}) , "\n";
      }
      close $fh;
      
=cut

        }

    }

    $stoplists_folder->store( \%stops_of_line, "slists/line.storable" );

}

package Actium::MakeStopLists::DirList 0.001;

1;

__END__
