package Octium::Cmd::HeadwayTimes 0.011;

# This is intended to accept a tab-delimited text file and then display the
# minutes between times in the list.

use Octium;
use Octium::Time;

###########################################
## COMMAND
###########################################

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium.pl headwaytimes filename.txt -- show the headway between times on the 
schedule

HELP

}

sub START {

    my $class = shift;
    my $env   = shift;
    my @argv  = $env->argv;

  FILE:
    foreach my $filename (@argv) {
        open my $in, '<', $filename;

        say "---\n$filename\n---" unless @argv == 1;

        my $prev;
      LINE:
        while ( my $line = readline($in) ) {
            chomp($line);

            if ( not defined $prev ) {
                $prev = $line;
                say $line;
                next LINE;
            }

            my @prevtimes = timenums( split( "\t", $prev ) );
            my @times     = timenums( split( "\t", $line ) );

            my $numfields = u::min( $#prevtimes, $#times );

            my @headways;

          FIELD:
            for my $i ( 0 .. $numfields ) {
                my $prevtime = $prevtimes[$i];
                my $time     = $times[$i];

                if ( not defined $prevtime or not defined $time ) {
                    push @headways, undef;
                    next FIELD;
                }

                my $headway = ( $time - $prevtime );

                $headway = $EMPTY if $headway == 0;
                push @headways, $headway;

            }

            if ( u::any {defined} @headways ) {
                say u::jointab(@headways);
            }

            say $line;

            $prev = $line;

        } ## tidy end: LINE: while ( my $line = readline...)

    } ## tidy end: FILE: foreach my $filename (@argv)
} ## tidy end: sub START

func timenums (@times) {
    my @timenums = map { Octium::Time->from_str($_)->timenum } @times;
    return @timenums;
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

