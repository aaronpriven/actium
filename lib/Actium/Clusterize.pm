package Actium::Clusterize 0.012;

use Actium::Preamble;

use DDP;

use Sub::Exporter -setup => { exports => [qw(unfold_clusters)] };    ### DEP ###

sub unfold_clusters {

    ( my $size, \my %original_count ) = _validate_unfold(@_);

    ## pad leaves to the longest length, with spaces

    my $leaf_length = u::max( map {length} keys %original_count );

    my %count_of_leaf;
    foreach my $original_leaf ( keys %original_count ) {
        my $newleaf = _pad( length => $leaf_length, original => $original_leaf , padding => " ");
        $count_of_leaf{$newleaf} = $original_count{$original_leaf};
    }

    my ( %count_of_node, %leaves_of, %is_a_root, %children_of );

    foreach my $leaf ( keys %count_of_leaf ) {
        my @chars = split( //, $leaf );
        if ( @chars < $leaf_length ) {
            push @chars, " " x ( $leaf_length - @chars );
        }

        my $leafcount = $count_of_leaf{$leaf};
        $leaves_of{$leaf}{$leaf} = 1;

        while ( @chars > 1 ) {

            my $node = join( $EMPTY, @chars );
            $count_of_node{$node} += $leafcount;

            pop @chars;

            my $parent = join( $EMPTY, @chars );
            $leaves_of{$parent}{$leaf}   = 1;
            $children_of{$parent}{$node} = 1;

        }

        $is_a_root{ $chars[0] } = 1;
        $count_of_node{ $chars[0] } += $leafcount;

    } ## tidy end: foreach my $leaf ( keys %count_of_leaf)

    my @to_process = keys %is_a_root;
    my @processed;

  NODE:
    while (@to_process) {

        my $node = shift @to_process;

        print STDERR "A: to process =";
        my %z = %count_of_node{@to_process};
        p %z;
        say STDERR "B: processing: $node, count = ", $count_of_node{$node};
        %z = %count_of_node{@processed};
        print STDERR "C: processed =";
        p %z;

        #is this a leaf? if so, we're done with it
        if ( not exists $children_of{$node} ) {
            push @processed, $node;
        }

        #        # is there only one child? bump it up
        #        if ( ( scalar keys $children_of{$node}->%* ) == 1 ) {
        #            unshift @to_process, keys %{ $children_of{$node} };
        #            next NODE;
        #        }

        #        # if it's smaller than specified size, we're done with it
        #        if ( $count_of_node{$node} < $size ) {
        #            push @processed, $node;
        #            next NODE;
        #        }

        # sort children by size

        my @children
          = reverse sort { $count_of_node{$a} <=> $count_of_node{$b} }
          keys $children_of{$node}->%*;

        # as long as there are children large enough, and which leave
        # enough left in the node to continue, bump that up

        while ( @children > 1
            and $count_of_node{ $children[0] } >= $size
            and ( $count_of_node{$node} - $count_of_node{ $children[0] } )
            >= $size )
        {

            my $child = shift @children;

            $count_of_node{$node} -= $count_of_node{$child};
            delete $children_of{$node}{$child};
            delete $leaves_of{$node}{$child};

            unshift @to_process, $child;

        }

        if ( @children == 1 ) {
            # only one child left? process it
            unshift @to_process, @children;
        }
        elsif (@children) {
            # more than one child? We know none of them can be removed,
            # so we're done
            push @processed, $node;
        }

    } ## tidy end: NODE: while (@to_process)

    # now @processed is the list of clusters
    # need to return %leaves_of{@processed}

    @processed = sort @processed;

    my %node_of_leaf;

    foreach my $node (@processed) {
        my @leaves = keys $leaves_of{$node}->%*;
        foreach (@leaves) {
            s/ +$//;
        }
        #my $displaynode = $node; 
        #my $displaynode = u::joinseries_ampersand(sort @leaves);
        my $displaynode = _pad(length => $leaf_length, padding => 'x', original => $node );
        
        $node_of_leaf{$_} = $displaynode foreach @leaves;
    }

    return \%node_of_leaf;

} ## tidy end: sub unfold_clusters

sub _validate_unfold {
    my %params = u::validate(
        @_,
        {   size     => { default => 40 },
            count_of => { type    => $PV_TYPE{HASHREF}, optional => 1 },
            clusters => { type    => $PV_TYPE{ARRAYREF}, optional => 1 },
        }
    );

    my %count_of;

    if ( exists $params{clusters} ) {
        croak "Cannot specify both count_of and clusters"
          if exists $params{count_of};
        $count_of{$_}++ foreach ( $params{clusters}->@* );
    }
    elsif ( exists $params{count_of} ) {
        \%count_of = $params{count_of};
    }
    else {
        croak "Must specify either count_of or clusters";
    }

    return $params{size}, \%count_of;
} ## tidy end: sub _validate_unfold

sub _pad {
    
    my %p = @_;

    my $padded_length = $p{length};
    my $orig          = $p{original};
    my $orig_length   = length($orig);
    my $padding = $p{padding};

    my $new = $orig;
    if ( $orig_length < $padded_length ) {
        $new .= $padding x ( $padded_length - $orig_length );
    }

    return $new;

}

1;

__END__

const my $CLUSTER_MINIMUM => 10;

# all clusters must be the same length
# and all characters must be digits except the first one

sub fold_clusters {

    # accepts a hashref of cluster counts, an arrayref of clusters,
    # or a list of clusters

    my %count_of;
    my $ref = shift;

    if ( u::is_hashref($ref) ) {
        \%count_of = $ref;
    }
    elsif ( u::is_arrayref($ref) ) {
        $count_of{$_}++ foreach $ref->@*;
    }
    elsif ( u::is_ref($ref) ) {
        croak "Invalid " . u::reftype($ref) . " reference passed to clusterize";
    }
    else {
        $count_of{$_}++ foreach ( $ref, @_ );
    }

    my %leaves_of = map { $_, [$_] } keys %count_of;
    # this represents the leaves that have been folded into this cluster.

    my %folded_of = map { $_, $_ } keys %count_of;
    # this represents the ancestor that this cluster has been folded into.

    # so, for example,

    # $leaves_of{15} = [ 151, 152, 154 ]
    #    and
    # $folded_of{$151} = 15
    # $folded_of{$152} = 15
    # $folded_of{$153} = 15

    # Before folding, all clusters point to themselves

    my $fold_cr = sub {
        my $child  = shift;
        my $parent = shift;

        if ( not defined $parent ) {
            my @digits = split( //, $child );
            my $lastdigit = pop @digits;
            $parent = join( $EMPTY, @digits );
        }

        $count_of{$parent} += $count_of{$child};
        delete $count_of{$child};

        my @leaves = $leaves_of{$child}->@*;
        push $leaves_of{$parent}->@*, @leaves;
        delete $leaves_of{$child};

        foreach my $leaf (@leaves) {
            $folded_of{$leaf} = $parent;
        }

    };

    my $folded;
    do {
        $folded = 0;
        # first, move anything less than ten down a level,
        # unless it's already at the top level.
        foreach my $leaf ( sort keys %count_of ) {

            next
              if length($leaf) == 1
              or $count_of{$leaf} >= $CLUSTER_MINIMUM;

            # so move this one down
            $fold_cr->($leaf);
            $folded = 1;

        }

        # Then, if a cluster still has less than ten,
        # yank down the cluster whose average descendant value
        # is closest to that of its own descendants

        my @clusters = sort keys %count_of;
        foreach my $cluster (@clusters) {

            next unless defined $count_of{$cluster};    # already been yanked
            next if $count_of{$cluster} >= $CLUSTER_MINIMUM;

            # find non-folded children
            my @children = grep /^${cluster}[0-9]+/, @clusters;
            next unless @children;

            my $cluster_average
              = u::mean( map { substr( $_, 1 ) } $leaves_of{$cluster}->@* );

            my %closeness;

            foreach my $child (@children) {
                my $leaf_average
                  = u::mean( map { substr( $_, 1 ) } $leaves_of{$child}->@* );
                $closeness{$child} = abs( $leaf_average - $cluster_average );
            }

            @children
              = sort { $closeness{$a} <=> $closeness{$b} } @children;

            foreach my $child (@children) {
                $fold_cr->( $child, $cluster );
                last if $count_of{$cluster} >= $CLUSTER_MINIMUM;
            }

        } ## tidy end: foreach my $cluster (@clusters)
    } while $folded;

    # now go back and de-generalize where possible

    foreach my $cluster ( keys %count_of ) {
        next
          if defined $folded_of{$cluster}
          and $folded_of{$cluster} == $cluster;

        my @leaves = $leaves_of{$cluster}->@*;

        if ( @leaves == 1 ) {
            $folded_of{ $leaves[0] } = $leaves[0];
            delete $folded_of{$cluster};
            next;
        }

        my @parents = @leaves;

        while ( length( $parents[0] ) > 1 ) {
            chop @parents;

            if ( ( scalar( u::uniq @parents ) ) == 1 ) {
                $folded_of{$_} = $parents[0] foreach @leaves;
                last;
            }
        }

    } ## tidy end: foreach my $cluster ( keys ...)

    # put the x's on the end

    foreach my $leaf ( keys %folded_of ) {
        my $folded       = $folded_of{$leaf};
        my $leaflength   = length($leaf);
        my $foldedlength = length($folded);
        if ( $leaflength > $foldedlength ) {
            my $folded = $folded . ( 'x' x ( $leaflength - $foldedlength ) );
            $folded_of{$leaf} = $folded;
        }

    }

    return %folded_of;

} ## tidy end: sub fold_clusters

1;
