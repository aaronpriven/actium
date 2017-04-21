package Actium::Combinatorics 0.012;

# Permutations, partitions, and combinations for Actium

use 5.016;
use warnings;

use Algorithm::Combinatorics(':all'); ### DEP ###
use Actium::Util('population_stdev');

use Sub::Exporter -setup => {
    exports => [ qw< ordered_partitions odometer_combinations > ]
};
# Sub::Exporter ### DEP ###

sub ordered_partitions {

    # The idea here is that partitions are identified by a combination
    # of numbers representing the breaks between items.

    # So if you have items qw<a b c d e> then the possible breaks are
    # after a, after b, after c, or after d --
    # numbered 0, 1, 2 and 3.

    # If you have two frames, then you have one break between them.
    # If you have three frames, then you have two breaks between them.

    # This gets all the combinations of breaks between them and
    # then creates the subsets that correspond to those breaks,
    # and returns the subsets. So, if you have two frames, the results are
    # [ a] [ b c d e] , [ a b ] [ c d e] , [a b c] [ d e ], [a b c d] [e].

    # These sorted by which one we'd want to use first
    # (primarily, which combination yields even results, and then
    # if it can't be even, having the extra one at the front rather than
    # at the back or the middle)

    # This differs from
    # Algorithm::Combinatorics::partitions(\@tables, $num_frames)
    # only that it preserves the order. partitions could return
    # [ b] [ a c d e]
    # but this routine will never do that.
    # I am not sure whether this is actually good or not.  Wouldn't
    # it be weird to have a big NX1 table followed by small NX and NX2 tables?
    # If not, then this could be replaced with partitions, as above.

    my @data     = @{+shift};
    my $num_frames = shift;

    my $final_idx = $#data;

    if ( not defined $num_frames ) {
        my @all_partitions;
        for ( 1 .. @data ) {
            push @all_partitions, ordered_partitions( \@data, $_ );
        }
        return @all_partitions;
    }
    
    if ($num_frames == @data ) {
        return [ map { [ $_ ] } @data ];
    }
    if ($num_frames == 1 ) {
        return [ \@data ];
    }
    
    my @indices = ( 0 .. $final_idx - 1 );
    my @break_after_idx_sets = combinations( \@indices, $num_frames - 1 );
    
    my @partitions;

    foreach my $break_after_idx_set (@break_after_idx_sets) {
        my @partition;
        my @break_after_idx = @$break_after_idx_set;

        push @partition, [ @data[ 0 .. $break_after_idx[0] ] ];

        for my $i ( 1 .. $#break_after_idx ) {
            my $first = $break_after_idx[ $i - 1 ] + 1;
            my $last  = $break_after_idx[$i];
            push @partition, [ @data[ $first .. $last ] ];
        }

        push @partition,
          [ @data[ 1 + $break_after_idx[-1] .. $final_idx ] ];
          
        push @partitions, \@partition;

#        my @sort_values = map { scalar @{$_} } @partition;
#        # count of tables in each frame
#
#        unshift @sort_values, population_stdev(@sort_values);
#        # standard deviation -- so makes them as close to the same
#        # number of tables as possible
#
#        push @partitions, [ \@partition, \@sort_values ];
#
#    } ## tidy end: foreach my $break_after_idx_set...
#
#    @partitions = sort _ordered_partition_sort @partitions;
#
#    return map { $_->[0] } @partitions;

    }
    
    return @partitions;

} ## tidy end: sub ordered_partitions


sub odometer_combinations {
 
    # This is a stupid name but I don't know what to call it.
    # You pass this a list of lists, and it gives you all the possible
    # combinations of one from each list.
    #
    # So, if you have [ [ A, B, C] , [ D ] , [E, F ]],
    # and you call this, you'll end up with
    # [ A , D , E ] , [ B , D , E ], [ C, D, E ],
    # [ A , D , F ] , [ B , D , F ], [ C, D, F ]

    # Note that the CPAN module Iterator::Array::Jagged may do the same thing,
    # in which case it might be better to use that code instead.  I just 
    # looked at that module briefly without looking to see whether it 
    # made sense.

    my @list_of_lists = @_;

    my ( @combinations);
    my $odometer_r = [];
    my $maxes_r = [];

    foreach my $i ( 0 .. $#list_of_lists ) {
        $odometer_r->[$i] = 0;
        $maxes_r->[$i] = $#{ $list_of_lists[$i] };
    }

    while ($odometer_r) {
     
        #my @combination;
        #for my $wheel (0 .. $#list_of_lists) {
        #   push @combination, $list_of_lists[$wheel][$odometer_r->[$wheel]];
        #}
           
         my @combination
          = map { $list_of_lists[$_][ $odometer_r->[$_] ] } 0 .. $#list_of_lists;
        push @combinations, \@combination;
        $odometer_r = _odometer_increment( $odometer_r, $maxes_r );
    }
    return @combinations;

} ## tidy end: sub _odometer_combinations

sub _odometer_increment {
    my $odometer_r = shift;
    my $maxes_r    = shift;

    my $wheel = $#{$odometer_r};    # start at rightmost wheel

    until ( $odometer_r->[$wheel] < $maxes_r->[$wheel] || $wheel < 0 ) {
        $odometer_r->[$wheel] = 0;
        $wheel--;                   # next wheel to the left
    }
    if ( $wheel < 0 ) {
        return;                     # fell off the left end; no more sequences
    }
    else {
        ( $odometer_r->[$wheel] )++;    # this wheel now turns one notch
        return $odometer_r;
    }
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
