package Actium::Eclipse 0.012;

# Originally, this did nothing of any use. However, requiring that this file
# be present was a cute way of figuring out whether the requiring
# program is running under Eclipse or not.

# Add -MActium::Eclipse to Eclipse's default perl comamnd line.
# Then you can do:

#  if ($Actium::Eclipse::is_under_eclipse) {
#     do_something();
#  }
#  else {
#     do_something_else;
#  }

# Ta da.

# Originally, I did that so that actium.pl could ask for a command line if
# none was provided.  I later moved that routine to this module. So
# Actium::Eclipse::get_command_line() gets the command line (using Applescript...
# slowly) from Eclipse.

use 5.010;
use warnings;    ### DEP ###
use strict;      ### DEP ###

no warnings('redefine');
# without which, Eclipse complains because it sees this module twice when
# debugging this module

our $is_under_eclipse = 1;

$ENV{LINES}   = 25;
$ENV{COLUMNS} = 80;
# at least sometimes, Term::Readkey complains if it doesn't have anything
# to set the window size by

sub get_command_line {

    my $history;

    if ( -f '/tmp/UnderEclipse.history' ) {
        open my $histfile, '<', '/tmp/UnderEclipse.history';
        $history = readline($histfile);
        chomp $history;
        close $histfile;
    }
    else {
        $history = "";
    }

    my $script
      = qq[osascript -e 'tell application "System Events" to get text returned of ( display dialog "$0\rCommand line:" default answer "$history" buttons "OK" default button "OK" with title "Command line entry" ) '];

    my $newargs = `$script`;
    chomp $newargs;

    if ( $newargs ne $history ) {
        open my $histout, '>', '/tmp/UnderEclipse.history';
        say $histout $newargs;
        close $histout;
    }

    return split( ' ', $newargs );

}    ## <perltidy> end sub get_command_line

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

