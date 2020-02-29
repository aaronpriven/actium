package Octium::Cmd::Stops2KML 0.011;

# Creates KML output of stops

use Actium;
use Octium;
use Octium::StopReports('stops2kml');
use File::Slurper('write_text');    ### DEP ###

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium stops2kml -- create list of stops in KML for Google Earth

Usage:

actium stops2kml <outputfile>

Takes all stops in the database and produces a KML file 
with the bus stop information.
HELP

    return;

}

sub OPTIONS {
    return (
        'actiumdb',
        {   spec           => 'workzones',
            description    => 'Create KML for work zones instead of by stop',
            fallback       => '0',
            envvar         => 'STOPS2KML_WORKZONES',
            config_section => 'Stops2KML',
            config_key     => 'WorkZones',
        },
        {   spec           => 'vicinity',
            description    => 'Create KML for lines around a vicinity',
            fallback       => '0',
            envvar         => 'STOPS2KML_VICINITY',
            config_section => 'Stops2KML',
            config_key     => 'Vicinity',
        },
    );
}

sub START {
    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;
    my @argv     = $env->argv;

    my $outputfile = shift @argv;

    unless ($outputfile) {
        HELP();
        return;
    }

    my $use_option;
    my $workzones = $env->option('workzones');
    $use_option = 'w' if $workzones;
    my $vicinity = $env->option('vicinity');
    $use_option = 'v' if $vicinity;

    my $kml_text = stops2kml( $actiumdb, $use_option );

    write_text( $outputfile, $kml_text );

    return;

}

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

