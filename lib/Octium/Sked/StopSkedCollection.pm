package Octium::Sked::StopSkedCollection 0.015;
# vimcolor: #00261C

use Actium 'class';
use Actium::Types('Folder');
use Types::Common::Numeric('PositiveOrZeroInt');
use List::MoreUtils('nsort_by');
use List::Compare;

has _stopskeds_r => (
    traits   => ['Array'],
    is       => 'bare',
    init_arg => 'stopskeds',
    isa      => 'ArrayRef[Octium::Sked::StopSked]',
    required => 1,
    handles  => { stopskeds => 'elements', },
);

has _stopids_display => (
    init_arg => undef,
    is       => 'ro',
    lazy     => 1,
    builder  => 1,
);

method _build_stopids_display {
    my @stopids = Actium::uniq( sort map { $_->stopid } $self->stopskeds );
    return join( '.', @stopids );
}

method store_dumped (Folder $folder does coerce) {
    my $stopids = $self->_stopids_display;
    # there may be more than one collection with the same stop IDs in which
    # case this will write over one of them
    env->crier->over($stopids);
    my $file = $folder->file( $stopids . '.dump' );
    local $Data::Dumper::Indent = 1;
    $file->spew_text( $self->dump );
    return;
}

method store_bundled (Folder $folder does coerce) {
    my $stopids = $self->_stopids_display;
    env->crier->over($stopids);
    my $file = $folder->file( $stopids . '.json' );
    require JSON;
    $file->spew_text( JSON->new->pretty->canonical->encode( $self->bundle ) );
}

method bundle {
    return [ map { $_->bundle } $self->stopskeds ];
}

##### COMBINE SIMILAR SCHEDULES #####

func _combine_skeds_with_same_ensuing_stops ( :$threshold , :\@stopskeds) {
    return @stopskeds if @stopskeds == 1;
    my $ss_class = Actium::blessed( $stopskeds[0] );

    # groups, here, refers to groups of schedules that
    # share a set of ensuing stops
    my ( %is_in_group, %ensuing_min, @groups_quantity );

    # go through each stopsked
  STOPSKED:
    foreach my $ss_idx ( 0 .. $#stopskeds ) {
        my $stopsked = $stopskeds[$ss_idx];

        \my %num_trips = $stopsked->ensuing_count($threshold);
        #     %num_trips : ensuing string as keys
        #     and the quantity of trips in this stopsked as value
        #     It is used for determining the %ensuing_min

        # go through each set of ensuing stops of this stopsked
        foreach my $ensuing_str ( keys %num_trips ) {

            if ( not exists $ensuing_min{$ensuing_str}
                or $num_trips{$ensuing_str} < $ensuing_min{$ensuing_str} )
            {
                $ensuing_min{$ensuing_str} = $num_trips{$ensuing_str};
            }

            # across all schedules of this day, keep track of the shortest
            #    schedule with these ensuing stops
            # the idea is that if we have schedules  with the following:
            #    [ ensuing_a ] [ ensuing_b ] [ensuing_a , ensuing_b ],
            #    where we can combine one of [ ensuing_a ] or
            #    [ ensuing_b ] with [ensuing_a, ensuing_b ] but not both,
            #    then choose the one with the *least* trips in it.

            $is_in_group{$ensuing_str}{$ss_idx} = 1;
            # $is_in_group{$ensuing}{$ss_idx} is 1 if the
            # ensuing_str is associated with that stopsked

            $groups_quantity[$ss_idx]++;
            # @groups_quantity is the number of groups of ensuing stops
            # each schedule is in -- in other words, how many different sets
            # of ensuing stops are used
        }

    }

    # then see if they have the same ensuing stops
    #
    # To be combined:
    #
    # 1) they must have ensuingstops in common
    #
    # 2) no schedule should have a *different* set of ensuingstops in
    #    common with a different schedule.

    # so, what this does is first, delete all single-entry groups, so that when
    # groups_quantity says a sked falls into two groups, we know it's really a
    # conflict.
  ENSURING_SINGLE_ENTRY:
    for my $ensuing_str ( keys %is_in_group ) {
        my @stopsked_idxs = keys $is_in_group{$ensuing_str}->%*;
        if ( @stopsked_idxs == 1 ) {
            delete $is_in_group{$ensuing_str};
            $groups_quantity[ $stopsked_idxs[0] ]--;
        }
    }

    # now we know any remaining groups are potential candidates for merging.
    # But they may have schedules to combine more than once, which isn't okay

    # go through remaining ensuing groups, from the one with the largest
    # minimum length to the to smallest.
    my ( @combined, @has_combined );
  ENSURING_COMBINE:
    for my $ensuing_str ( reverse sort { $ensuing_min{$a} <=> $ensuing_min{$b} }
        ( keys %is_in_group ) )
    {

        # if this sked is in several ensuing sets, delete this one, leaving
        # later ones.
        for ( keys $is_in_group{$ensuing_str}->%* ) {
            if ( $groups_quantity[$_] > 1 ) {
                delete $is_in_group{$ensuing_str}{$_};
                $groups_quantity[$_]--;
            }
        }

        # now we know any remaining skeds in this group are only in this group.
        # if there's more than one in the group, it should be combined
        my @stopsked_idxs = keys $is_in_group{$ensuing_str}->%*;
        next ENSURING_COMBINE unless @stopsked_idxs > 1;

        # combine the skeds
        push @combined, $ss_class->combine( @stopskeds[@stopsked_idxs] );

        # mark stopskeds that have been combined
        $has_combined[$_] = 1 foreach @stopsked_idxs;

    }

    my @non_combined_idxs = grep { !$has_combined[$_] } ( 0 .. $#stopskeds );
    return ( @combined, @stopskeds[@non_combined_idxs] );

}

func _fraction_different ($left_sked, $right_sked) {
    my $comparator = List::Compare->new(
        {   lists => [
                [ $left_sked->merge_comparison_strings ],
                [ $right_sked->merge_comparison_strings ]
            ],
            unsorted => 1,
        }
    );
    my $num_same      = scalar( $comparator->intersection );
    my $num_different = scalar( $comparator->symdiff );
    return $num_different / ( $num_same + $num_different );
}

func _merge_skeds_varying_only_by_days (
     :\@stopskeds, Num :$difference_fraction
     ) {

    my $ss_class = Actium::blessed( $stopskeds[0] );

    my @to_return;
    my @queue = reverse nsort_by { $_->days->as_sortable } @stopskeds;

  OUTER:
    while ( @queue > 1 ) {
        my $left = shift @queue;
        my @failed;

      INNER:
        while (@queue) {
            my $right = shift @queue;

            if ( _fraction_different( $left, $right ) < $difference_fraction ) {
                my $merged = $ss_class->merge( $left, $right );
                if ( not defined $merged ) {
                    push @failed, $right;
                    next INNER;
                }
                unshift @queue, $merged, @failed;
                next OUTER;
            }
            else {
                push @failed, $right;
            }
        }
        # no merger happened
        push @to_return, $left;
        unshift @queue, @failed;
    }

    return ( @to_return, @queue );

}

method combined (PositiveOrZeroInt $threshold , Num :$difference_fraction) {
    # Create a new collection, with new schedules.
    #
    # * First, combine schedules of different lines, of the same days, with the
    # same ensuing stops.  Put all the trips together in the sames schedule,
    # but no de-duplication.)
    #
    # * Then, merge schedules with the same days and mostly identical trips,
    # merging the trips so that there are not duplicates.

    my %stopskeds_of;
    foreach my $stopsked ( $self->stopskeds ) {
        my $key = join( " ", $stopsked->stopid, $stopsked->days->as_string );
        push $stopskeds_of{$key}->@*, $stopsked;
    }

    my @combined = map {
        _combine_skeds_with_same_ensuing_stops(
            threshold => $threshold,
            stopskeds => $stopskeds_of{$_}
        )
    } keys %stopskeds_of;

    @combined = _merge_skeds_varying_only_by_days(
        difference_fraction => $difference_fraction,
        stopskeds           => \@combined
    ) unless @combined == 1;

    my $class = Actium::blessed $self;
    return $class->new( stopskeds => \@combined );

}

### CLASS METHODS

method sorted (Str $class: Octium::Sked::StopSkedCollection @collections ) {
    @collections = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->_stopids_display ] } @collections;
    return @collections;
}

method unbundle ($class: ArrayRef $bundle ) {
    my $stopskeds_r = map { $_->unbundle } $bundle->@*;
    return $class->new( stopskeds => $stopskeds_r );
}

# don't need these now, but I might later

#method _build_stopskeds_of_stopid_r {
#    my %stopskeds_of_stopid;
#    foreach my $stopsked ( $self->stopskeds ) {
#        my $stopid = $stopsked->stopid;
#        push $stopskeds_of_stopid{$stopid}->@*, $stopsked;
#    }
#    return \%stopskeds_of_stopid;
#}
#
#has _stopskeds_of_stopid_r => (
#    lazy    => 1,
#    builder => 1,
#    traits  => ['Hash'],
#    is      => 'bare',
#    isa     => 'HashRef[ArrayRef[Octium::Sked::StopSked]]',
#    handles => {
#        _stopids                  => 'keys',
#        _has_stopskeds_of_stopid => 'exists',
#        _stopskeds_of_stopid_r   => 'get',
#    },
#);
#
#has _first_stopid => (
#    lazy     => 1,
#    builder  => 1,
#    is       => 'ro',
#    init_arg => undef,
#);

#method _build_first_stopid {
#    my @sorted = sort $self->_stopids;
#    return $sorted[0];
#}

#method stopskeds_of_stopid (Str $stopid) {
#    return () if not $self->_has_stopskeds_of_stopid;
#    return $self->_stopskeds_of_stopid_r($stopid)->@*;
#}

1;

__END__

=encoding utf8

=head1 NAME

Octium::Sked::StopSkedCollection -  Object representing schedule info
for a particular bus stop or group of bus stops

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use Octium::Sked::StopSkedCollection;
 # do something with Octium::Sked::StopSkedCollection

=head1 DESCRIPTION

This represents schedule information for a particular bus stop, or
group of bus stops.

WHen created from the C<stopskeds> method in
L<Octium::Sked::StopSkedMaker|Octium::Sked::StopSkedMaker> which is
applied to L<Octium::Sked|Octium::Sked>, it will have one collection
per stop, and so some of the write-to-disk methods assume this.
However, this is not necessarily true when used in other contexts.

=head1 CLASS METHODS

=head2 new(...)

The module inherits its constructor from Moose.

=head2 sorted($object, $object, ...)

This routine takes a list of stop schedule collections and returns them
sorted in an way that makes sense for presentation. (At the moment,
sorted by stop IDs. This could change.)

=head2 unbundle($string)

The C<unbundle> method takes a structure created by the C<bundle>
method and returns a recreated object.

=head1 ATTRIBUTE

=head2 stopskeds

An array of L<Octium::Sked::StopSked|Octium::Sked::StopSked> objects. 
The "stopskeds" argument in the constructor should be a reference to
the array, while the stopskeds() method will return the list.

=head1 OBJECT METHODS

=begin comment

=head2 _stopids

Returns a list of the stop IDs associated with the stop schedules.

=head2 stopskeds_of_stopid($stopid)

Takes a stop ID and returns the associated StopSked objects of that
stop ID.

=end comment

=head2 bundle

This returns a struct which, when passed to the C<unbundle> class
method, will recreate the object.

=head2 store_bundled ($folder), store_dumped($folder)

These take an L<Actium::Storage::Folder|Actium::Storage::Folder> object
(or anything that can be coerced into it, including a string path, see
L<Actium::Types|Actium::Types>) and stores data representing the object
into a file.

The C<store_bundle> method stores the struct returned by C<bundle> in a
JSON file.  The C<store_dumped> stores a dump of the object (created
from Moose's C<dump> described in L<Moose::Object|Moose::Object>.

In either case, the file name is taken from the stop ID or IDs of the
associated stop schedules, which means that if more than one collection
has the same stop IDs, the last bundle will overwrite the earlier ones.

=head1 DIAGNOSTICS

None specific to this class.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

The Actium system.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2020

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * 

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item * 

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

