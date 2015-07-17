# /Actium/Cmd/TheaImport.pm

# Takes the THEA files and imports them so Actium can use them.

# Legacy status: 4

use 5.014;
use warnings;

package Actium::Cmd::TheaImport 0.010;

use Actium::Files::Thea::Import ('thea_import');
use Actium::Cmd::Config::Signup ('signup');

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium theaimport -- read THEA files from Scheduling, creating
long-format Sked files for use by the rest of the Actium system,
as well as processing stops and places files for import.
HELP

    Actium::Term::output_usage();

}

sub OPTIONS {
    my ($class, $env) = @_;
    return ( Actium::Cmd::Config::Signup::options($env));
}

sub START {
    my ( $class, $env ) = @_;
    my $signup = signup($env);

    my $theafolder = $signup->subfolder('thea');
    
    thea_import ($signup, $theafolder);

} ## tidy end: sub START

1;

__END__
