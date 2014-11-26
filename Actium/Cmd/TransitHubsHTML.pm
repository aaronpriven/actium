# Actium/Cmd/TransitHubsHTML.pm

# Produces HTML from TransitHubs file

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.016;

package Actium::Cmd::LineDescrip 0.006;

use Actium::Preamble;

use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');

use Actium::Term ('output_usage');

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
transithubshtml. Creates transithubs.html file from transithubs.txt
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
    
    my $transit_hubs_html = transithubs_html($signup);
    
    my $outfh = $signup->open_write('transithubs.html');

    say $outfh $transit_hubs_html;

    close $outfh;

    return;

} ## tidy end: sub START

1;
