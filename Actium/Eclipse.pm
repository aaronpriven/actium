# Actium/Eclipse.pm

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

# Subversion: $Id$

# Legacy stage 4.

package Actium::Eclipse;

use 5.010;
use warnings;
use strict;

no warnings('redefine');
# without which, Eclipse complains because it sees this module twice when
# debugging this module

our $is_under_eclipse = 1;

$ENV{LINES} = 25;
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

} ## <perltidy> end sub get_command_line

1;
