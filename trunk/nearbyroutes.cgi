#!/ActivePerl/bin/perl

# nearbyroutes.cgi

## no critic (RequireLocalizedPunctuationVars)

use 5.012;
use warnings;

our $VERSION = 0.002;

BEGIN {
 
print "Content-type: text/plain\r\n\r\n";
 
print "Started\r\n";

}

# add the current program directory to list of files to include
use FindBin qw($Bin);
use lib $Bin;
use English qw(-no_match_vars);

use Actium::Options qw(init_options );

use Actium::O::Folders::Signup;

use Actium::Cmd::NearbyRoutes;
# TODO: move NearbyRoutes to a non-Cmd module

my $dbname = 'geocoder.db';

my $threshold = 5280 / 4;    # 1/3 mile

init_options();

use CGI qw(:standard);

my $q = CGI->new();

my $address = param(address);

my $signup     = Actium::O::Folders::Signup->new();
my $dbfilespec = $signup->make_filespec($dbname);

Geo::Coder::US->set_db($dbfilespec);

my $stops_r = Actium::Cmd::NearbyRoutes::load_stops($signup);

my @res = Geo::Coder::US->geocode($address);

foreach my $this_res (@res) {
    my $lat  = $this_res->{'lat'};
    my $long = $this_res->{'long'};

    print "$_\t";

    my $nearby = find_nearby( $stops_r, $lat, $long );

    $nearby = "No stop found" unless defined $nearby;

    say $nearby;

}
