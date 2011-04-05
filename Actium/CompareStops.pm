# /Actium/CompareStops.pm

# Takes the old and new stops and produces comparison lists. 

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::CompareStops 0.001;

# add the current program directory to list of files to include

use Carp;
use Storable();
use English ('-no_match_vars');

use Actium::Sorting(qw<travelsort>);
use Actium::Constants;
use Actium::Term ('output_usage');
use Actium::Options (qw<add_option option>);
use Actium::Signup;

add_option ('oldsignup' , 'Previous signup to compare this signup to');

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium comparestops -- compare stops from old to new signups

Usage:

actium comparestops -oldsignup f10 -signup sp11

Compares stops in the specified signups,
producing lists of compared stops in /compare in the new signup.

/compare/comparestops.txt is a simple list of stops.

/compare/comparestopstravel.txt is the same list, ordered by travel routes

HELP

    output_usage();
    return;

}

sub START {
 

} ## tidy end: sub START

1;

__END__

