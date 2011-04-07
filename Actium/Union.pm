# Actium/Union.pm
# Ordered union of lists

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Union 0.001;

use Carp;

use Algorithm::Diff qw(sdiff traverse_sequences);
use Scalar::Util ('reftype');

use Exporter qw( import );
our @EXPORT_OK = qw(ordered_union distinguish);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub ordered_union {
    my @array_rs = @_;

    _check_arrayrefs(@array_rs);

    # return the first array if there's only one array
    return $array_rs[0] if $#array_rs == 0;

    @array_rs
      = reverse sort { @{$a} <=> @{$b} or "@{$a}" cmp "@{$b}" } @array_rs;

    # sort it so the list with the most entries is first,
    # or alternatively the one that sorts alphabetically latest.
    # The latter test is arbitrary, just to make sure the
    # result is the same each time.

    my $union_r = shift @array_rs;
    foreach my $array_r (@array_rs) {
        $union_r = _ordered_union_pair( $union_r, $array_r );
    }

    return wantarray ? @{$union_r} : $union_r;

}    ## <perltidy> end sub ordered_union

sub _ordered_union_pair {

    my $a_r = shift;    # array ref
    my $b_r = shift;    # array ref

    my @union;
    my @tempa;
    my @tempb;

    my $match = sub {
        push @union, @tempa, @tempb, $a_r->[ $_[0] ];
        @tempa = ();
        @tempb = ();
    };

    my $only_in_a = sub { push @tempa, $a_r->[ $_[0] ] };

    my $only_in_b = sub { push @tempb, $b_r->[ $_[1] ] };

    traverse_sequences(
        $a_r, $b_r,
        {   MATCH     => $match,
            DISCARD_A => $only_in_a,
            DISCARD_B => $only_in_b,
        }
    );

    push @union, @tempa, @tempb;

    return wantarray ? @union : \@union;

    # This works as follows. traverse_sequences goes through the
    # lists as described in the Algorithm::Diff documentation,
    # calling one of the appropriate callbacks whenever the
    # sequencer advances.

    # When there is an item that is in only one of the lists,
    # the callback adds that item to the appropriate temporary array.
    # Then, when there is a match, it pushes each of the temporary
    # arrays to the union array, followed by the current (matching) item.
    # Then it empties the temporary arrays. Thus, every time there is
    # a match, each of the differing sequences prior to it are added to the
    # union. It adds the a-sequence before the b-sequence; ordered_union
    # ensures that this is from either the longer sequence or the one that's
    # latest in alphabetical order.

    # Finally, at the end, the temporary arrays are pushed onto @union,
    # in case the last entry isn't a match.

    # In normal usage most of the time the temporary arrays will be empty.
    # But this ensures that the sequences /A 1 2 Z/ and /A L M Z/ will end
    # up as /A 1 2 L M Z/. There's no way to know whether the proper order
    # should have been /A L M 1 2 Z/ instead, but we can be pretty sure
    # that interleaving them -- /A 1 L M 2 Z/ or /A 1 L 2 M Z/ -- is wrong.

}    ## <perltidy> end sub _ordered_union_pair

sub _check_arrayrefs {
    #my $caller    = '$' . shift . '()';
    my $caller;
    ( $caller = ( caller(1) )[3] ) =~ s/.*://;
    my @arrayrefs = @_;
    foreach (@arrayrefs) {
        croak "Arguments to $caller must be array references"
          unless defined( reftype($_) )
              and reftype($_) eq 'ARRAY';
    }
    return;
}

sub distinguish {

    my @inputs = @_;

    _check_arrayrefs(@inputs);
    
    my @check_order = reverse
      sort { scalar @{ $inputs[$a] } <=> scalar @{ $inputs[$b] } }
      ( 0 .. $#inputs );
      

    my ( @firsts, @lasts );
    foreach my $input_r (@inputs) {
        push @firsts, $input_r->[0];
        push @lasts,  $input_r->[-1];
    }

    if ( @inputs == 1 ) {
        return ( [ $firsts[0] ] ) if $firsts[0] eq $lasts[0];
        return [ $firsts[0], $lasts[0] ];
    }

    my @results;

    foreach my $from ( @check_order ) {
        my @sdiffs;
        foreach my $to ( @check_order ) {
            next if $from == $to;
            push @sdiffs,
              [ grep { $_->[0] ne q{+} }
                  @{ sdiff( $inputs[$from], $inputs[$to] ) } ];
        }

        my @input = @{ $inputs[$from] };

        # $sdiffs[to-list][place][0] = change_value (c, +, - , u )
        # $sdiffs[to-list][place][1] = place
        
        my @change_ranges;
        my @prevchanges = ('u') x @sdiffs;
        my $in_a_range  = 0;
        my $final_idx   = $#input;

        for my $idx ( 0 .. $final_idx ) {

            my @thesechanges;
            my $new_u = 0;
            my $new_c = 0;
            foreach my $to ( 0 .. $#sdiffs ) {
                my $this = $sdiffs[$to][$idx][0] eq 'u' ? 'u' : 'c';
                push @thesechanges, $this;
                next if $prevchanges[$to] eq $this;
                if ( $this eq 'u' ) {
                    $new_u = 1;
                }
                else {
                    $new_c = 1;
                }

            }

            if ( $new_u and $in_a_range ) {
                # end of a change range
                $change_ranges[-1][1] = $idx - 1;
                $in_a_range = 0;
            }
            if ($new_c) {
                $change_ranges[-1][1] = $idx - 1 if $in_a_range;
                # start of a change range
                push @change_ranges, [ $idx, undef ];
                $in_a_range = 1;
            }

            @prevchanges = @thesechanges;
        } ## tidy end: for my $idx ( 0 .. $final_idx)

        $change_ranges[-1][1] //= $final_idx if @change_ranges;

        my @relevants;
        foreach my $range (@change_ranges) {
            my ( $start, $end ) = @{$range};
            if ( $start == 0 ) {
                push @relevants, $input[0];
            }
            elsif ( $end == $final_idx ) {
                push @relevants, $input[-1];
            }
            else {
                my $pushed;
                for my $item ( @input[ $start .. $end ] ) {
                    if ( $item eq $firsts[$from] ) {
                        push @relevants, $item;
                        $pushed = 1;
                    }
                    elsif ( $item eq $lasts[$from] ) {
                        push @relevants, $item;
                        $pushed = 1;
                    }
                    last if $pushed;
                }
                if ( not $pushed ) {
                    push @relevants, $input[ ( $start + $end ) / 2 ];
                }
            }

        } ## tidy end: foreach my $range (@change_ranges)
        if ( not( $relevants[0] ) or $relevants[0] ne $firsts[$from] ) {
            unshift @relevants, $firsts[$from];
        }
        if ( $relevants[-1] ne $lasts[$from] ) {
            push @relevants, $lasts[$from];
        }

        $results[$from] = \@relevants;
        #push @results, \@relevants;

    } ## tidy end: foreach my $from ( 0 .. $#inputs)

    #@results = @results[@input_order];
    
    return @results;

} ## tidy end: sub distinguish

1;

__END__

=head1 NAME

Actium::Union - Ordered union of lists for the Actium system

=head1 VERSION

This documentation refers to Actium::Union version 0.001

=head1 SYNOPSIS

 use Actium::Union qw(ordered_union distinguish);
 @list = qw/HILL_MALL CCJR_COLL DELN_BART UNIV_S.P. OAKL_AMTK/;
 @list2 = qw/CAST_TEWK RICH_BART UNIV_S.P. DELN_BART/;
 @list3 = qw/DELN_BART OAKL_AMTK/;
 @union = ordered_union (\@list1, \@list2, \@list3);
 @distinguished = distinguish(\@list1, \@list2, \@list3);
 # @union = qw/HILL_MALL CCJR_COLL CAST_TEWK 
 #             RICH_BART DELN_BART UNIV_S.P. OAKL_AMTK/
 # @distinguished = (
 #  [ qw/HILL_MALL OAKL_AMTK/ ], 
 #  [ qw/CAST_TEWK DELN_BART/ ],
 #  [ qw/DELN_BART OAKL_AMTK/ ] )
 
=head1 DESCRIPTION

Actium::Union consists of two specialized set functions.

=head1 SUBROUTINES

=over

=item B<ordered_union()>

ordered_union is designed to take the union of two sets, preserving the 
order of the two sets as much as possible.  It takes the two lists and 
interleaves the two, coming up with a list that preserves the order of the two
while including all elements.

Most work of this routine comes from L<Algorithm::Diff|Algorithm::Diff>. 
Basically it takes the result from Algorithm::Diff and stitches it back
together again as best it can.

The purpose of this is of course to put together lists of timepoints and stops,
creating a single stop or timepoint list out of multiple lists.

B<ordered_union> takes a series of array references as arguments, and returns
the union of those lists, in order. If you have lists like

 qw/m v c 6   f e w 5 ! a t       m/
 qw/m v c 6 z f   w p @   t r x y m/

(spacing added to emphasize similarities and differences), then the result is

 qw/m v c 6 z f e w 5 ! a p @ t r x y m/

If you pass more than two lists, it runs the algorithm repeatedly until it has
a single remaining list.

Where there is a sequence that differs between the two lists (for example, the
sequences qw/5 1 a/ and qw/p @/ from the above lists),
the algorithm puts the values of the first list ahead of the values from the
second list, keeping values from the same list together until there is a match
again. (It doesn't do something like qw/5 p ! @ a/.)

=item B<distinguish()>

Takes a series of array references as arguments, and provides in turn the relevant
elements from each list, in order to describe the differences between them.

The idea is that if you have a bus line that 
has several variants, travelling through the following points:

 M Q V R 
 M Q V R L Y T
 M Q V R Z X T

you don't actually need to show all these points to distinguish the three lists.
You can say

 M R
 M L T
 M Z T
 
And that is sufficient to distinguish the three lists from each other.

The first and last entry of each list is always retained. Otherwise, entries
that are identical across all the lists are dropped, and of each range of 
differing entries, only one is kept (it tries to pick one in the middle).

=back

=head1 DIAGNOSTICS

=over

=item Arguments to I<caller> must be array references

Something was passed to I<ordered_union()> or I<distinguish()> 
that was not an array reference.

=back

=head1 DEPENDENCIES

=over

=item *

Perl 5.010

=item *

Algorithm::Diff

=back

=head1 BUGS AND LIMITATIONS

There's no good way of determining whether the union of qw/M Q V/ and
qw/M L V/ should be qw/M L Q V/ or qw/M Q L V/. I think this is insoluble
without having more information (e.g., when the letters represent bus stops,
which bus stops are closer).

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 ACKNOWLEDGEMENTS

Thanks to the participants of the UCSC forum (http://www.geek.org/forum/)
for the insight, when I had absolutely no clue how to solve the 
ordered_union problem, that it was a variant of the "diff" problem.

=head1 COPYRIGHT & LICENSE

Copyright 2011 

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
