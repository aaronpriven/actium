# /Actium/Cmd/XheaImport.pm
#
# Takes XML files exported from Hastus and imports them 

# Subversion: $Id$

package Actium::Cmd::XheaImport 0.003;

use Actium::Preamble;
use Actium::Files::Xhea;
use Actium::O::Folders::Signup;

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $signup      = Actium::O::Folders::Signup->new();
    my $xhea_folder = $signup->subfolder('xhea');

    my ($fields_of_r, %adjusted_values_of_r) = 
       Actium::Files::Xhea::load_adjusted($xhea_folder);

    return;

} ## tidy end: sub START

1;
