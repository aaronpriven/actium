package Actium::Cmd::CitiesByLine 0.011;

use Actium::Preamble;
use Actium::StopReports;

sub OPTIONS {
    return 'actiumdb';
}

sub HELP {
    say "citiesbyline: produce list of cities by line for GovDelivery.";
    return;
}

sub START {
    my ( $class, $env ) = @_;
    my $cry = cry("Producing ciies by line report for web site");
    my $actiumdb = $env->actiumdb;
    Actium::StopReports::citiesbyline(actiumdb => $actiumdb);
    $cry->done;

}

1;

__END__
