# /Actium/Cmd/XheaImport.pm
#
# Takes XML files exported from Hastus and imports them

# Subversion: $Id$

package Actium::Cmd::XheaImport 0.009;

use Actium::Preamble;
use Actium::Files::Xhea;
use Actium::O::Folders::Signup;

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $signup      = Actium::O::Folders::Signup->new();
    my $xhea_folder = $signup->subfolder('xhea');
    my $tab_folder  = $xhea_folder->subfolder('tab');

    Actium::Files::Xhea::xhea_import(
        signup      => $signup,
        xhea_folder => $xhea_folder,
        tab_folder  => $tab_folder
    );
    return;

}    ## tidy end: sub START

1;

