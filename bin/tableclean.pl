#!/usr/bin/env perl

use 5.014;
use warnings; ### DEP ###

our $VERSION = 0.010;

use File::Slurp::Tiny('read_file'); ### DEP ###

my $file = $ARGV[0];

my $html = read_file ($file);

my $version = '20';

my $url = 
   "http://www.actransit.org/maps/schedule_results.php?version_id=$version&quick_line=";
   
$html =~ s/\s+/ /g; #no newlines

$html =~ s{.*?</head>}{}is;
$html =~ s{</?(div|span|body).*?>}{}igs;
$html =~ s/<(em|i|b)\s+.*?>/<$1>/igs;
$html =~ s/<(table|td|p|tr)\s+.*?>/<$1>/igs;
$html =~ s{<p>&nbsp;</p>\s+}{}gs;
$html =~ s{<td>\s*<p>}{<td>}gs;
$html =~ s{</p>\s*</td>}{</td>}gs;
#$html =~ s{</?(p|div|span|body).*?>}{}igs;

my $behind = qr{
     (?<![A-Za-z0-9:])
     (?<!January\s)
     (?<!February\s)
     (?<!March\s)
     (?<!April\s)
     (?<!May\s)
     (?<!June\s)
     (?<!July\s)
     (?<!August\s)
     (?<!September\s)
     (?<!October\s)
     (?<!November\s)
     (?<!December\s)
}x;  # not a letter or digit or colon, or month

my $ahead = qr{ (?! (?: , \s+ 201\d | [A-Za-z0-9] | : | \s+Loop) ) }x;
# not either ", 201x", where x is a digit and space is any space character, or
# a letter or digit, or a colon, or "Loop" (for A Loop / B Loop )

$html =~ s{$behind
          (
             \d{1,2}[A-Z]? |
             2\d\d         |
             3\d\d         |
             60[1-9]       |
             6[1-9]\d      |
             A[ABD-Z]\d?   |  # skip "AC"
             [B-Z][A-Z]\d? |
             [B-Z]         
          ) 
          $ahead
          }
         
         
          {<a href="$url$1">$1</a>}gx;
          
$html =~ s/<table.*?>/<table border="1" cellspacing="0" cellpadding="6">/igs;

$html =~ s#(</(?:table|td|p|tr)>\s+)#$1\n#igs;

print $html;



=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.003

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

Copyright 2017

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

