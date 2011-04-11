# buildskeds - builds schedules from headways and from HSA files

# never completed

# Subversion: $Id$

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

use 5.010;

package Actium::Buildskeds;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

use Actium::Headways;
use Actium::Signup;

sub START {

   my $signup = Actium::Signup->new();
   
   my @skeds = build_skeds($signup);
   
   # do something with @skeds

}

sub build_skeds {
    
   my $signup = shift;
    
   my @headwayskeds = process_headway_sheets($signup);
   my @skeds = process_HSAfiles($signup);
   @skeds = combine_headways_and_HSAs(\@headwayskeds, \@skeds);
   output_files($signup, @skeds);
    
}

sub process_headway_sheets {
   my $signup = shift;
   
   my $headwaysdir = $signup->subdir("headways");
   my @headwaysfiles = $headwaysdir->glob_plain_files('*.{prt,txt}');

   my @skeds = Actium::Headways::read_headways(@headwaysfiles);

   return @skeds;

}

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.001

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.


=head1 OPTIONS

A complete list of every available command-line option with which
the application can be invoked, explaining what each does and listing
any restrictions or interactions.

If the application has no options, this section may be omitted.

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
