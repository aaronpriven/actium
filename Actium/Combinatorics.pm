# Actium/Combinatorics.pm

# Permutations, partitions, and combinations for Actium

# Subversion: $Id$

# legacy status: 4

package Actium::Combinatorics 0.002;

use 5.016;
use warnings;

use Algorithm::Combinatorics(':all');
use Actium::Util('population_stdev');

use Sub::Exporter -setup => {
    exports => [
        qw<
          ordered_partitions
          odometer_combinations
          >
    ]
};

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

    my $data_r     = shift;
    my $num_frames = shift;

    my $final_idx = $#{$data_r};

    if ( not defined $num_frames ) {
        my @all_partitions;
        for ( 1 .. $final_idx ) {
            push @all_partitions, ordered_partitions( $data_r, $_ );
        }
        return @all_partitions;
    }

    my @indices = ( 0 .. $final_idx - 1 );
    my @break_after_idx_sets = combinations( \@indices, $num_frames - 1 );

    my @partitions;

    foreach my $break_after_idx_set (@break_after_idx_sets) {
        my @partition;
        my @break_after_idx = @$break_after_idx_set;

        push @partition, [ $data_r->[ 0 .. $break_after_idx[0] ] ];

        for my $i ( 1 .. $#break_after_idx ) {
            my $first = $break_after_idx[ $i - 1 ] + 1;
            my $last  = $break_after_idx[$i];
            push @partition, [ $data_r->[ $first .. $last ] ];
        }

        push @partition,
          [ $data_r->[ 1 + $break_after_idx[-1] .. $final_idx ] ];

        my @sort_values = map { scalar @{$_} } @partition;
        # count of tables in each frame

        unshift @sort_values, population_stdev(@sort_values);
        # standard deviation -- so makes them as close to the same
        # number of tables as possible

        push @partitions, [ \@partition, \@sort_values ];

    } ## tidy end: foreach my $break_after_idx_set...

    @partitions = sort _ordered_partition_sort @partitions;

    return map { $_->[0] } @partitions;

} ## tidy end: sub ordered_partitions

sub _ordered_partition_sort {
    my @a = @{ $a->[1] };
    my @b = @{ $b->[1] };

    # first, return the comparison of the standard deviations of the
    # count of tables in each frame

    my $result = $a[0] <=> $b[0];
    return $result if $result;

    # If those are the same, go through the remaining values,
    # which are the counts of the tables in each frame.
    # Return the one that's highest first -- so it will
    # prefer [2, 1] over [1, 2]
    for my $i ( 1 .. $#a ) {
        my $result = $b[$i] <=> $a[$i];
        return $result if $result;
    }

    return 0;    # the same...

} ## tidy end: sub _ordered_partition_sort

sub odometer_combinations {
 
    # This is a stupid name but I don't know what to call it.
    # You pass this a list of lists, and it gives you all the possible
    # combinations of one from each list.
    #
    # So, if you have [ [ A, B, C] , [ D ] , [E, F ]],
    # and you call this, you'll end up with
    # [ A , D , E ] , [ B , D , E ], [ C, D, E ],
    # [ A , D , F ] , [ B , D , F ], [ C, D, F ]

    my @list_of_lists = @_;

    my ( @combinations, $odometer_r, $maxes_r );

    foreach my $i ( 0 .. $#list_of_lists ) {
        $odometer_r->[$i] = 0;
        $odometer_r->[$i] = $#{ $list_of_lists[$i] };
    }

    while ($odometer_r) {
        my @combination
          = map { $list_of_lists[ $odometer_r->[$_] ] } 0 .. $#list_of_lists;
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
