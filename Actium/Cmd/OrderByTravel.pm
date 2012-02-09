# /Actium/Cmd/OrderByTravel.pm

# Takes a list of stops and order it so that people can drive down a
# particular bus route and hit as many stops as possible.

# Subversion: $Id$

# legacy stage 4

use 5.012;
use warnings;

package Actium::Cmd::OrderByTravel 0.001;

use Carp;
use Storable();
use English ('-no_match_vars');

use Actium::Sorting::Travel(qw<travelsort>);
use Actium::Constants;
use Actium::Term ('output_usage');
use Actium::Folders::Signup;

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium orderbytravel -- create list of stops ordered by travel route

Usage:

actium orderbytravel <file>

Takes the file specified as input. Takes everything before the first tab
as the Stop ID.  Reads the line.storable file from the specified signup and
produces a list of the input stops ordered by travel along the bus stops.
HELP

    output_usage();

    return;

}

sub START {

    my $inputfilespec = shift @ARGV;
    die "No input file given" unless $inputfilespec;
    
    open my $input_h, '<', $inputfilespec
      or die "Can't open file $inputfilespec: $OS_ERROR";

    my (%description_of);
    while (<$input_h>) {
        chomp;
        my ( $stop, $description ) = split( /\t/, $_, 2 );
        next if ( $stop ~~ [qw<StopID PhoneID stop_id_1>]);    # header line
        $description_of{$stop} = $description;
    }

    my $slistsdir = Actium::Folders::Signup->new('slists');

    # retrieve data
    my $stops_of_r = $slistsdir->retrieve('line.storable')
      or die "Can't open line.storable file: $OS_ERROR";

    my @sorted = travelsort( [ keys %description_of ], $stops_of_r );

    binmode STDOUT, ':utf8';
    while ( my $ref = shift @sorted ) {
    my ($linedir, @stops) = @{$ref};
        my $numstops = scalar @stops;
        foreach my $i ( 1 .. $numstops ) {
            my $stop = $stops[$i - 1];
            say "$linedir\t$i of $numstops\t$stop\t$description_of{$stop}";
        }
    }

} ## tidy end: sub START

1;

__END__


=head1 NAME

orderbytravel - produce ordered list of stops by travel along bus routes

=head1 VERSION

This documentation refers to version 0.001

=head1 USAGE

From a shell:

 actium.pl orderbytravel /Some/Directory/Inputfile.txt

=head1 REQUIRED ARGUMENTS

=over

=item I<file>

The user must give the full pathname to an input file. The input file
is treated as tab-delimited text, with the first field being the stop ID.

If the first field of a line is 'PhoneID', 'StopID', or 'stop_id_1', 
the line is skipped (since it probably contains column names).

=back

=head1 OPTIONS

This program specifies no options itself, but several modules this subprogram 
uses specify options. See:

=over

=item L<OPTIONS in Actium::Folders::Signup|Actium::Folders::Signup/OPTIONS>

=item L<OPTIONS in Actium::Sorting::Travel|Actium::Sorting::Travel/OPTIONS>

=item L<OPTIONS in Actium::Term|Actium::Term/OPTIONS>

=back

A complete list of options can be found by running 
"actium.pl help orderbytravel"

=head1 DESCRIPTION

The purpose of this program is to produce lists of stops ordered by travel 
route. This makes it easier for a maintenance
worker or surveyor to travel down a bus route and visit all the stops,
but without duplicates.

The user specifies an input file which contains stops. The program compares
this to the 'line.storable' file, which contains a list of bus lines and
directions and which stops, in order, are used by those lines.

The result is a list of routings, with the affected stops, with all duplicates
removed. It is designed so that the longest lists possible are given.

=head1 DIAGNOSTICS

=over

=item No input file given

No file specification was given on the command line.

=item Can't open file $inputfilespec: $OS_ERROR

An error was found trying to open the file given on the command line.
The file may not have been found, or there may be some other error.

=item Can't open line.storable file: $OS_ERROR

An error was found trying to read the file line.storable. It may not be 
present in the appropriate place (the "slists" folder under the specified 
signup) or there may be some other error.

=back

=head1 DEPENDENCIES

=over

=item Actium::Constants

=item Actium::Term 

=item Actium::Options 

=item Actium::Folders::Signup

=item Actium::Sorting::Travel

=back

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
