package Actium::Cmd::Stops2KML 0.011;

# Creates KML output of stops

use 5.016;
use warnings;

use Actium::Preamble;
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

    return;

}

sub OPTIONS {
    return (
        'actiumdb',
        {   spec           => 'workzones',
            description    => 'Create KML for work zones instead of by stop',
            fallback       => '0',
            envvar         => 'STOPS2KML_WORKZONES',
            config_section => 'Stops2KML',
            config_key     => 'WorkZones',
        },
    );
}

sub START {
    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;
    my @argv     = $env->argv;

    my $outputfile = shift @argv;

    unless ($outputfile) {
        HELP();
        return;
    }

    my $workzones = $env->option('workzones');

    my $kml_text = stops2kml( $actiumdb, $workzones );

    write_file( $outputfile, $kml_text, binmode => ':utf8' );

    return;

} ## tidy end: sub START

1;

__END__
