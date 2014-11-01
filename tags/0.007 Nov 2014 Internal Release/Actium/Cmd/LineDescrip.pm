# Actium/Cmd/LineDescrip.pm

# Produces line descriptions from the Lines database

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.016;

package Actium::Cmd::LineDescrip 0.006;

use Actium::Preamble;

use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::LineInfo ('line_descrip_html');

use Actium::Options(qw<add_option option>);

add_option( 'version=s', 'Current version of line maps. Required', );

use Actium::Term ('output_usage');

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
linedescrip. Creates line description file.
HELP

    Actium::Term::output_usage();

    return;
}

sub START {
    
    my $class = shift;
    my %params = @_;
    
    my $config_obj = $params{config};

    my $signup = Actium::O::Folders::Signup->new();
    my $actiumdb = actiumdb($config_obj);
    
    my $version = option('version');

    unless ( $version or $version eq '0' ) {
        die "No version specified.\n"
          . 'You must provide a version number for inclusion in map links\n';
    }

    my $html_descrips = line_descrip_html(
        {   signup   => $signup,
            database => $actiumdb,
            version  => $version,
        }
    );

    my $outfh = $signup->open_write('line_descriptions.html');

    say $outfh $html_descrips;

    close $outfh;

    return;

} ## tidy end: sub START

1;
