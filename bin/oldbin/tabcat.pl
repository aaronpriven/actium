#!/usr/bin/env perl

use 5.016;
use warnings;

our $VERSION = 0.002;

binmode STDERR, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN,  ':encoding(UTF-8)';

use utf8;
use autodie; ### DEP ###
use open ':encoding(UTF-8)'; ### DEP ###
use Encode; ### DEP ###
my @args = map { decode( 'UTF-8', $_ ) } @ARGV;

#@args = qw(StopID /Users/apriven/actium/db/sp13/compare/OX-Transbay
#  /Users/apriven/actium/db/sp13/compare/comparestops-action.txt);

use List::Util('max'); ### DEP ###

my $fieldsep = "\t";
my $nul      = q{};

my $key_field    = shift @args;
my $fc_key_field = fc($key_field);

my %lines_of;
my @tabcounts;    # represents separators, not fields

foreach my $file_idx ( 0 .. $#args ) {
    my $file = $args[$file_idx];

    open my $fh, "<:eol(LF)", $file;

    my $headerline = readline($fh);
    chomp $headerline;
    $headerline =~ s/$fieldsep*\z//;
    my @headers = splittab($headerline);

    my $key_idx;
    for my $head_idx ( 0 .. $#headers ) {
        my $this_head = $headers[$head_idx];
        if ( fc($this_head) eq $fc_key_field ) {
            $key_idx = $head_idx;
            last;
        }
    }
    die "Can't find key field $key_field in file $file"
      if not defined $key_idx;

    splice( @headers, $key_idx, 1 );    # delete key header from line

    $headerline = jointab(@headers);
    $lines_of{$nul}[$file_idx] = $headerline;

    my $tabcount = counttab($headerline);

    while ( my $line = readline($fh) ) {
        chomp $line;
        $line =~ s/$fieldsep*\z//;

        my @fields   = splittab($line);
        my $keyvalue = $fields[$key_idx];
        splice( @fields, $key_idx, 1 );    # delete key from line
        $lines_of{$keyvalue}[$file_idx] = jointab(@fields);

        $tabcount = max( $tabcount, (counttab($line) -1 ));

    }

    $tabcounts[$file_idx] = $tabcount;

    close $fh;

} ## tidy end: foreach my $file_idx ( 0 .....)

foreach my $key_value ( sort keys %lines_of ) {

    my @lines = @{ $lines_of{$key_value} };

    for my $file_idx ( 0 .. $#lines ) {
        if ( not defined $lines[$file_idx] ) {
            $lines[$file_idx] = $fieldsep x $tabcounts[$file_idx];
        }
        else {
            my $tabcount = counttab( $lines[$file_idx] );
            if ( $tabcount < $tabcounts[$file_idx] ) {
                my $moretabs = $tabcounts[$file_idx] - $tabcount;
                $lines[$file_idx] .= $fieldsep x $moretabs;
            }
        }
    }

    $key_value = $key_field if $key_value eq $nul;
    say jointab( $key_value, @lines );
} ## tidy end: foreach my $key_value ( sort...)

sub splittab {
    my $line = shift;
    return split( /$fieldsep/, $line );
}

sub counttab {
    my $line = shift;
    my $count = () = $line =~ /$fieldsep/g;
    return $count

}

sub jointab {
    return join( $fieldsep, @_ );
}



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

