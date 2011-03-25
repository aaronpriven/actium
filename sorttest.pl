#!/ActivePerl/bin/perl

# Test the Actium::Sorting module

# legacy status: 3

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

# Subversion: $Id$

use 5.010;

use warnings;
use strict;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

# add the current program directory to list of files to include
use FindBin qw($Bin);
use lib $Bin;

use Actium::Sorting (qw(byline));
use Actium::Options (qw(init_options));

init_options();

my @lines = qw (
OX1
OX
OX2
OX10
A1A
A1
A
1
38
1000
9000
9000A
38X3273
AZZZ3827Q
38X
38XA
100
LB
LA2
LB2
72
9
72M
382A
1AX
1A
1B
);

say (join("\n" , sort byline @lines));

__END__

=head1 NAME

sorttest.pl - Test of "bylines" routine in Actium::Sorting

=head1 VERSION

This documentation refers to <name> version 0.001

=head1 USAGE

 perl sorttest.pl

=head1 DESCRIPTION

This program is a simple test of the "bylines" routine in Actium::Sorting. 
It has a long list of line names which are sorted, and then the sorted
list is sent to standard output.

=head1 DEPENDENCIES

=item *

perl 5.010

item *

Actium::Sorting

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
