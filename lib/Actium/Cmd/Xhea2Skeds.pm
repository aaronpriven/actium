package Actium::Cmd::Xhea2Skeds 0.012;

# Takes tab files that are result of XheaImport, and makes schedules

use Actium::Preamble;
use Actium::Files::Xhea::ToSkeds;

sub OPTIONS {
    return ( 'signup', 'actiumdb' );
}

sub START {

    my ( $class, $env ) = @_;
    my $signup   = $env->signup;
    my $actiumdb = $env->actiumdb;

    my $xhea_tab_folder = $signup->subfolder( 'xhea', 'tab' );
    my $xhea_skeds_folder = $signup->subfolder('xheaskeds');

    Actium::Files::Xhea::ToSkeds::xheatab2skeds(
        actiumdb        => $actiumdb,
        signup => $signup,
    );

}

1;

