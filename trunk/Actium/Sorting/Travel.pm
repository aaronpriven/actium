# Actium/Sorting/Travel.pm
# Sorting routines by travel line)

# Subversion: $Id$

# legacy status 4

use 5.012;
use warnings;

package Actium::Sorting::Travel 0.006;

use Storable;
use Actium::Options (qw(add_option option));

use Actium::Sorting::Line ('byline');

use Actium::Constants;

use Sub::Exporter -setup => { exports => [qw(travelsort)] };

add_option( 'promote=s',
        'When sorting by travel, give a list of lines to be sorted first, '
      . 'separated by commas. For example, -promote 26,A,58' );

add_option( 'demote600s!',
    'When sorting by travel, lower the priority of 600-series lines. ' );

###################################
### SORTING BY TRAVEL ROUTES
###################################

sub travelsort {

    my %stop_is_used;
    $stop_is_used{$_} = 1 foreach @{ +shift };

    my %allstops_of_linedir = %{ +shift };

    # keys: travel lines. values: array ref of stops

    my %is_priority_line;
    if ( option('promote') ) {
        my @prioritylines = split /,/, option('promote');
        $is_priority_line{$_} = 1 foreach @prioritylines;
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
        foreach my $stop ( @{$stops_r} ) {
            push @usedstops, $stop if $stop_is_used{$stop};
        }
        $used_stops_of_linedir{$linedir} = \@usedstops;
    }

    my @results;

    while ( scalar keys %used_stops_of_linedir ) {

        my $max_linedir
          = _get_max_linedir( \%used_stops_of_linedir, \%is_priority_linedir );

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
} ## tidy end: sub travelsort

sub _get_max_linedir {

    my $stops_of_linedir_r    = shift;
    my $is_priority_linedir_r = shift;

    my $max_linedir;

    if ( option('demote600s') ) {

        $max_linedir = (
            sort {
                ( ( $is_priority_linedir_r->{$b} // 0 )
                    <=> ( $is_priority_linedir_r->{$a} // 0 ) )

                  or

                  ( $a =~ /^6\d\d/ <=> $b =~ /^6\d\d/ )
                  or ( @{ $stops_of_linedir_r->{$b} } <=>
                    @{ $stops_of_linedir_r->{$a} } )
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
                  ( @{ $stops_of_linedir_r->{$b} } <=>
                    @{ $stops_of_linedir_r->{$a} } )
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

Actium::Sorting::Travel is a module that provides special sorting routines
for the Actium system. It sorts by travel line. The purpose is to provide
lists of stops ordered in a way that makes it easier for a maintenance
worker or surveyor to travel down a bus line and visit all the stops,
but without duplicates.

The result is a list of routings, with the affected stops, with all duplicates
removed. It is designed so that the longest lists possible are given.

=head1 SUBROUTINES

Nothing is exported by default, but travelsort() may be requested by 
the calling module.

=over

=item travelsort( I<stops> , I<stops_of_linedir> )

The routine requires two arguments. The first is a reference to an array
of the stops that are to be sorted. 

 [qw<stop_1 stop_2 stop_3>] ...

The second is a hash ref. The keys are the routings and and the 
values are the stops that it uses, in order.

 $ref->{1-Northbound}->[qw<stop_2 stop_1>]
 $ref->{5-Northbound}->[qw<stop_1>]
 $ref->{6-Counterclockwise}->[qw<stop_2>]
 ...
 
Stops on the second list but not on the first list are ignored, allowing 
users to pass (for example) the full set of stops-by-line to the routine.
 
The result is a list of arrayrefs. The first element of each arrayref
is the routing, and the following elements are the stops.

 [qw(5-Northbound stop_3 stop_2 stop_7)]
 [qw(1-Northbound stop_2 stop_1 stop_5)]
 ...
 
=back

=head1 OPTIONS

This module uses the Actium::Options module to allow users to control
it from the command line.

=over

=item B<-promote>
=item B<-demote600s>

(more to come)

=back

=head1 DEPENDENCIES

=over

=item * 

perl 5.12

=item *

Actium::Options

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 
