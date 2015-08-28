# Actium/Cmd/Time.pm
# Routines for formatting times and parsing formatted times

# legacy status 3

use warnings;
use strict;

package Actium::Cmd::Time 0.010;

use 5.014;

use Actium::O::Time;

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

} ## tidy end: sub HELP

sub START {

    my $class = shift;
    my $env   = shift;
    my @argv  = $env->argv;

    foreach my $time (@argv) {
        if ( $time =~ m/\A [-n] ? \d+ \z/sx ) {    # is it a timenum?
            $time =~ s/n/-/g;

            my $obj = Actium::O::Time::->from_num($time);

            say "$time -> AP: ", $obj->ap, " or APBX: ", $obj->apbx,
              " or T24: ", $obj->t24;
        }
        else {
            my $obj = Actium::O::Time::->from_str($time);
            say "$time -> ", $obj->timenum;
        }

    }

} ## tidy end: sub START

1;

__END__
# TODO: Add POD
