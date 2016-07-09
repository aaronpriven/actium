package Actium::Cmd::XheaImport 0.011;

# Takes XML files exported from Hastus and imports them

use Actium::Preamble;
use Actium::Files::Xhea;

sub OPTIONS {
    return 'signup';
}

sub START {


    my ( $class, $env ) = @_;
    my $signup = $env->signup;
    
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

