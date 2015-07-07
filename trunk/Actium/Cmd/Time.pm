# Actium/Cmd/Time.pm
# Routines for formatting times and parsing formatted times

# Subversion: $Id: Time.pm 465 2014-09-25 22:25:14Z aaronpriven $

# legacy status 3

use warnings;
use strict;

package Actium::Cmd::Time 0.006;

use 5.014;

use Actium::Time qw(timestr_sub);

###########################################
## COMMAND
###########################################

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium time -- convert timenums to timestrings

Usage:

actium time <time>...

Converts times (found on the command line) between a time number 
(an integer: minutes after midnight, or before midnight if negative) 
to a time string (hours:minutes), or vice versa.  Any integers are
treated as time numbers; anything else is treated as a time string.

Because command-line options are preceded by a hyphen, 
negative numbers require special treatment. 
Either precede all times with a double dash ("--"),
which indicates that following command-line arguments will not be processed
as options, or alternatively enter negative numbers with an "n" instead
of a minus sign ("n10" will be treated as -10).

HELP

}

sub START {

    my $class = shift;
my %params = @_;

	my @argv = @{$params{argv}};
  
    my $timestr_sub = timestr_sub( { XB    => 1 } );
    my $timestr_24  = timestr_sub( { HOURS => 24 } );
    foreach my $time (@argv) {
        if ( $time =~ m/\A [-n] ? \d+ \z/sx ) {
            $time =~ s/n/-/g;
            say "$time -> ", $timestr_sub->($time), " or ",
              $timestr_24->($time);
        }
        else {
            say "$time -> ", timenum($time);
        }

    }

}

1;

__END__
# TODO: Add POD
