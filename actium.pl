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

use 5.012;
use warnings;

our $VERSION = 0.005;

# add the current program directory to list of files to include
use FindBin qw($Bin);
use lib $Bin;
use English qw(-no_match_vars);
use Scalar::Util('reftype');

use Actium::Options qw(add_option init_options option);

use Actium::O::Files::Ini;
my $config = Actium::O::Files::Ini::->new('.actium.ini');

# Ask user for a command line, if running under Eclipse.

{
    no warnings('once');
    ## no critic (RequireExplicitInclusion, RequireLocalizedPunctuationVars)
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
        ## use critic
    }
}

# Someday, if I want to allow these to run as CGI, rather than
# creating a separate actium.cgi I can find out whether it's in that
# environment by checking whether $ENV{GATEWAY_INTERFACE} exists --
# if so, we're under CGI. Cool.

### Get subcommand, and run subcommand

my %module_of = (
    slists2html     => 'Slists2HTML',
    theaimport      => 'TheaImport',
    makestoplists   => 'MakeStopLists',
    time            => 'Time',
    sqlite2tab      => 'SQLite2tab',
    flagspecs       => 'Flagspecs',
    timetables      => 'Timetables',
    tabula          => \'timetables',
    tabulae         => \'timetables',
    orderbytravel   => 'OrderByTravel',
    patterns        => 'Patterns',
    prepareflags => 'PrepareFlags',
    adddescriptionf => 'AddDescriptionF',
    k2id            => 'MakePoints',
    nearbyroutes    => 'NearbyRoutes',
    mr_import       => 'MRImport',
    mr_copy         => 'MRCopy',
    htmltables      => 'HTMLTables',
    linedescrip     => 'LineDescrip',
    decalcount => 'DecalCount',
    xml2thea        => 'Xml2Thea',
    xheaimport => 'XheaImport',
                                            # more to come
);

# a reference is an alias, so tabulae => \'tabula' means if you type
# "tabulae" it will treat it as though you typed "tabula"
my $help       = 0;
my $subcommand = shift(@ARGV);

if ( not $subcommand or ( lc($subcommand) eq 'help' and ( @ARGV == 0 ) ) ) {
    print mainhelp() or die "Can't print help text: $OS_ERROR";
    exit 0;
}

if ( lc($subcommand) eq 'help' ) {
    $help       = 1;
    $subcommand = shift(@ARGV);
}

$subcommand = lc($subcommand);

while ( exists( $module_of{$subcommand} )
    and defined( reftype( $module_of{$subcommand} ) ) )
{
    $subcommand = ${ $module_of{$subcommand} };
}

if ( not exists $module_of{$subcommand} ) {
    print "Unrecognized subcommand $subcommand.\n\n" . mainhelp()
      or die "Can't print help text: $OS_ERROR";
    exit 1;
}

my $module = "Actium::Cmd::$module_of{$subcommand}";

require( modulefile($module) ) or die $OS_ERROR;

add_option( 'help|?', 'Displays this help message.' );
add_option( '_stacktrace',
        'Provides lots of debugging information if there is an error. '
      . 'Best ignored.' );

init_options();

if ( option('_stacktrace') ) {
## no critic (RequireLocalizedPunctuationVars)
    $SIG{'__WARN__'} = \&stacktrace;
    $SIG{'__DIE__'}  = \&stacktrace;
}

if ( $help or option('help') ) {
    $module->HELP(@ARGV);
}
else {
    $module->START(argv => [ @ARGV ], config => $config);
}

sub mainhelp {

    my $helptext = "$PROGRAM_NAME subcommands available:\n\n";
    foreach my $subcommand ( sort keys %module_of ) {
        next if defined( reftype( $module_of{$subcommand} ) );
        $helptext .= "$subcommand\n";
    }

    return $helptext;

}

sub modulefile {
    my $name = shift;
    $name =~ s{::|'}{/}gs;
    return "$name.pm";
}

sub stacktrace {
    require Carp;
    Carp::confess(@_);
}

__END__

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.001

=head1 USAGE

 # brief working invocation example(s) using the most comman usage(s)

=head1 REQUIRED ARGUMENTS

A list of every argument that must appear on the command line when
the application is invoked, explaining what each one does, any
restrictions on where each one may appear (i.e., flags that must
appear before or after filenames), and how the various arguments
and options may interact (e.g., mutual exclusions, required
combinations, etc.)

If all of the application's arguments are optional, this section
may be omitted entirely.

=over

=item B<argument()>
Description of argument.

=back

=head1 OPTIONS

A complete list of every available option with which the application
can be invoked, explaining wha each does and listing any restrictions
or interactions.

If the application has no options, this section may be omitted.

=head1 DESCRIPTION

A full description of the program and its features.

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.


