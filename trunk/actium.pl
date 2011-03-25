#!/ActivePerl/bin/perl

# actium.pl - command-line access to Actium system

# Legacy Stage 3

# This is the single executable file that allows access to various Actium
# commands. There are a couple of reasons for this. The main one is that I
# would like to rewrite the modules so that they can provide data that can
# be reused in other programs. With standalone programs it's been difficult
# to do that. Also, littering the world with lots of little executables seems
# like a bad idea.

# Subversion: $Id$

## no critic (RequireLocalizedPunctuationVars)

use strict;
use warnings;
use 5.010;

our $VERSION = "0.001"; ## no critic (ProhibitInterpolationOfLiterals)
$VERSION = eval $VERSION;

# add the current program directory to list of files to include
use FindBin qw($Bin);
use lib $Bin;
use English qw(-no_match_vars);

use Actium::Options qw(add_option init_options option);

# Ask user for a command line, if running under Eclipse.

{
    no warnings('once');
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
    }
}


# The below make sure that all errors give full stack traces.
# This should be changed to a command-line option

# arguably also the facetious name should be changed

$SIG{'__WARN__'} = \&soft_cushions;
$SIG{'__DIE__'} = \&soft_cushions;

sub soft_cushions {
    # Confess! Confess! Or we will get the comfy chair!
    require Carp;
    Carp::confess (@_);
}

### Get subcommand, and run subcommand

my %module_of = (
    headways => 'Headways',
    time => 'Time',
    hasi2tab => 'Hasi2x',
    flagspecs => 'Flagspecs',
    checkhasis => 'Hasi2x',
    drivingorder => 'DrivingOrder',
    # more to come
);

my $help       = 0;
my $subcommand = shift(@ARGV);

if ( not $subcommand or ( lc($subcommand) eq "help" and (@ARGV == 0) ) )   {
    print mainhelp() or die "Can't print help text: $OS_ERROR";
    exit 0;
}

if ( lc($subcommand) eq 'help' ) {
    $help       = 1;
    $subcommand = shift(@ARGV);
}

$subcommand = lc($subcommand);

if ( not exists $module_of{$subcommand} ) {
    print "Unrecognized subcommand $subcommand.\n\n" . mainhelp()
      or die "Can't print help text: $OS_ERROR";
    exit 1;
}

my $module = "Actium::$module_of{$subcommand}";

require( modulefile($module) ) or die $OS_ERROR;

add_option( 'help|?', 'Displays this help message.' );

init_options();

my $sub;
if ( $help or option('help') ) {
    $sub = $subcommand . '_HELP';
}
else {
    $sub = $subcommand . '_START';
}

{
no strict 'refs';
$module->$sub();
}

sub mainhelp {

    my $help = "$0 subcommands available:\n\n";
    foreach (sort keys %module_of ) {
        $help .= "$_\n";
    }
    
    return $help;

}

sub modulefile {
    my $name = shift;
    $name =~ s{::|'}{/}gs;
    return "$name.pm";
}
