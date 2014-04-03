# /Actium/Cmd/XheaImport.pm
#
# Takes XML files exported from Hastus and imports them

# Subversion: $Id$

package Actium::Cmd::XheaImport 0.003;

use Actium::Preamble;
use Actium::Files::Xhea;
use Actium::Import::CalculateFields;
use Actium::O::Folders::Signup;

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $signup      = Actium::O::Folders::Signup->new();
    my $xhea_folder = $signup->subfolder('xhea');

    my ( $fieldnames_of_r, $fields_of_r, $adjusted_values_of_r )
      = Actium::Files::Xhea::load_adjusted($xhea_folder);

    my $tab_strings_r
      = Actium::Files::Xhea::tab_strings( $fieldnames_of_r, $fields_of_r, 
        $adjusted_values_of_r );
      
    my $tab_folder = $xhea_folder->subfolder('tab');
    
    $tab_folder->write_files_from_hash($tab_strings_r, qw(tab txt));
    
    $tab_folder->json_store_pretty( $fields_of_r, 'records.json' );

    return;

}

1;


