package Actium::Clusterize 0.012;

use Actium::Preamble;

use Sub::Exporter -setup => { exports => [qw(fold_clusters)] };    ### DEP ###

sub unfold_clusters {

    ( my $size, \my %count_of_leaf ) = _validate_unfold(@_);

    \my ( @roots, %count_of_node, %children_of ) = _nodes( \%count_of_leaf );
    # add %leaves_of

    my @to_process = @roots;
    my @processed;

  NODE:
    while (@to_process) {

        my $node = shift @to_process;
        if (   $count_of_node{$node} < $size
            or not exists $children_of{$node}
            or scalar $children_of{$node} == 1 )
        {
            push @processed, $node;
            next NODE;
        }

        foreach my $child_idx ( reverse 0 .. $#{ $children_of{$node} } ) {

            my $child = $children_of{$node}[$child_idx];

            if ( $count_of_node{$child} >= $size
                and ( $count_of_node{$node} - $count_of_node{$child} ) >= $size )
            {
                $count_of_node{$node} -= $count_of_node{$child};
                push @processed, $child;
                unshift @to_process, $node;
                splice ($children_of{$node}->@*,$child_idx,1);
                # also remove the leavf from leaves_of{node}
            }

        }

    } ## tidy end: NODE: while (@to_process)
    
    # now @processed is the list of clusters
    # need to return %leaves_of{@processed}
    
}

    sub _validate_unfold {
        my %params = validate(
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

    sub _nodes {

        \my %count_of_leaf = shift;

        my $length = u::max( map {length} keys %count_of_leaf );

        my ( %count_of_node, %is_a_root, %children_of );

        foreach my $leaf ( keys %count_of_leaf ) {
            my @chars = split( //, $leaf );
            if ( @chars < $length ) {
                push @chars, " " x ( $length - @chars );
            }

            my $leafcount = $count_of_leaf{$leaf};

            while ( @chars > 1 ) {

                my $node = join( $EMPTY, @chars );
                $count_of_node{$node} += $leafcount;

                pop @chars;

                my $parent = join( $EMPTY, @chars );
                push $children_of{$parent}->@*, $node;

            }

            $is_a_root{ $chars[0] } = 1;
            $count_of_node{ $chars[0] } += $leafcount;

        } ## tidy end: foreach my $leaf ( keys %count_of_leaf)

        return [ keys %is_a_root ], \%count_of_node, \%children_of;

    } ## tidy end: sub _nodes

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
            croak "Invalid "
              . u::reftype($ref)
              . " reference passed to clusterize";
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

                next unless defined $count_of{$cluster};   # already been yanked
                next if $count_of{$cluster} >= $CLUSTER_MINIMUM;

                # find non-folded children
                my @children = grep /^${cluster}[0-9]+/, @clusters;
                next unless @children;

                my $cluster_average
                  = u::mean( map { substr( $_, 1 ) } $leaves_of{$cluster}->@* );

                my %closeness;

                foreach my $child (@children) {
                    my $leaf_average
                      = u::mean( map { substr( $_, 1 ) }
                          $leaves_of{$child}->@* );
                    $closeness{$child}
                      = abs( $leaf_average - $cluster_average );
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
                my $folded
                  = $folded . ( 'x' x ( $leaflength - $foldedlength ) );
                $folded_of{$leaf} = $folded;
            }

        }

        return %folded_of;

    } ## tidy end: sub fold_clusters

    1;
