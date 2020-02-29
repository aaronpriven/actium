package Octium::Set 0.014;

use Actium;
use Octium;

use Algorithm::Diff qw(sdiff traverse_sequences);    ### DEP ###
use Algorithm::Combinatorics(':all');                ### DEP ###
use Set::IntSpan;                                    ### DEP ###

use Sub::Exporter -setup => {
    exports => [
        qw(ordered_union distinguish comm ordered_union_columns
          ordered_partitions odometer_combinations clusterize)
    ]
};
# Sub::Exporter ### DEP ###

use Params::Validate (':all');                       ### DEP ###

### CLUSTERIZE

const my $DEFAULT_CLUSTER_SIZE => 40;

func clusterize (
     :$size = $DEFAULT_CLUSTER_SIZE,
     :$root_digits = 1,
     :$return where { $_ eq 'runlist' or $_ eq 'values' } = 'runlist',
     :@all_values is ref_alias = [],
     :@items is ref_alias = [],
     :count_of(%original_count) is ref_alias = {},
    ) {

    if ( @items and scalar keys %original_count ) {
        croak "Cannot specify both count_of and items";
    }
    if ( not @items and not scalar keys %original_count ) {
        croak "Must specify either count_of or items";
    }

    if (@items) {
        my %item_count_of;
        $item_count_of{$_}++ foreach (@items);
        %original_count = %item_count_of;
        # make a copy so it doesn't change an original empty count_of
        # parameter if that was passed in
    }

    ## pad leaves to the longest length, with spaces

    my $leaf_length = Octium::max( map {length} keys %original_count );

    if ( not( Octium::looks_like_number($root_digits) ) or $root_digits < 1 ) {
        croak "Invalid root digit specification $root_digits";
    }

    if ( $leaf_length <= $root_digits ) {
        if ( $return eq 'runlist' ) {
            return +{ map { $_ => $_ } keys %original_count };
        }
        else {
            return +{ map { $_ => [$_] } keys %original_count };
        }
   #croak "Longest leaf length ($leaf_length) less than or equal to the number "
   #  . "of root digits specified ($root_digits)";
    }

    my ( %count_of_leaf, %original_leaf_of );
    foreach my $original_leaf ( keys %original_count ) {
        my $newleaf = sprintf( '%-*s', $leaf_length, $original_leaf );
        $count_of_leaf{$newleaf}    = $original_count{$original_leaf};
        $original_leaf_of{$newleaf} = $original_leaf;
    }

    my ( %count_of_node, %is_a_root, %children_of, %leaves_of );

    foreach my $leaf ( keys %count_of_leaf ) {

        $leaf = scalar( '0' x $leaf_length ) unless $leaf;

        my @chars = split( //, $leaf );
        if ( @chars < $leaf_length ) {
            push @chars, " " x ( $leaf_length - @chars );
        }

        my $leafcount = $count_of_leaf{$leaf};

        while ( @chars > $root_digits ) {

            my $node = join( $EMPTY, @chars );
            $count_of_node{$node} += $leafcount;

            push $leaves_of{$node}->@*, $leaf;

            pop @chars;

            my $parent = @chars ? join( $EMPTY, @chars ) : 'EMPTY';
            $children_of{$parent}{$node} = 1;

        }

        my $root = @chars ? join( $EMPTY, @chars ) : 'EMPTY';
        $is_a_root{$root} = 1;
        $count_of_node{$root} += $leafcount;

    }    ## tidy end: foreach my $leaf ( keys %count_of_leaf)

    my @to_process = keys %is_a_root;
    my @processed;

  NODE:
    while (@to_process) {

        my $node = shift @to_process;

        #is this a leaf? if so, we're done with it
        if ( not exists $children_of{$node} ) {
            push @processed, $node;
        }

        my @children_nodes
          = reverse sort { $count_of_node{$a} <=> $count_of_node{$b} }
          keys $children_of{$node}->%*;

        # as long as there are children large enough, and which leave
        # enough left in the node to continue, bump that up

        while ( @children_nodes > 1
            and $count_of_node{ $children_nodes[0] } >= $size
            and ( $count_of_node{$node} - $count_of_node{ $children_nodes[0] } )
            >= $size )
        {

            my $child = shift @children_nodes;

            $count_of_node{$node} -= $count_of_node{$child};
            delete $children_of{$node}{$child};

            unshift @to_process, $child;

        }

        if ( @children_nodes == 1 ) {
            # only one child left? process it
            unshift @to_process, @children_nodes;
            next NODE;
        }

        @children_nodes = sort @children_nodes;

        my $partition_letter = 'a';

      PARTITION:
        while ( @children_nodes >= 4
            and ( Octium::sum( @count_of_node{@children_nodes} ) )
            >= $size * 2 )
        {

            # so it may be possible to partition these.
            # Any single node that could have worked
            # has been filtered out already, so there must be at
            # least two nodes on either side of the partition, hence minimum 4

            # I am intentionally limiting partitions to consecutive remaining
            # items (I don't want it to do [701,704] and [702,703]).
            # if there is a pathological situation where that can't be
            # partitioned (e.g., 701 => 1, 702=> 2, 703 => 38, 704  => 39 )
            # it's still unlikely to lead to absurdly large clusters

            foreach my $last_item_of_partition ( 1 .. $#children_nodes - 2 ) {

                my @partition = @children_nodes[ 0 .. $last_item_of_partition ];
                my $partition_count = Octium::sum( @count_of_node{@partition} );

                if ( $partition_count >= $size ) {

                    # do the partition

                    splice( @children_nodes, 0, $last_item_of_partition + 1 );

                    my $partition_node = $node . ++$partition_letter;
                    push @processed, $partition_node;

                    $count_of_node{$partition_node} = $partition_count;
                    $count_of_node{$node} -= $partition_count;

                    foreach my $partition_child (@partition) {
                        $children_of{$partition_node}{$partition_child} = 1;
                        delete $children_of{$node}{$partition_child};
                    }

                    next PARTITION;

                }    ## tidy end: if ( $partition_count ...)

            }    ## tidy end: foreach my $last_item_of_partition...

            # got to the end, no partition possible

            last PARTITION;

        }    ## tidy end: PARTITION: while ( @children_nodes >=...)

        # if any of the remaining children of node are not leaves,
        # flatten the structure by a level -- make the grandchildren
        # the children -- and reprocess.

        if ( Octium::any { exists $children_of{$_} } @children_nodes ) {

            foreach my $child_node (@children_nodes) {
                if ( exists $children_of{$child_node} ) {
                    my @grandchildren_nodes
                      = keys $children_of{$child_node}->%*;
                    delete $children_of{$node}{$child_node};
                    foreach my $grandchild_node (@grandchildren_nodes) {
                        $children_of{$node}{$grandchild_node} = 1;
                    }

                }

            }

            unshift @to_process, $node;
            next NODE;

        }

        # if all are leaves, then we're done

        push @processed, $node;

    }    ## tidy end: NODE: while (@to_process)

    # now @processed is the list of clusters
    # need to return %leaves_of{@processed}

    @processed = sort @processed;

    my %node_of_leaf;

    foreach my $processed_node (@processed) {

        # walk children, finding their leaves

        my @to_get_leaves_of = $processed_node;
        my @leaves;

        while (@to_get_leaves_of) {
            my $node = shift @to_get_leaves_of;

            my @children = keys $children_of{$node}->%*;
            @children = ($node) unless @children;

            foreach my $child (@children) {
                if ( exists $original_leaf_of{$child} ) {
                    push @leaves, $original_leaf_of{$child};
                }
                else {
                    push @to_get_leaves_of, $child;
                }
            }

        }

        my $span = Set::IntSpan::->new( \@leaves );

        if (@all_values) {

           # go through each span of holes. If the *entire* hole is missing in
           # all values, then add the hole to the displayed span.
           # If any of the values of the hole is a real value, don't fill it in.

            my $all_values_set = Set::IntSpan->new(@all_values);

            my @holes = $span->holes->sets;
            foreach my $hole_set (@holes) {
                my $diff_set = $hole_set->diff($all_values_set);
                # set of integers in $hole_set but not in $all_values_set
                if ( $hole_set->equal($diff_set) ) {
                    # if they are the same, so no member of the hole is in
                    # all_values_set,
                    $span->U($hole_set);
                    # fill in the hole
                }
            }
        }    ## tidy end: if (@all_values)
        my $returnnode;
        if ( $return eq 'runlist' ) {
            $returnnode = $span->run_list;
        }
        else {
            $returnnode = scalar( $span->elements );
            # returns a reference
        }

        $node_of_leaf{$_} = $returnnode foreach @leaves;
    }    ## tidy end: foreach my $processed_node ...

    return \%node_of_leaf;

}    ## tidy end: func clusterize

### COMBINATORICS

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

    my @data       = @{ +shift };
    my $num_frames = shift;

    my $final_idx = $#data;

    if ( not defined $num_frames ) {
        my @all_partitions;
        for ( 1 .. @data ) {
            push @all_partitions, ordered_partitions( \@data, $_ );
        }
        return @all_partitions;
    }

    if ( $num_frames == @data ) {
        return [ map { [$_] } @data ];
    }
    if ( $num_frames == 1 ) {
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

        push @partition, [ @data[ 1 + $break_after_idx[-1] .. $final_idx ] ];

        push @partitions, \@partition;

    }

    return @partitions;

}    ## tidy end: sub ordered_partitions

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

    my (@combinations);
    my $odometer_r = [];
    my $maxes_r    = [];

    foreach my $i ( 0 .. $#list_of_lists ) {
        $odometer_r->[$i] = 0;
        $maxes_r->[$i]    = $#{ $list_of_lists[$i] };
    }

    while ($odometer_r) {

        my @combination
          = map { $list_of_lists[$_][ $odometer_r->[$_] ] }
          0 .. $#list_of_lists;
        push @combinations, \@combination;
        $odometer_r = _odometer_increment( $odometer_r, $maxes_r );
    }
    return @combinations;

}    ## tidy end: sub odometer_combinations

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

### UNION

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

}    ## tidy end: sub _comm_unchecked

my $sethash_callback = {

    'not a hash of lists' => sub {
        my $sethash_r = shift;
        while ( my ( $id, $set_r ) = each %{$sethash_r} ) {
            my $reftype = Octium::reftype($set_r);
            if ( not( $reftype and $reftype eq 'ARRAYREF' ) ) {
                return 0;
            }
        }
        return 1;
    }

};

my $ordered_union_columns_validspec = {
    sethash    => { type => HASHREF, callback => $sethash_callback, },
    tiebreaker => {
        type    => CODEREF,
        default => sub { return 0 }
    },
};

sub ordered_union_columns {

    ### GET PARAMETERS

    my %params = Octium::validate( @_, $ordered_union_columns_validspec );

    my $tiebreaker = $params{tiebreaker};

    my %set_of = %{ $params{sethash} };

    my @ordered_ids = map { $_->[0] }
      reverse
      sort { @{ $a->[1] } <=> @{ $b->[1] } or "@{$a->[1]}" cmp "@{$b->[1]}" }
      map { [ $_, $set_of{$_} ] }
      keys %set_of;

    # sort it so the list with the most entries is first,
    # or alternatively the one that sorts alphabetically latest.
    # The latter test is arbitrary, just to make sure the
    # result is the same each time.

    ### INITIALIZE LOOP OF ARRAYS

    my $first_set_id = shift @ordered_ids;

    my $union_set_r  = $set_of{$first_set_id};    # longest entry
    my $highest_col  = $#{$union_set_r};
    my $union_cols_r = [ 0 .. $highest_col ];

    my %cols_of = ( $first_set_id => [ 0 .. $highest_col ] );

    my $markers_r;

    while (@ordered_ids) {
        my $set_id = shift @ordered_ids;
        my $set_r  = $set_of{$set_id};
        my $set_cols;

        ( $union_set_r, $union_cols_r, $markers_r, $set_cols )
          = _columns_pair( $union_set_r, $union_cols_r, $set_r, $tiebreaker );

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

}    ## tidy end: sub ordered_union_columns

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

        my $cmpvalue = (
            $tiebreaker->(
                \@tempa, \@tempb, $previous_value, $following_value
            )
        );

        if ( $cmpvalue != 1 ) {
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

}    ## tidy end: sub _columns_pair

sub _check_arrayrefs {
    #my $caller    = '$' . shift . '()';
    my $caller;
    ( $caller = ( caller(1) )[3] ) =~ s/.*://;
    my @arrayrefs = @_;
    foreach (@arrayrefs) {
        croak "Arguments to $caller must be array references"
          unless defined( Octium::reftype($_) )
          and Octium::reftype($_) eq 'ARRAY';
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
        }    ## tidy end: for my $idx ( 0 .. $final_idx)

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

        }    ## tidy end: foreach my $range (@change_ranges)
        if ( not( $relevants[0] ) or $relevants[0] ne $firsts[$from] ) {
            unshift @relevants, $firsts[$from];
        }
        if ( $relevants[-1] ne $lasts[$from] ) {
            push @relevants, $lasts[$from];
        }

        $results[$from] = \@relevants;
        #push @results, \@relevants;

    }    ## tidy end: foreach my $from (@check_order)

    #@results = @results[@input_order];

    return @results;

}    ## tidy end: sub distinguish

1;

__END__

=head1 NAME

Octium::Set - Set functions for the Actium system

=head1 VERSION

This documentation refers to Octium::Set version 0.012

=head1 SYNOPSIS

 use Octium::Set qw(ordered_union comm distinguish clusterize);
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


 my $clusters_of_r =  clusterize (
     count_of => { 101 => 5, 102 => 2 }
     );
     
or

 my $clusters_of_r =  clusterize (
     items => [ 101, 101, 101, 101, 101 , 102, 102, 102 ]
     );
     
 # either way, $clusters_of_r = { '101,102' => 8 }
 
More usefully:

    my %count_of = (
        101 => 5, 102 =>  4, 112 =>   0, 113 =>  1,
        221 => 5, 222 => 43, 233 => 135, 237 => 45,  
          234 => 5, 235 => 43, 251 => 67,
        305 => 2,
        441 => 5, 442 => 8,
        501 => 5, 502 => 4, 510 => 73,
        607 => 8,
        701 => 21, 702 => 21, 703 => 21, 704 => 41, 705 => 21,
    );

 my $clusters_of_r =  clusterize ( count_of => \%count_of );

 # now $clusters_of_r = {
 #   101 =>  '101-102,112-113',
 #   102 =>  '101-102,112-113',
 #   112 =>  '101-102,112-113',
 #   113 =>  '101-102,112-113',
 #   221 =>  '221-222',
 #   222 =>  '221-222',
 #   233 =>  '233',
 #   234 =>  '234-235',
 #   235 =>  '234-235',
 #   237 =>  '237',
 #   251 =>  '251',
 #   305 =>  '305',
 #   441 =>  '441-442',
 #   442 =>  '441-442',
 #   501 =>  '501-502,510',
 #   502 =>  '501-502,510',
 #   510 =>  '501-502,510',
 #   607 =>  '607',
 #   701 =>  '701-702',
 #   702 =>  '701-702',
 #   703 =>  '703,705',
 #   704 =>  '704',
 #   705 =>  '703,705',
 #}
 
=head1 DESCRIPTION

Octium::Set consists of several specialized set functions.

=head1 SUBROUTINES

=over

=item B<ordered_partitions()>

Documentation to come.

=item B<odometer_combinations()>

Documentation to come.

=item B<ordered_union()>

ordered_union is designed to take the union of two sets, preserving the
 order of the two sets as much as possible.  It takes the two lists and
 interleaves the two, coming up with a list that preserves the order of
the two while including all elements.

Most of the work of this routine comes from
L<Algorithm::Diff|Algorithm::Diff>.  Basically it takes the result from
Algorithm::Diff and stitches it back together again as best it can.

The purpose of this is of course to put together lists of timepoints
and stops, creating a single stop or timepoint list out of multiple
lists.

B<ordered_union> takes a series of array references as arguments, and
returns the union of those lists, in order. If you have lists like

 qw/m v c 6   f e w 5 ! a t       m/
 qw/m v c 6 z f   w p @   t r x y m/

(spacing added to emphasize similarities and differences), then the
result is

 qw/m v c 6 z f e w 5 ! a p @ t r x y m/

If you pass more than two lists, it runs the algorithm repeatedly until
it has a single remaining list.

Where there is a sequence that differs between the two lists (for
example, the sequences qw/5 1 a/ and qw/p @/ from the above lists), the
algorithm puts the values of the first list ahead of the values from
the second list, keeping values from the same list together until there
is a match again. (It doesn't do something like qw/5 p ! @ a/.)

=item B<comm()>

This routine is named after the Unix utility C<comm>, in that it is
similar conceptually, even though the results are different. (I
couldn't think of a better name. Sorry.)

It accepts as its  arguments two lists which are to be compared.  It
returns the unified list, as I<ordered_union> does, but also provides a
second list, with markers as to  whether each result is from the first
list only ('<'), the second list only ('>'), or both lists ('=').

To use the example from above, if passed the two lists

 qw/m v c 6   f e w 5 ! a t       m/
 qw/m v c 6 z f   w p @   t r x y m/

then the result from comm would be

 [ qw/m v c 6 z f e w 5 ! a p @ t r x y m/ ,
   qw/= = = = > = < = < < = > > = > > > =/ ]
 
Unlike I<ordered_union>, I<comm> can accept only two lists as
arguments.

=item B<ordered_union_columns>

ordered_union_columns is an elaboration on ordered_union. It takes the 
following named parameters, which may be specified in a hash or as a
hash  reference. (L<Params::Validate|Params::Validate> is used for
validating  parameters.)

=over

=item sets

This must be an array reference, containing references to other arrays
which are the sets that are unified. It is required.

=item ids

This is another array reference. It should contain a unique ID for each
set that is passed. This is used in the columns_of return value. If it
is not specified, the lists are assigned the ids ( 0, 1, 2, ... ) and
so on.

=item tiebreaker

When there is a sequence that differs between the two lists (such as
the  qw/5 1 a/ and qw/p @/ seqeuences from the example above), there is
no way for the algorithm to know which goes first. The tiebreaker
parameter allows the user to pass in a function that will determine
whether a first list or second list will go first. It should return a
value less than zero if the first list should  go first, zero if it
can't make a determination, or a value greater than zero if the second
list should go first. (The values are chosen to be similar to the
blocks in the sort function, and to allow easy use of the <=> and cmp
operators.

An example:

 tiebreaker => sub { 
     my @a = @{+shift};
     my @b = @{+shift};
     return @a <=> @b;
 };
 
That would put the longest sequence first.

Four arguments are passed to the tiebreaker function: a reference to
the first sequence, a reference to the second sequence, the value in
the combined list  that would come before the two sequences (or undef
if there is none), and the value in the combined list that would come
after the two sequences.

=back

The return values are passed in a hash reference, which has the
following  values:

=over

=item union

This contains the new unified list, the same as that which would be 
returned by ordered_union (barring the effect of tiebreakers).

=item markers

This contains a set of markers such as that returned by comm() (see
above).  The values are not meaningful unless exactly two lists were
passed to the function.

=item columns_of

This is a hash reference. The keys are the id's for each of the lists,
and the values are array references indicating what column in the
unified list corresponds to each column in the passed lists.

For example, suppose we take the union of the following lists:

 ID 'A':  qw/m v c 6   f e w 5 ! a t       m/
 ID 'B':  qw/m v c 6 z f   w p @   t r x y m/
 
The union would be, with the column numbers below it:  union           
=>  qw/m v c 6 z f e w 5 !  a  p  @  t  r  x  y  m/   (union columns)  
     0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17

 
The columns_of hash would look like:

 columns => { A => [0 1 2 3 5 6 7 8 9 10 13 17] ,
 #               qw/m v c 6 f e w 5 !  a  t  m/

              B => [0 1 2 3 4 5 7 11 12 13 14 15 16 17 ] }
 #               qw/m v c 6 z f w  p  @  t  r  x  y m/
 
The idea is that if I have a column of data that matches the headers in
list B, that I can then put that column in the right place in the
unified list.

=back

=item B<distinguish()>

Takes a series of array references as arguments, and provides in turn
the relevant elements from each list, in order to describe the
differences between them.

The idea is that if you have a bus line that  has several variants,
travelling through the following points:

 M Q V R 
 M Q V R L Y T
 M Q V R Z X T

you don't actually need to show all these points to distinguish the
three lists. You can say

 M R
 M L T
 M Z T
 
And that is sufficient to distinguish the three lists from each other.

The first and last entry of each list is always retained. Otherwise,
entries that are identical across all the lists are dropped, and of
each range of  differing entries, only one is kept (it tries to pick
one in the middle).

=item B<clusterize()>

The B<clusterize()> routine combines lists of items into
reasonably-sized chunks.

The idea is that there are a certain number of items, each one divided
into a category that is an integer.  Maybe there are different zones of
bus stops, where each zone is given a number: zone 101, zone 102, zone
304, and so on.  If each zone has a significant number of stops that
need work, not much is needed: just make up a separate work order list
for each zone. But what if some zones only have one or two stops? A
separte work order for each stop is overkill.  This routine combines
small zones into larger ones.

The routine assumes that the numbers are hierarchies, and puts together
zones that start with the same numbers.  So, for example, it treats 502
and 5021 as more closely related than 502 and 503, or 5021 and 5120.
This is intentional, as it should make it easier (for example) to add
new  zones in between other zones, without having to rename them.

The B<clusterize> subroutine accepts named parameters. Either
C<count_of> or C<items> must be specified. The other two parameters,
C<root_digits> and  C<size>, are optional.

=over 

=item C<count_of>

This should be a reference to a hash, where the keys are the zone
numbers and the values are the quantities in each zone.

 my $clusters_of_r = clusterize ( count_of => { 101 => 5, 102 => 2 } );
 
=item C<items>

This should be a reference to an array, each containing a zone number.

 my $clusters_of_r = clusterize ( items => { qw/101 101 101 101 101 102 102/);
     
The B<clusterize> subroutine will convert this into a count. Specify
whichever is easier.

=item C<root_digits> (default: 1)

The B<clusterize> routine does not combine zones that have different
roots. For example, using the default, it will never combine zones
beginning with 1 and zones beginning with 2, even if only one stop
begins with 1.  This parameter allows the number of digits treated as
root digits to be specified:

=over

0 -- All items could be combined.

1 -- Items 1000 and 1999 could be combined, but not items 1010 and
2010.

2 -- Items 1010 and 1020 could be combined, but not items 1010 and
1100, or items 1100 and 2100.

=back

And so forth.

=item C<size> (default: 40)

This is the number of items that's considered the minimum size for a
work  order.  Work zones with a quantity of items smaller than this
will be combined with other work zones (unless those work zones have
different roots).

So, for example,

 my $clusters_of_r = clusterize ( count_of => { 101 => 45, 102 => 42 } );
 
will yield C<{ 101 => 101, 102 = 102 }>, but

 my $clusters_of_r = clusterize ( 
      count_of => { 101 => 45, 102 => 42 } , size => 50);
      
will yield C<{ '101' => '101-102', '102' => '101-102' }>.

=back

The result from B<clusterize> will be a reference to a hash. The keys
will be the original items passed to B<clusterize>. The values will be
the new cluster that they are placed in, expressed as a combination of
ranges. So, for example,  a new cluster might be "101" where a single
work zone makes up a cluster, or "102-103" or even
"102-105,107-108,150-151" if that's the result.

=back

=head1 DIAGNOSTICS

=over

=item Arguments to I<caller> must be array references

Something was passed to I<ordered_union()>, I<comm()> or
I<distinguish()>  that was not an array reference.

=item Not enough arguments to comm

=item Too many arguments to comm

The I<comm> routine can compare two, but only two, lists. Some number
of lists other than two were passed to it.

=item Invalid root digit specification $root_digits

clusterize: The root_digit parameter was not a number, or it was
negative.

=item Cannot specify both count_of and items

=item Must specify either count_of or items

One, and only one, of C<count_of> or C<items> must be specified  to
B<clusterize>. If neither is specified, there's nothing to work on; if
both are specified, it's not clear which should be worked on.

=item Cannot specify both count_of and items

=item Must specify either count_of or items

One, and only one, of C<count_of> or C<items> must be specified to
B<clusterize>. If neither is specified, there's nothing to work on; if
both are specified, it's not clear which should be worked on.

=back

=head1 DEPENDENCIES

=over

=item Actium

=item Algorithm::Combinatorics

=item Algorithm::Diff

=item Params::Validate

=item Set::IntSpan

=back

=head1 BUGS AND LIMITATIONS

The ordered_union_columns routine was written later, and arguably all
three of ordered_union, comm, and ordered_union_columns should be
combined in some way (the way ordered_union and comm already are).

The distingish routine needs better comments in the code.

The comm routine could be redone so that instead of using symbols, it
uses IDs -- this would allow more than one to be used. (In the simplest
case, "<" would be "A", ">" would be "B", and "=" would be the
combination of A and B, probably "A\tB").

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 ACKNOWLEDGEMENTS

Thanks to the participants of the UCSC forum
(http://www.geek.org/forum/) for the insight, when I had absolutely no
clue how to solve the  ordered_union problem, that it was a variant of
the "diff" problem.

=head1 COPYRIGHT & LICENSE

Copyright 2012-2017

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

