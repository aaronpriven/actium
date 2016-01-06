# Actium/Cmd/LineDescrip.pm

# Produces line descriptions from the Lines database
# Also produces transit hubs sheet, so should be renamed to something else.
# Possibly combine with slists2html

# legacy status: 4

use warnings;
use 5.016;

package Actium::Cmd::LineDescrip 0.010;

use Actium::Preamble;

use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup   ('signup');

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
linedescrip. Creates line description file.
HELP

    return;
}

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        Actium::Cmd::Config::Signup::options($env)
    );
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);

    my $signup = signup($env);

    my $html_descrips = $actiumdb->line_descrip_html( { signup => $signup, } );

    my $outfh = $signup->open_write('line_descriptions.html');
    say $outfh $html_descrips;
    close $outfh or die $OS_ERROR;

    my $html_hubs = $actiumdb->lines_at_transit_hubs_html;

    my $outhubs = $signup->open_write('transithubs.html');
    say $outhubs $html_hubs;
    close $outhubs or die $OS_ERROR;

    \my %descrips_of_hubs_indesign
      = $actiumdb->descrips_of_transithubs_indesign( { signup => $signup } )
      ;

    my $line_descrip_folder = $signup->subfolder('line_descrip');

    $line_descrip_folder->write_files_from_hash( \%descrips_of_hubs_indesign,
        'Indesign Line Description', 'txt' );

    return;

} ## tidy end: sub START

1;
