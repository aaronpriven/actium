# /Actium/Cmd/Xhea2Hasi.pm
#
# Takes tab files that are result of XheaImport, and mocks up hasi files

package Actium::Cmd::Xhea2Hasi 0.010;

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

    my $xhea_tab_folder = $signup->subfolder('xhea' , 'tab');
    my $hasi_folder = $signup->subfolder('hasi');
    
    Actium::Files::Xhea::to_hasi($xhea_tab_folder, $hasi_folder);

} ## tidy end: sub START

1;

