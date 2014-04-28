# /Actium/Cmd/AddDescriptionF.pm

# Adds the DescriptionF from the XML file to a stop list given, so that
# <stopid>\t<arbitrarytext> 
# turns to
# <stopid>\t<DescriptionF>\t<arbitrarytext>

# Subversion: $Id$

# Legacy status: well, 4, but not necessarily intended as a permanent thing

package Actium::Cmd::AddDescriptionF 0.001;

use 5.012;
use warnings;

use autodie;

use Actium::O::Folders::Signup;
use Actium::O::Files::FMPXMLResult;
use Actium::Term;

sub HELP { say "Help not implemented"; }

sub START {
 
   my $signup = Actium::O::Folders::Signup->new;
   
   my $xml_db = $signup->load_xml;
   $xml_db->ensure_loaded('Stops');
   
    emit 'Getting stop descriptions from FileMaker export';

    my $dbh = $xml_db->dbh;

    my $stops_row_of_r =
      $xml_db->all_in_columns_key(qw/Stops DescriptionCityF/);

    emit_done;

 
   my $file = shift @ARGV || '-' ; # stdin
   
   
   open my $in, '<' , $file;
   
   binmode STDOUT, ":utf8";
   
   while (<$in>) {
       chomp;
    
       my ($stopid, $text) = split (/\t/, $_, 2);
       $text //= q[];
       my $desc = $stops_row_of_r->{$stopid}{DescriptionCityF};
       if (not defined $desc) {
          if ( $stopid =~ /Stop\s*ID/i) {
              $desc = "DescriptionCityF";
          } else {
          $desc = "** NOT FOUND **";
          warn "No description found for $stopid";
           }
       }
       say "$stopid\t$desc\t$text";
       
   }
   
   
 
 
}

1;
