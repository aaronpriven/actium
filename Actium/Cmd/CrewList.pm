# /Actium/Cmd/CrewList.pm

# Gets the active stops, by crew assignment, and create the stop list for it.

# legacy stage 4

use 5.016;
use warnings;

package Actium::Cmd::CrewList 0.010;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::StopReports('crewlist_xlsx');
use Actium::Cmd::Config::Signup ('signup');

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

sub OPTIONS {
    my ($class, $env) = @_;
    return (Actium::Cmd::Config::ActiumFM::OPTIONS($env), 
    Actium::Cmd::Config::Signup::options($env));
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb   = actiumdb($env);
    my @argv = $env->argv;
    my $outputfile = shift @argv;

    unless ($outputfile) {
        $class->HELP($env);
        return;
    }

    my $slistsdir = signup($env, 'slists');
    
    # retrieve data
    my $stops_of_r = $slistsdir->retrieve('line.storable')
      or die "Can't open line.storable file: $OS_ERROR";

    my $signup_display = $slistsdir->signup;

    crewlist_xlsx(
        outputfile       => $outputfile,
        actiumdb         => $actiumdb,
        stops_of_linedir => $stops_of_r,
        signup_display   => $signup_display,
    );

    return;
} ## tidy end: sub START

1;

__END__
