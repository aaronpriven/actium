# /Actium/Cmd/TheaImport.pm

# Takes the THEA files and imports them so Actium can use them.

# Subversion: $Id$

# Legacy status: 4 (still in progress...)

use 5.014;
use warnings;

package Actium::Cmd::TheaImport 0.001;

use Actium::Files::Thea::Import ('thea_import');

use Actium::Folders::Signup;

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium theaimport -- read THEA files from Scheduling, creating
long-format Sked files for use by the rest of the Actium system,
as well as processing stops and places files for import.
HELP

    Actium::Term::output_usage();

}

sub START {

    my $signup     = Actium::Folders::Signup->new;
    my $theafolder = $signup->subfolder('thea');
    
    thea_import ($signup, $theafolder);

} ## tidy end: sub START

1;

__END__