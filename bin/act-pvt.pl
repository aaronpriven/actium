#!/usr/bin/env perl

# act-pvt.pl - command-line access to Actium system

use FindBin qw($Bin);    ### DEP ###
use lib ("$Bin/../lib"); ### DEP ###

use Actium;
use Actium::Env::CLI;

our $VERSION = 0.015;

Actium::Env::CLI::->new(
    commandpath => $0,
    system_name => 'actium',
    subcommands => {
        #        nonmin       => 'NonMinSuppCalendar',
        #        ems          => 'Ems',
        #        frequency    => 'Frequency',
        #        headwaytimes => 'HeadwayTimes',
        #        indd_encode  => 'InDesignEncode',
        #        pr_add_stop  => 'PRAddStop',
        #        scratch      => 'Scratch',
        #        schooltrips  => 'SchoolTrips',
        #        tempsigns    => 'TempSigns',
        #        theaimport   => 'TheaImport',
        time => 'Time',
        #        xhea2hasi    => 'Xhea2Hasi',
    },
);

__END__

=encoding utf8

=head1 NAME

act-pvt.pl - Private (or at least, not particularly public) commands in
the Actium system

=head1 VERSION

This documentation refers to act-pvt.pl version 0.015

=head1 USAGE

 act-pvt.pl subcommand ...

=head1 DESCRIPTION

The act-pvt.pl command gives command-line access to various subcommands
that are not considered public enough to make available to all Actium
users. Generally they are commands used for development or informal
testing.

=head1 AVAILABLE SUBCOMMANDS

See the documentation in each subcommand's module file for more
information.

=head2 help

This provides a list of subcommands available using act-pvt.pl.

=head2 manual

This displays this manual page, or the manual page for the supplied
subcommand.

=head2 time

See L<Actium::Cmd::Time|Actium::Cmd::Time>.

=head1 OPTIONS, CONFIGURATION AND ENVIRONMENT

All commands in act-pvt.pl take the default option package. See
L<Actium::Env::CLI|Actium::Env::CLI> for more information about the
option packages. See information in each subcommand's module for
specific information about that subcommand.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017-2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

