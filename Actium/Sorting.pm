# Actium/Sorting.pm
# Sorting routines (by line designation, or by travel route)

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Sorting 0.001;

use Storable;
use Actium::Options (qw(add_option option));

use Exporter qw( import );
our @EXPORT_OK = qw(byline sortbyline linekeys travelsort);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

add_option( 'lettersfirst!',
        'When lines are sorted, sort letters ahead of numbers '
      . '(like Muni, not AC)' );

########################
### SORTING BY LINE NAME
########################

sub linekeys {
    my @keys;
    foreach my $line (@_) {
        if ( option('lettersfirst') ) {
            push @keys, _letters_first($line);
        }
        else {
            push @keys, _numbers_first($line);
        }
    }
    return @keys;
}

sub _numbers_first {

    # this is derived from Sort::Key::Natural

    my $line = uc(shift);

    my @parts = $line =~ /\d+|[[:alpha:]]+/g;

    # @parts is $line, divided into digit parts or alphanumeric parts
    # e.g.,
    #   $line      @parts
    #   A          ( A )
    #   72         ( 72 )
    #   72M        ( 72 , M )
    #   MA1        ( MA , 1 )
    #   A11A        ( A  , 11 , A )

    for (@parts) {

        if (m/ \A 0+ \z/sx) {    # special case: if it's zero
            $_ = '10';
        }
        elsif (m/\A\d/sx) {      # otherwise, for digit parts,

            s/ \A 0+ //sx;       # remove leading zeroes

            my $len       = length($_);
            my $nines     = int( $len / 9 );
            my $remainder = $len % 9;

            $_ = ( '9' x $nines ) . $remainder . $_;

            # That adds a string representing the length of the number
            # to the front of the part.
            # So, it turns "1" into "11", "57" into "257", and so forth.
            # For numbers 9 or more digits long, it adds a 9 in front of the
            # length for each 9 digits: a 10-digit number will have "90"
            # added, an 11-digit number will have "91" added, an 18-digit number
            # will have "990", etc.

            # This ends up sorting, using the 'cmp' operator,
            # the same as a numeric comparison for the numeric parts,
            # while continuing to have a string comparison for the
            # non-numeric parts.

        }    ## <perltidy> end elsif (m/^\d/)

    }    ## <perltidy> end for (@parts)

    return join( "\0", @parts );

}    ## <perltidy> end sub _numbers_first

sub _letters_first {
    my $key = _numbers_first(@_);
    $key =~ s/\0(\d)/\cA$1/g;
    $key = "\1" . $key if $key =~ m/^[[:alpha:]]/;
    return $key;
}

sub byline ($$) {    ## no critic (ProhibitSubroutinePrototypes)
    my ( $a, $b ) = linekeys(@_);
    return $a cmp $b;
}

sub sortbyline {
    return sort { byline( $a, $b ) or $a cmp $b } @_;
}

###################################
### SORTING BY TRAVEL ROUTES
###################################

sub travelsort {

    my %stop_is_used;
    $stop_is_used{$_} = 1 foreach @{ +shift };

    my %allstops_of_linedir = %{ +shift };

    # keys: travel routes. values: array ref of stops

    # Make new %used_stops_of_linedir with only stops
    # on the first list

    my %used_stops_of_linedir;

    while ( my ( $linedir, $stops_r ) = each %allstops_of_linedir ) {
        my @usedstops;
        foreach my $stop ( @{$stops_r} ) {
            push @usedstops, $stop if $stop_is_used{$stop};
        }
        $used_stops_of_linedir{$linedir} = \@usedstops;
    }

    my @results;

    while ( scalar keys %used_stops_of_linedir ) {

        my $max_linedir = _get_max_linedir( \%used_stops_of_linedir );

        # $max_linedir is now the line/dir combination with the most stops

        my @stops = @{ $used_stops_of_linedir{$max_linedir} };

        # and @stops is the current list of stops

        last unless @stops;

        push @results, [ $max_linedir, @stops ];

        # Save the one with the most stops

        delete $used_stops_of_linedir{$max_linedir};

        # delete all stops in the remaining routes
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

    }
    return @results;
}

sub _get_max_linedir {

    my $stops_of_linedir_r = shift;

    my $max_linedir = (
        sort {

            #( $a =~ /^6\d\d/ <=> $b =~ /^6\d\d/ ) or
            ( @{ $stops_of_linedir_r->{$b} } <=>
                  @{ $stops_of_linedir_r->{$a} } )
              or byline( $a, $b )
          } keys %{$stops_of_linedir_r}
    )[0];

    return $max_linedir;
}

1;

__END__

=head1 NAME

Actium::Sorting - special sort routines for Actium system

=head1 VERSION

This documentation refers to version 0.001.

=head1 SYNOPSIS

 use Actium::Sorting qw(byline linekeys);
 @lines        = qw(N N1 NA NA1 1 1R 10 2 20 200 20A );
 @sorted_lines = sortbyline (@lines);
 # @sorted_lines is 1 1R 2 10 20 20A 200 N N1 NA NA1

 @sorted_lines = 
    sort { $mode_of{$a} cmp $mode_of{$b} or byline($a, $b) } (@lines);
 # sorted by mode, and if mode is the same, by line

 @key_of{@lines} = linekeys(@lines);
 @sorted_lines = sort {
     is_special($a) <=> is_special($b)
     or $key_of{$a} cmp $key_of{$b}
 } @lines;
 # same as before, unless some lines are considered special
   
=head1 DESCRIPTION

Actium::Sorting is a module that provides special sorting routines
for the Actium system. 

=head2 By Line

The first kind of sorting is 
by "lines", which sorts transit line designations in 
the appropriate order.  This is a type of "natural" sort.  
It works by generating a key 
associated with each line, which when sorted gives the proper "natural" sort. 
See L<Implementation Details|/IMPLEMENTATION DETAILS> below.

The usual way of designating transit lines is to use a primary 
line number followed by a secondary letter: for example, "42A" is the "A" 
variant of line "42."  Alternatively, lines are often designated with a main
letter or pair of letters, followed by a secondary number: line "A10" or 
"JX1".

When sorting lines that are designated in this fashion, they should be 
sorted first by their main 
line number or letter(s), and then secondarily by any secondary part. Because 
transit line designations are a mixture of letters and 
numbers, a naive sort (purely alphabetical or numerical) will yield 
inappropriate results.

This module can sort lines of arbitrary length and complexity, with very long
line names (AAAAAAAA...) and/or very high numbers of subline
designations (A1B2C3D4...).

Unless the B<-lettersfirst> option is specified on the command line, 
line designations beginning with numbers
are sorted before lines beginning with letters. The module is 
case-insensitive.

=head2 By Travel Route

The second kind of sorting is by travel route. The purpose is to provide
lists of stops ordered in a way that makes it easier for a maintenance
worker or surveyor to travel down a bus route and visit all the stops,
but without duplicates.

The result is a list of routings, with the affected stops, with all duplicates
removed. It is designed so that the longest lists possible are given.

=head1 SUBROUTINES

Nothing is exported by default, but sortbyline(), byline(), linekeys() ,
and travelsort() may be requested by the calling module.

=over

=item sortbyline(I<@lines>)

Returns a list of lines, sorted properly by line. (If lines are not identical but 
have identical sort keys -- for example, if they differ by case, or one line has
extra characters in it -- the sort routine will fall back on a standard perl "cmp" sort.)

=back

=over

=item byline (I<line1>, I<line2>)

The byline() subroutine is typically called as the BLOCK part of a 
L<perlfunc/sort> function call:

  @lines = sort byline @lines;

As required by sort, byline() takes two arguments, which are then compared.
It returns 
-1, 0, or 1, depending on whether the first line should sort before, 
the same as, or after the second line.

It is mainly useful as part of a longer sort block:

=over 2

 @sorted_lines = 
    sort { 
        $mode_of{$a} cmp $mode_of{$b} 
        or byline($a, $b) 
    } (@lines);

=back

=item linekeys (I<line1>, I<line2> [ , ...] )

This routine returns a the sort keys that can be used to
sort the lines that were given, using "cmp" or another stringwise operator.
In this way you can use the values for
sorting in another program, or what have you.

=item travelsort( I<stops> , I<stops_of_linedir> )

The routine requires two arguments. The first  is a reference to an array
of the stops that are to be sorted. 

 [qw<stop_1 stop_2 stop_3>] ...

The second is a hash ref. The keys are the routings and and the 
values are the stops that it uses, in order.

 $ref->{1-Northbound}->[qw<stop_2 stop_1>]
 $ref->{5-Northbound}->[qw<stop_1>]
 $ref->{6-Counterclockwise}->[qw<stop_2>]
 ...
 
Stops on the second list but not on the first list are ignored, allowing 
users to pass (for example) the full set of stops-by-route to the routine.
 
The result is a list of arrayrefs. The first element of each arrayref
is the routing, and the following elements are the stops.

 [qw(5-Northbound stop_3 stop_2 stop_7)]
 [qw(1-Northbound stop_2 stop_1 stop_5)]
 ...

=head1 OPTIONS

This module uses the Actium::Options module to allow users to control
it from the command line.

=over

=item B<-lettersfirst>

B<-lettersfirst> changes the sort order so that lines beginning with letters
are sorted before numbers, instead of the other way around.  This yields
"A, A1, B, 1, 10" instead of "1, 10, A, A1, B".

This does not affect sorting beyond the first character.

=back

=head1 DEPENDENCIES

=over

=item * 

perl 5.12

=item *

Actium::Options

=back

=head1 IMPLEMENTATION DETAILS

The key for sorting by line
is generated by taking all the alphabetical parts (matching perl's "[:alpha:]"
character class) and the numeric parts (matching perl's "\d" character class), changing
the numeric portion so that it sorts properly (by putting the number of digits in the number
ahead of the number), and then reassembling them, joined by NUL characters (\0).

Any characters that are not part of the [:alpha:] or \d classes are dropped when creating
the sort key.  The sortbyline() routine will fall back on a standard (case-sensitive) 
string sort if two lines have identical keys but are not themselves identical. The other
routines simply ignore these characters.

=head1 BUGS AND LIMITATIONS

No attempt has been made to internationalize the sort routine.

=head1 ACKNOWLEDGEMENTS

The line key generation code in this module is based on the CPAN module 
L<Sort::Key::Natural>, by
Salvador Fandiño García. (I did not want to require Sort::Key as a dependency.)

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 