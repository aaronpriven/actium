#!/usr/bin/env perl -pi -0777

# legacy status: 1

# Excel for Mac outputs text files that use CR instead of LF as line 
# boundaries, and which may have extra fields tacked on to the end
# which confuse the sked reading program. This truncates those.

s/\cM/\cJ/g;
s/\s+\cJ/\cJ/g;

$_ .= "\cJ" unless substr ($_ , -1, 1) eq "\cJ";



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

