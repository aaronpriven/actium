package Actium::Clusterize 0.012;

use Actium::Preamble;

use Sub::Exporter -setup => { exports => [qw(clusterize)] };    ### DEP ###
use Set::IntSpan;                                               ### DEP ###

sub clusterize {

    (   my $size,
        \my %original_count,
        my $root_digits,
        \my @all_values,
        my $return,
    ) = _validate(@_);

    ## pad leaves to the longest length, with spaces

    my $leaf_length = u::max( map {length} keys %original_count );

    if ( not( u::looks_like_number($root_digits) ) or $root_digits < 1 ) {
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
            and ( u::sum( @count_of_node{@children_nodes} ) ) >= $size * 2 )
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
                my $partition_count = u::sum( @count_of_node{@partition} );

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

                } ## tidy end: if ( $partition_count ...)

            } ## tidy end: foreach my $last_item_of_partition...

            # got to the end, no partition possible

            last PARTITION;

        } ## tidy end: PARTITION: while ( @children_nodes >=...)

        # if any of the remaining children of node are not leaves,
        # flatten the structure by a level -- make the grandchildren
        # the children -- and reprocess.

        if ( u::any { exists $children_of{$_} } @children_nodes ) {

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

    } ## tidy end: NODE: while (@to_process)

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
        } ## tidy end: if (@all_values)
        my $returnnode;
        if ( $return eq 'runlist' ) {
            $returnnode = $span->run_list;
        }
        else {
            $returnnode = scalar( $span->elements );
            # returns a reference
        }

        $node_of_leaf{$_} = $returnnode foreach @leaves;
    } ## tidy end: foreach my $processed_node ...

    return \%node_of_leaf;

} ## tidy end: sub clusterize

sub _validate {
    my %params = u::validate(
        @_,
        {   size        => { default => 40 },
            root_digits => { type    => $PV_TYPE{SCALAR}, default => 1 },
            count_of    => { type    => $PV_TYPE{HASHREF}, optional => 1 },
            items       => { type    => $PV_TYPE{ARRAYREF}, optional => 1 },
            all_values  => { type    => $PV_TYPE{ARRAYREF}, optional => 1 },
            return => { type => $PV_TYPE{SCALAR}, default => 'runlist' },
        }
    );

    my %count_of;

    if ( exists $params{items} ) {
        croak "Cannot specify both count_of and items"
          if exists $params{count_of};
        \my @items = $params{items};
        croak "No items passed to clusterize" unless @items;
        $count_of{$_}++ foreach (@items);
    }
    elsif ( exists $params{count_of} ) {
        \%count_of = $params{count_of};
        croak "No items passed to clusterize" unless %count_of;
    }
    else {
        croak "Must specify either count_of or items";
    }

    my $all_values_r;
    if ( exists $params{all_values} ) {
        $all_values_r = $params{all_values};
    }
    else {
        $all_values_r = [];
    }

    if ( $params{return} ne 'runlist' and $params{return} ne 'values' ) {
        croak "Unknown return request (must be runlist or values) "
          . $params{return};
    }

    return $params{size}, \%count_of, $params{root_digits}, $all_values_r,
      $params{return};
} ## tidy end: sub _validate

1;

__END__

=encoding utf8

=head1 NAME

Actium::Clusterize - Break lists of bus stops, etc.,  into manageable clusters

=head1 VERSION

This documentation refers to version 0.012

=head1 SYNOPSIS

 use Actium::Clusterize('clusterize');
 
 my $clusters_of_r =  clusterize (
     count_of => { 101 => 5, 102 => 2 }
     );
     
or

 my $clusters_of_r =  clusterize (
     items => [ 101, 101, 101, 101, 101 , 102, 102, 102 ]
     );
     
or

 # either way, $clusters_of_r = { '101,102' => 8 }
 
More usefully:

    my %count_of = (
        101 => 5,
        102 => 4,
        112 => 0,
        113 => 1,
        221 => 5,
        222 => 43,
        233 => 135,
        237 => 45,
        234 => 5,
        235 => 43,
        251 => 67,
        305 => 2,
        441 => 5,
        442 => 8,
        501 => 5,
        502 => 4,
        510 => 73,
        607 => 8,
        701 => 21,
        702 => 21,
        703 => 21,
        704 => 41,
        705 => 21,
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

Actium::Clusterize combines lists of items into reasonably-sized chunks.

The idea is that there are a certain number of items, each one
divided into a category that is an integer.  Maybe there are different
zones of bus stops, where each zone is given a number: zone 101,
zone 102, zone 304, and so on.  If each zone has a significant
number of stops that need work, not much is needed: just make up a
separate work order list for each zone. But what if some zones only
have one or two stops? A separte work order for each stop is overkill. 
This routine combines small zones into larger ones.

The routine assumes that the numbers are hierarchies, and puts together
zones that start with the same numbers.  So, for example, it treats
502 and 5021 as more closely related than 502 and 503, or 5021 and 5120.
This is intentional, as it should make it easier (for example) to add new 
zones in between other zones, without having to rename them.

=head1 SUBROUTINES

=over

=item B<clusterize()>

The B<clusterize> subroutine accepts named parameters. Either C<count_of> or 
C<items> must be specified. The other two parameters, C<root_digits> and 
C<size>, are optional.

=over 

=item C<count_of>

This should be a reference to a hash, where the keys are the zone numbers and
the values are the quantities in each zone.

 my $clusters_of_r = clusterize ( count_of => { 101 => 5, 102 => 2 } );
 
=item C<items>

This should be a reference to an array, each containing a zone number.

 my $clusters_of_r = clusterize ( items => { qw/101 101 101 101 101 102 102/);
     
The B<clusterize> subroutine will convert this into a count. Specify whichever
is easier.

=item C<root_digits> (default: 1)

The B<clusterize> routine does not combine zones that have different roots.
For example, using the default, it will never combine zones beginning
with 1 and zones beginning with 2, even if only one stop begins with 1. 
This parameter allows the number of digits treated as root digits to be specified:

=over

0 -- All items could be combined.

1 -- Items 1000 and 1999 could be combined, but not items 1010 and 2010.

2 -- Items 1010 and 1020 could be combined, but not items 1010 and 1100, or
items 1100 and 2100.

=back

And so forth.

=item C<size> (default: 40)

This is the number of items that's considered the minimum size for a work 
order.  Work zones with a quantity of items smaller than this will be combined
with other work zones (unless those work zones have different roots).

So, for example, 

 my $clusters_of_r = clusterize ( count_of => { 101 => 45, 102 => 42 } );
 
will yield C<{ 101 => 101, 102 = 102 }>, but 
 
 my $clusters_of_r = clusterize ( 
      count_of => { 101 => 45, 102 => 42 } , size => 50);
      
will yield C<{ '101' => '101-102', '102' => '101-102' }>.

=back

The result from B<clusterize> will be a reference to a hash. The keys will be
the original items passed to B<clusterize>. The values will be the new cluster
that they are placed in, expressed as a combination of ranges. So, for example, 
a new cluster might be "101" where a single work zone makes up a cluster,
or "102-103" or even "102-105,107-108,150-151" if that's the result.

=back

=head1 DIAGNOSTICS

=over 

=item *

Invalid root digit specification $root_digits

The root_digit parameter was not a number, or negative

=for removed

=item *

Longest leaf length (...) less than or equal to the number of root digits specified (...)

The root digit specification was so big, and the longest leaf length
so small, that clusterization would be pointless as everything would be 
in its own cluster.

This is no longer valid as now clusters like this just return themselves

=cut

=item * 

Cannot specify both count_of and items

=item *

Must specify either count_of or items

One, and only one, of C<count_of> or C<items> must be specified 
to B<clusterize>. If neither is specified, there's nothing to work on;
if both are specified, it's not clear which should be worked on.

=back

=head1 DEPENDENCIES

=over

=item * 

Actium::Preamble.

=item *

Set::IntSpan.

=back

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

