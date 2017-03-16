package Actium::Clusterize 0.012;

use Actium::Preamble;

use Sub::Exporter -setup => { exports => [qw(unfold_clusters)] };    ### DEP ###
use Set::IntSpan; # dep

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

        #is this a leaf? if so, we're done with it
        if ( not exists $children_of{$node} ) {
            push @processed, $node;
        }

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
        #my $displaynode = _pad(length => $leaf_length, padding => 'x', original => $node );
        my $span = Set::IntSpan::->new(\@leaves);
        my $displaynode = $span->run_list;
        #$displaynode =~ s/,/, /g;
        
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
