# /Actium/Cmd/XheaImport.pm
#
# Takes XML files exported from Hastus and imports them

package Actium::Cmd::XheaImport 0.010;

use Actium::Preamble;
use Actium::Files::Xhea;
use Actium::Cmd::Config::Signup ('signup');

sub OPTIONS {
    my ($class, $env) = @_;
    return ( Actium::Cmd::Config::Signup::options($env));
}

sub START {


    my ( $class, $env ) = @_;
    my $signup = signup($env);
    
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

