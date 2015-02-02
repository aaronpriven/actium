# Actium/Cmd/LineDescrip.pm

# Produces line descriptions from the Lines database
# Also produces transit hubs sheet, so should be renamed to something else.
# Possibly combine with slists2html 

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.016;

package Actium::Cmd::LineDescrip 0.008;

use Actium::Preamble;

use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');

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
    
    my $html_descrips = $actiumdb->line_descrip_html(
        {   signup   => $signup,
        }
    );

    my $outfh = $signup->open_write('line_descriptions.html');
    say $outfh $html_descrips;
    close $outfh;
    
    my $html_hubs = $actiumdb->lines_at_transit_hubs_html;
    
    my $outhubs = $signup->open_write('transithubs.html');
    say $outhubs $html_hubs;
    close $outhubs;

    return;

} ## tidy end: sub START

1;
