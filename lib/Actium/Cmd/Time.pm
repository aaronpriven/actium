package Actium::Cmd::Time 0.015;

# Routines for formatting times and parsing formatted times

use Actium;
use Actium::Time;

###########################################
## COMMAND
###########################################

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium time -- convert timenums to timestrings

Usage:

actium time <time>...

Converts times (found on the command line) between a time number (an integer:
minutes after midnight, or before midnight if negative) to a time string
(hours:minutes), or vice versa.  Any integers are treated as time numbers;
anything else is treated as a time string.

Because command-line options are preceded by a hyphen, negative numbers require
special treatment.  Either precede all times with a double dash ("--"), which
indicates that following command-line arguments will not be processed as
options, or alternatively enter negative numbers with an "n" instead of a minus
sign ("n10" will be treated as -10).

HELP

}    ## tidy end: sub HELP

sub START {

    my @argv = env->argv;

    foreach my $time (@argv) {
        if ( $time =~ m/\A [-n] ? \d+ \z/sx ) {    # is it a timenum?
            $time =~ s/n/-/g;

            if ( not Actium::Time->is_in_range($time) ) {
                say "$time -> (invalid time)";
                next;
            }

            my $obj = Actium::Time::->from_num($time);

            say "$time -> AP: ", $obj->ap, " or APBX: ", $obj->apbx,
              " or T24: ", $obj->formatted();
        }
        else {
            my $obj = Actium::Time::->from_str($time);
            say "$time -> ", $obj->timenum // '(invalid time)';
        }

    }

}

1;

__END__

=encoding utf8

=head1 NAME

act-pvt.pl time - convert between time numbers and strings

=head1 VERSION

This documentation refers to version 0.015

=head1 USAGE

 act-pvt.pl time 150
  # 150 -> AP: 2:30a or APBX: 2:30a or T24: 02:30

 act-pvt.pl time 2:30
  # 2:30 -> 150

 act-pvt.pl time 2:30p 3:30p
  # 2:30p -> 870

=head1 DESCRIPTION

The C<act-pvt.pl time> command converts between Actium time numbers and times
displayed in the conventional way (e.g., "3:15p").

Actium time numbers are integers representing the number of minutes since
midnight on the start of that service day.  It is possible to have negative
integers,

=head1 ARGUMENTS

Each argument is tested to see whether it is an integer. If it is, it is
treated as a time number, and a conversion made between that integer and
conventionally displayed times.  If it is not an integer, it is treated as a
conventional time, converted into an integer, and then displayed.

  1500 -> AP: 1:00a or APBX: 1:00x or T24: 01:00
  2:30p -> 870

The command accepts multiple arguments and will convert and display them, in
turn.

Because command-line options are preceded by a hyphen, negative numbers require
special treatment.  Either precede all times with a double dash ("--"), which
indicates that following command-line arguments will not be processed as
options, or alternatively enter negative numbers with an "n" instead of a minus
sign ("n10" will be treated as -10).

See the documentation of L<Actium::Time|Actium::Time> for full details about
what sorts of arguments are accepted as time strings.

=back

=head1 OPTIONS

There are no options specific to C<act-pvt.pl time>.  See
L<act-pvt.pl|act-pvt.pl> for options common to several subcommands.

=head1 DIAGNOSTICS

If a time is foud that is not a valid time string or number, "(invalid time)"
will be displayed.

=head1 EXIT STATUS

No special exit status is made from this subcommand.
See L<act-pvt.pl|act-pvt.pl> for statuses common to several subcommands.

=head1 CONFIGURATION AND ENVIRONMENT

This subcommand has no specific configuration.  See L<act-pvt.pl|act-pvt.pl>
for configuration common to several subcommands.

=head1 DEPENDENCIES

The Actium system, including notably L<Actium::Time|Actium::Time>.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https://github.com/aaronpriven/actium/issues|https://github.com/aaronpriven/actium/issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2009-2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item *

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item *

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
