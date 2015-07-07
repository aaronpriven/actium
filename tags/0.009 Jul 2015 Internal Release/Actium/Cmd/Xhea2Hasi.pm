# /Actium/Cmd/Xhea2Hasi.pm
#
# Takes tab files that are result of XheaImport, and mocks up hasi files

# Subversion: $Id$

package Actium::Cmd::Xhea2Hasi 0.005;

use Actium::Preamble;
use Actium::Files::Xhea;
use Actium::O::Folders::Signup;

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $signup      = Actium::O::Folders::Signup->new();
    my $xhea_tab_folder = $signup->subfolder('xhea' , 'tab');
    my $hasi_folder = $signup->subfolder('hasi');
    
    Actium::Files::Xhea::to_hasi($xhea_tab_folder, $hasi_folder);

} ## tidy end: sub START

1;

