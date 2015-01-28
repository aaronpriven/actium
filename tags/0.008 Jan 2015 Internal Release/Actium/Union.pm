# Actium/Union.pm
# Ordered union of lists

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Union 0.006;

use Carp;

use Algorithm::Diff qw(sdiff traverse_sequences);
use Scalar::Util ('reftype');

use Sub::Exporter 
   -setup => 
   { exports => [qw(ordered_union distinguish comm ordered_union_columns)] }
;

use Params::Validate (':all');

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
        ( $union_r, undef ) = _comm_unchecked( $union_r, $array_r );
    }

    return wantarray ? @{$union_r} : $union_r;

}    ## <perltidy> end sub ordered_union

sub comm {
    my @array_rs = @_;
    _check_arrayrefs(@array_rs);
    croak "Not enough arguments to comm" if @array_rs < 2;
    croak "Too many arguments to comm"   if @array_rs > 2;
    return _comm_unchecked(@array_rs);
}

sub _comm_unchecked {

    my $a_r = shift;    # array ref
    my $b_r = shift;    # array ref

    my @union;
    my @markers;
    my @tempa;
    my @tempb;

    my $match = sub {
        push @union, @tempa, @tempb, $a_r->[ $_[0] ];
        push @markers, ('<') x @tempa, ('>') x @tempb, '=';

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
    push @markers, ('<') x @tempa, ('>') x @tempb;

    return ( \@union, \@markers );

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

    # It saves what it did in @markers.

    # In normal usage most of the time the temporary arrays will be empty.
    # But this ensures that the sequences /A 1 2 Z/ and /A L M Z/ will end
    # up as /A 1 2 L M Z/. There's no way to know whether the proper order
    # should have been /A L M 1 2 Z/ instead, but we can be pretty sure
    # that interleaving them -- /A 1 L M 2 Z/ or /A 1 L 2 M Z/ -- is wrong.

} ## tidy end: sub _comm_unchecked

my $sethash_callback = {

    'not a hash of lists' => sub {
        my $sethash_r = shift;
        while ( my ( $id, $set_r ) = each %{$sethash_r} ) {
            my $reftype = reftype($set_r);
            if ( not( $reftype and $reftype eq 'ARRAYREF' ) ) {
                return 0;
            }
        }
        return 1;
      }

};

#my $sets_callback = {
#    'not a list of lists' => sub {
#        my $sets_r = shift;
#        foreach ( @{$sets_r} ) {
#            my $reftype = reftype($_);
#            if ( not( $reftype and $reftype eq 'ARRAYREF' ) ) {
#                return 0;
#            }
#            return 1;
#        }
#      }
#};
#
#my $set_ids_callback = {
#    'different number of set IDs as sets' => sub {
#        my $set_ids_r = shift;
#        my $sets_r    = $_[0]->{sets};
#        return ( scalar @$set_ids_r == scalar @$sets_r );
#      }
#};

my $ordered_union_columns_validspec = {
    sethash => { type => HASHREF, callback => $sethash_callback, },
    tiebreaker => {
        type    => CODEREF,
        default => sub { return 0 }
    },
};

sub ordered_union_columns {

    ### GET PARAMETERS

    my %params = validate( @_, $ordered_union_columns_validspec );

    my $tiebreaker = $params{tiebreaker};
    
    my %set_of = %{ $params{sethash} };
    
    my @ordered_ids = map  { $_->[0] }
          reverse sort {
               @{$a->[1]} <=> @{$b->[1]} or "@{$a->[1]}" cmp "@{$b->[1]}" 
          }
          map  { [$_, $set_of{$_} ] }
          keys %set_of;
    
    # sort it so the list with the most entries is first,
    # or alternatively the one that sorts alphabetically latest.
    # The latter test is arbitrary, just to make sure the
    # result is the same each time.

    ### INITIALIZE LOOP OF ARRAYS
    
    my $first_set_id = shift @ordered_ids;
    
    my $union_set_r  = $set_of{$first_set_id};        # longest entry
    my $highest_col  = $#{$union_set_r};
    my $union_cols_r = [ 0 .. $highest_col ];

    my %cols_of = ( $first_set_id => [ 0 .. $highest_col ] );

    my $markers_r;

    while (@ordered_ids) {
        my $set_id = shift @ordered_ids;
        my $set_r = $set_of{$set_id};
        my $set_cols;

        ( $union_set_r, $union_cols_r, $markers_r, $set_cols )
          = _columns_pair( $union_set_r, $union_cols_r, $set_r,
            $tiebreaker );

        $cols_of{$set_id} = $set_cols;

    }

    ### CONVERT COLUMN IDS TO COLUMN INDEXES
    # previous column IDs aren't in numeric order.
    # This makes indexes that are in order.

    # go through the list of column id, and identify the index of that id
    my %idx_of_id;
    for my $idx ( 0 .. $#{$union_cols_r} ) {
        my $id = $union_cols_r->[$idx];
        $idx_of_id{$id} = $idx;
    }

    # set the $col_idx_of{$set_id} to be the numeric index of
    # the values in $col_of{$set_id}
    my %col_idxs_of;
    foreach my $set_id ( keys %cols_of ) {
        $col_idxs_of{$set_id}
          = [ map { $idx_of_id{$_} } @{ $cols_of{$set_id} } ];
    }

    my %return = (
        union      => $union_set_r,
        markers    => $markers_r,
        columns_of => \%col_idxs_of,
    );

} ## tidy end: sub ordered_union_columns

sub _columns_pair {

    my ( $a_r, $a_col_r, $b_r, $tiebreaker ) = @_;
    
    my $highest_col = $#{$a_r};

    my ( @union, @u_col, @b_col,     @markers );
    my ( @tempa, @tempb, @tempa_col, @tempb_col );

    my $only_in_a = sub {
        my $idx = $_[0];
        push @tempa,     $a_r->[$idx];
        push @tempa_col, $a_col_r->[$idx];

        # when we get a value that's only in the first list,
        # we add it to the temporary first list, and
        # add the previously generated column id to the temporary
        # first column list. The temporary lists are added
        # to the union lists later

    };

    my $only_in_b = sub {
        push @tempb, $b_r->[ $_[1] ];
        my $thiscol = ++$highest_col;
        push @tempb_col, $thiscol;
        push @b_col,     $thiscol;

        # when we get a value that's only in the second list,
        # we add it to the temporary second list, and
        # generated a new column id, which we put in the temporary
        # second column list, and also the b column list.
        # The temporary lists are added to the union lists later.
        # The b column list is returned to ordered_union_columns, and
        # stored associated with the b list's id.

    };

    my $add_temps_to_union_r = sub {
     
        return unless @tempa or @tempb;
        
        my $following_value = shift;

        my $previous_value = @union ? $union[-1] : undef;

        my $afirst = (
            $tiebreaker->(
                \@tempa, \@tempb, $previous_value, $following_value
              ) <= 0
        );

        if ($afirst) {
            push @union, @tempa,     @tempb;
            push @u_col, @tempa_col, @tempb_col;
            push @markers, ('<') x @tempa, ('>') x @tempb;
        }
        else {
            push @union, @tempb,     @tempa;
            push @u_col, @tempb_col, @tempa_col;
            push @markers, ('>') x @tempb, ('<') x @tempa;
        }

        @tempa     = ();
        @tempa_col = ();
        @tempb     = ();
        @tempb_col = ();

    };

    my $match = sub {

        my $matching_idx = $_[0];

        my $matching_value = $a_r->[$matching_idx];

        $add_temps_to_union_r->($matching_value);

        push @union,   $matching_value;
        push @u_col,   $a_col_r->[$matching_idx];
        push @b_col,   $a_col_r->[$matching_idx];
        push @markers, '=';

    };

    traverse_sequences(
        $a_r, $b_r,
        {   MATCH     => $match,
            DISCARD_A => $only_in_a,
            DISCARD_B => $only_in_b,
        }
    );

    $add_temps_to_union_r->();

    return ( \@union, \@u_col, \@markers, \@b_col );

} ## tidy end: sub _columns_pair

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

    foreach my $from (@check_order) {
        my @sdiffs;
        foreach my $to (@check_order) {
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

    } ## tidy end: foreach my $from (@check_order)

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

 use Actium::Union qw(ordered_union comm distinguish);
 @list = qw/HILL_MALL CCJR_COLL DELN_BART UNIV_S.P. OAKL_AMTK/;
 @list2 = qw/CAST_TEWK RICH_BART DELN_BART UNIV_S.P./;
 @list3 = qw/DELN_BART OAKL_AMTK/;
 
 @union = ordered_union (\@list1, \@list2, \@list3);
 
 @distinguished = distinguish(\@list1, \@list2, \@list3);
 
 @comm = comm(\@list1 , \@list2);
 
 # @union = qw/HILL_MALL CCJR_COLL CAST_TEWK 
 #             RICH_BART DELN_BART UNIV_S.P. OAKL_AMTK/
 
 #@comm = (
 # [qw/HILL_MALL CCJR_COLL CAST_TEWK RICH_BART DELN_BART UNIV_S.P. OAKL_AMTK/],
 # [qw/<         <         >         >         =         =         <        /])
 
 # @distinguished = (
 #  [ qw/HILL_MALL OAKL_AMTK/ ], 
 #  [ qw/CAST_TEWK DELN_BART/ ],
 #  [ qw/DELN_BART OAKL_AMTK/ ] )
 
=head1 DESCRIPTION

Actium::Union consists of four specialized set functions.

=head1 SUBROUTINES

=over

=item B<ordered_union()>

ordered_union is designed to take the union of two sets, preserving the 
order of the two sets as much as possible.  It takes the two lists and 
interleaves the two, coming up with a list that preserves the order of the two
while including all elements.

Most of the work of this routine comes from L<Algorithm::Diff|Algorithm::Diff>. 
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

=item B<comm()>

This routine is named after the Unix utility C<comm>, in that it is similar
conceptually, even though the results are different.
(I couldn't think of a better name. Sorry.)

It accepts as its 
arguments two lists which are to be compared.  It returns the unified list,
as I<ordered_union> does, but also provides a second list, with markers as to 
whether each result is from the first list only ('<'), the second list only
('>'), or both lists ('=').

To use the example from above, if passed the two lists

 qw/m v c 6   f e w 5 ! a t       m/
 qw/m v c 6 z f   w p @   t r x y m/

then the result from comm would be

 [ qw/m v c 6 z f e w 5 ! a p @ t r x y m/ ,
   qw/= = = = > = < = < < = > > = > > > =/ ]
 
Unlike I<ordered_union>, I<comm> can accept only two lists as arguments.

=item B<ordered_union_columns>

ordered_union_columns is an elaboration on ordered_union. It takes the 
following named parameters, which may be specified in a hash or as a hash 
reference. (L<Params::Validate|Params::Validate> is used for validating 
parameters.)

=over

=item sets

This must be an array reference, containing references to other arrays which
are the sets that are unified. It is required.

=item ids

This is another array reference. It should contain a unique ID for each set
that is passed. This is used in the columns_of return value. If it is not
specified, the lists are assigned the ids ( 0, 1, 2, ... ) and so on.

=item tiebreaker

When there is a sequence that differs between the two lists (such as the 
qw/5 1 a/ and qw/p @/ seqeuences from the example above), there is no way for
the algorithm to know which goes first. The tiebreaker parameter allows the user
to pass in a function that will determine whether a first list or second list
will go first. It should return a value less than zero if the first list should 
go first, zero if it can't make a determination, or a value greater than zero if
the second list should go first. (The values are chosen to be similar to the
blocks in the sort function, and to allow easy use of the <=> and cmp operators.

An example:

 tiebreaker => sub { 
     my @a = @{+shift};
     my @b = @{+shift};
     return @a <=> @b;
 };
 
That would put the longest sequence first.

Four arguments are passed to the tiebreaker function: a reference to the first
sequence, a reference to the second sequence, the value in the combined list 
that would come before the two sequences (or undef if there is none), and the
value in the combined list that would come after the two sequences.

=back

The return values are passed in a hash reference, which has the following 
values:

=over

=item union

This contains the new unified list, the same as that which would be 
returned by ordered_union (barring the effect of tiebreakers).

=item markers

This contains a set of markers such as that returned by comm() (see above). 
The values are not meaningful unless exactly two lists were passed to the
function.

=item columns_of

This is a hash reference. The keys are the id's for each of the lists, and the
values are array references indicating what column in the unified list
corresponds to each column in the passed lists.

For example, suppose we take the union of the following lists:

 ID 'A':  qw/m v c 6   f e w 5 ! a t       m/
 ID 'B':  qw/m v c 6 z f   w p @   t r x y m/
 
The union would be, with the column numbers below it:
 union            =>  qw/m v c 6 z f e w 5 !  a  p  @  t  r  x  y  m/
  (union columns)        0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17

 
The columns_of hash would look like:

 columns => { A => [0 1 2 3 5 6 7 8 9 10 13 17] ,
#                qw/m v c 6 f e w 5 !  a  t  m/

              B => [0 1 2 3 4 5 7 11 12 13 14 15 16 17 ] }
#                qw/m v c 6 z f w  p  @  t  r  x  y m/
 
The idea is that if I have a column of data that matches the headers in list
B, that I can then put that column in the right place in the unified list.

=back



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

Something was passed to I<ordered_union()>, I<comm()> or I<distinguish()> 
that was not an array reference.

=item Not enough arguments to comm
=item Too many arguments to comm

The I<comm> routine can compare two, but only two, lists. Some number of lists
other than two were passed to it.

=back

=head1 DEPENDENCIES

=over

=item Perl 5.012

=item Algorithm::Diff

=item Params::Validate

=back

=head1 BUGS AND LIMITATIONS

The ordered_union_columns routine was written later, and arguably all
three of ordered_union, comm, and ordered_union_columns should be combined
in some way (the way ordered_union and comm already are).

The distingish routine needs better comments in the code.

The comm routine could be redone so that instead of using symbols,
it uses IDs -- this would allow more than one to be used. (In the simplest case,
"<" would be "A", ">" would be "B", and "=" would be the combination of A and B,
probably "A\tB").

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 ACKNOWLEDGEMENTS

Thanks to the participants of the UCSC forum (http://www.geek.org/forum/)
for the insight, when I had absolutely no clue how to solve the 
ordered_union problem, that it was a variant of the "diff" problem.

=head1 COPYRIGHT & LICENSE

Copyright 2012 

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
