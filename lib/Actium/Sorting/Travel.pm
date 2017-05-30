package Actium::Sorting::Travel 0.012;

# Sorting routines by travel line)

use Actium;
use Actium::Sorting::Line ('byline');

use Sub::Exporter -setup => { exports => [qw(travelsort)] };
# Sub::Exporter ### DEP ###

func travelsort ( 
     :@stops! is ref_alias , 
     :%allstops_of_linedir! is ref_alias,
     :@promote is ref_alias , 
     Bool :$demote600s = 0 , 
     ) {

 #    my %params = u::validate(
 #        @_,
 #        {   stops            => { type => $PV_TYPE{ARRAYREF} },
 #            stops_of_linedir => { type => $PV_TYPE{HASHREF} },
 #            promote          => { type => $PV_TYPE{ARRAYREF}, optional => 1 },
 #            demote600s       => { type => $PV_TYPE{BOOLEAN}, default => 0 },
 #        }
 #    );

    my %stop_is_used;
    $stop_is_used{$_} = 1 foreach @stops;

    # keys: travel lines. values: array ref of stops

    my %is_priority_line;
    if (@promote) {
        $is_priority_line{$_} = 1 foreach @promote;
    }

    # Make new %used_stops_of_linedir with only stops
    # on the first list

    my %used_stops_of_linedir;
    my %is_priority_linedir;

    while ( my ( $linedir, $stops_r ) = each %allstops_of_linedir ) {

        my ($line) = split /-/, $linedir;

        $is_priority_linedir{$linedir} = 1
          if $is_priority_line{$line};
        my @usedstops;
        foreach my $stop ( u::uniq @{$stops_r} ) {
            push @usedstops, $stop if $stop_is_used{$stop};
        }
        $used_stops_of_linedir{$linedir} = \@usedstops;
    }

    my @results;

    while ( scalar keys %used_stops_of_linedir ) {

        my $max_linedir
          = _get_max_linedir( \%used_stops_of_linedir, \%is_priority_linedir,
            $demote600s );

        # $max_linedir is now the line/dir combination with the most stops

        my @stops = @{ $used_stops_of_linedir{$max_linedir} };

        # and @stops is the current list of stops

        last unless @stops;

        push @results, [ $max_linedir, @stops ];

        # Save the one with the most stops

        delete $used_stops_of_linedir{$max_linedir};

        # delete all stops in the remaining lines
        # that have been seen already

        my %seen_stop;
        $seen_stop{$_} = 1 foreach @stops;

        while ( my ( $linedir, $stops_r ) = each %used_stops_of_linedir ) {
            my @newstops;
            foreach my $stop ( @{$stops_r} ) {
                push @newstops, $stop unless $seen_stop{$stop};
            }
            if (@newstops) {
                $used_stops_of_linedir{$linedir} = \@newstops;
            }
            else {
                delete $used_stops_of_linedir{$linedir};
            }
        }

    } ## tidy end: while ( scalar keys %used_stops_of_linedir)
    return @results;
} ## tidy end: sub FUNC0

sub _get_max_linedir {

    my $stops_of_linedir_r    = shift;
    my $is_priority_linedir_r = shift;
    my $demote600s            = shift;

    my $max_linedir;

    if ($demote600s) {

        $max_linedir = (
            sort {
                ( ( $is_priority_linedir_r->{$b} // 0 )
                    <=> ( $is_priority_linedir_r->{$a} // 0 ) )

                  or

                  ( $a =~ /^6\d\d/ <=> $b =~ /^6\d\d/ )
                  or ( @{ $stops_of_linedir_r->{$b} }
                    <=> @{ $stops_of_linedir_r->{$a} } )
                  or byline( $a, $b )
            } keys %{$stops_of_linedir_r}
        )[0];

    }
    else {

        $max_linedir = (
            sort {
                ( ( $is_priority_linedir_r->{$b} // 0 )
                    <=> ( $is_priority_linedir_r->{$a} // 0 ) )

                  or

                  #( $a =~ /^6\d\d/ <=> $b =~ /^6\d\d/ ) or
                  ( @{ $stops_of_linedir_r->{$b} }
                    <=> @{ $stops_of_linedir_r->{$a} } )
                  or byline( $a, $b )
            } keys %{$stops_of_linedir_r}
        )[0];

    }

    return $max_linedir;
} ## tidy end: sub _get_max_linedir

1;

__END__

=head1 NAME

Actium::Sorting::Travel - travel sort routines for Actium system

=head1 VERSION

This documentation refers to version 0.001.

=head1 SYNOPSIS

 use Actium::Sorting::Travel qw(travelsort);
 (more to come)

=head1 DESCRIPTION

Actium::Sorting::Travel is a module that provides special sorting
routine for the Actium system. It sorts by travel line. The purpose is
to provide lists of stops ordered in a way that makes it easier for a
maintenance worker or surveyor to travel down a bus line and visit all
the stops, but without duplication.

The result is a list of routings, with the affected stops, with all
duplicates removed. It is designed so that the longest lists possible
are given.

=head1 SUBROUTINE

Nothing is exported by default, but travelsort() may be requested by 
the calling module.

=head2 travelsort
The travelsort routine provides the sorted list of stops.

It takes two mandatory and two optional named arguments.

=over

=item stops

The mandatory stops argument is a reference to an array of the stops
that are to be sorted.

 [qw<stop_1 stop_2 stop_3>] ...
 
=item stops_of_linedir

The stops_of_linedir argument must be a hash ref, where the  keys are
the routings and and the  values are the stops that it uses, in order.

 $ref->{1-Northbound}->[qw<stop_2 stop_1>]
 $ref->{5-Northbound}->[qw<stop_1>]
 $ref->{6-Counterclockwise}->[qw<stop_2>]
 ...
 
Stops in stops_of_linedir list but not in stops are ignored, allowing 
users to pass (for example) the full set of stops-by-line to the
routine.

=item promote

This optional parameter, if present, must be a reference to an array of
lines.  These lines will be given precedence when choosing which line
to use for a particular stop, even if another line has more stops.

=item demote600s

This optional parameter is a boolean. If it is true, all other lines
will be given precedence over lines 600-699, even if a 600-series line
has more stops.

=back
 
The result is a list of arrayrefs. The first element of each arrayref
is the routing, and the following elements are the stops.

 [qw(5-Northbound stop_3 stop_2 stop_7)]
 [qw(1-Northbound stop_2 stop_1 stop_5)]
 ...
 
=head1 DEPENDENCIES

=over

=item * 

perl 5.12

=item *

Sub::Exporter

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011-2015

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

