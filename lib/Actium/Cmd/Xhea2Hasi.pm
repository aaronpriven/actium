package Actium::Cmd::Xhea2Hasi 0.011;

# Takes tab files that are result of XheaImport, and mocks up hasi files

use Actium::Preamble;
use Actium::Files::Xhea;

sub OPTIONS {
    return 'signup';
}

sub START {

    my ( $class, $env ) = @_;
    my $signup = $env->signup;

    my $xhea_tab_folder = $signup->subfolder('xhea' , 'tab');
    my $hasi_folder = $signup->subfolder('hasi');
    
    Actium::Files::Xhea::to_hasi($xhea_tab_folder, $hasi_folder);

} ## tidy end: sub START

1;

