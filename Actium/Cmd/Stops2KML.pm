# /Actium/Cmd/Stops2KML.pm

# Creates KML output of stops

# legacy stage 4

use 5.016;
use warnings;

package Actium::Cmd::Stops2KML 0.010;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::StopReports('stops2kml');
use File::Slurp::Tiny('write_file');    ### DEP ###

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium stops2kml -- create list of stops in KML for Google Earth

Usage:

actium stops2kml <outputfile>

Takes all stops in the database and produces a KML file 
with the bus stop information.
HELP

    output_usage();

    return;

}

sub OPTIONS {
    return Actium::Cmd::Config::ActiumFM::OPTIONS();
}

sub START {
    my ( $class, %params ) = @_;
    my $actiumdb = actiumdb(%params);

    my $outputfile = shift @{ $params{argv} };

    unless ($outputfile) {
        HELP();
        return;
    }

    my $kml_text = stops2kml($actiumdb);

    write_file( $outputfile, $kml_text, binmode => ':utf8' );

    return;

}

1;

__END__
