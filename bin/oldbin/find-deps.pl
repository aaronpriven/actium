#!/usr/bin/env perl

# find-deps.pl
# Goes through the source code and finds everything marked with a dependency
# tag on the same line.  Omits Actium dependencies since the purpose of it
# is to identify which modules need to be installed for Actium to work.

# This handles most of the typical "use" and "require" statements such that
# just adding the tag on the use or require line will work. Otherwise
# they can be added on comment lines with the tag.

use 5.010;
use warnings;

our $VERSION = 0.010;

#use List::MoreUtils('uniq');
# I don't want to have a dependency in the dependency-finding program!

my $tag = '### ' . 'DEP' . ' ###';
# writing it that way avoids finding the literal tag in this file

my $path;

if ( -d 'bin' and -d 'lib' ) {
    $path = './bin ./lib';
}
else {
    $path = '.';
}

my @deps = `grep '$tag' -hIR $path`;

foreach (@deps) {

    s/$tag//;
    s/;//g;
    s/^\s+//;
    s/\s+$//;
    s/^#+//;
    s/^use //;
    s/^require //;
    s/(?:qw)?\(.*\)//g;    # deliberately greedy
    s/qw<.*\>//g;
    s/'.*'//g;
    s/^\s+//;
    s/\s+$//;

}

@deps = grep { !/^Actium::/ } @deps;

push @deps, qw(
  PadWalker
  Perl::Critic
  Perl::Critic::Moose
  Perl::Critic::StricterSubs
  Perl::Critic::Tics
  Perl::Tidy
  App::Ack
  );    # general dependencies of the system, not for any single module

@deps = uniq(@deps);
@deps = sort @deps;

say join( "\n", @deps );

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

__END__



=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.003

=head1 USAGE

 # brief working invocation example(s) using the most comman usage(s)

=head1 REQUIRED ARGUMENTS

A list of every argument that must appear on the command line when the
application is invoked, explaining what each one does, any restrictions
on where each one may appear (i.e., flags that must appear before or
after filenames), and how the various arguments and options may
interact (e.g., mutual exclusions, required combinations, etc.)

If all of the application's arguments are optional, this section may be
omitted entirely.

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

