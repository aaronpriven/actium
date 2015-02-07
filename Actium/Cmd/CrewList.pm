# /Actium/Cmd/CrewList.pm

# Gets the active stops, by crew assignment, and create the stop list for it.

# Subversion: $Id$

# legacy stage 4

use 5.016;
use warnings;

package Actium::Cmd::CrewList 0.009;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::CrewList('crewlist_xlsx');
use Actium::O::Folders::Signup;

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium crewlist -- create list of stops for the crew, ordered by travel route

Usage:

actium crewlist <outputfile>

Takes all active stops in the database, divides them into crew assignments,
and produces a result file (in Excel) with the stops ordered by travel 
along the bus stops.
HELP

    output_usage();

    return;

}

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};
    my $actium_db  = actiumdb($config_obj);
    my $outputfile = shift @{ $params{argv} };

    unless ($outputfile) {
        HELP();
        return;
    }

    my $slistsdir = Actium::O::Folders::Signup->new('slists');

    # retrieve data
    my $stops_of_r = $slistsdir->retrieve('line.storable')
      or die "Can't open line.storable file: $OS_ERROR";

    my $signup_display = $slistsdir->signup;

    crewlist_xlsx(
        outputfile       => $outputfile,
        actiumdb         => $actium_db,
        stops_of_linedir => $stops_of_r,
        signup_display   => $signup_display,
    );

}

1;

__END__
