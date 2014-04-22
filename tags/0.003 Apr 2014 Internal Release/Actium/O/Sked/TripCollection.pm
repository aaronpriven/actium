# Actium/Sked/TripCollection.pm

# Trip collection object (for schedules)

# Subversion: $Id$

# legacy status 4

package Actium::O::Sked::TripCollection;

# This is a collection of trips. It is convenient to have a collection of trips
# object (separate from the Sked object) for two reasons. First, the collection
# can be immutable even if the trips inside it, and the schedule, are mutable,
# so we can store things like the routes of all trips in it even if the trips
# themselves may change.  Second, it allows what had been class methods 
# working on groups of trips to be object methods on the collection object.

###  NOT IMPLEMENTED OR WORKING -- STILL JUST AN IDEA THAT IS NOT YET BEING
###  USED

...;

use 5.014;
use Moose;

use namespace::autoclean;

use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has 'trip_r' => (
    traits  => ['Array'],
    is      => 'ro',
    writer => '_set_trip_r',
    isa     => 'ArrayRef[Actium::O::Sked::Trip]',
    required => 1,
    handles => { trips => 'elements', trip => 'get', trip_count => 'count' },
);

sub BUILD {
 my $self = shift;
    $self->_sort_by_stoptimes;
    $self->_merge_if_same
 
 
 
}

my $common_stop_cr = sub {

    # returns undef if there's no stop in common, or
    # the stop to sort by if there is one

    my @trips = @_;
    my $common_stop;
    my $last_to_search
      = ( List::Util::min( map { $_->stoptime_count } @trips ) ) - 1;

  SORTBY_STOP:
    for my $stop ( 0 .. $last_to_search ) {
      SORTBY_TRIP:
        for my $trip (@trips) {
            next SORTBY_STOP if not defined $trip->stoptime($stop);
        }
        $common_stop = $stop;
        last SORTBY_STOP;
    }

    return $common_stop;

};

sub _sort_by_stoptimes {
    # TODO - generalize to sort by placetimes or stoptimes

    my $self = shift;
    my @trips = $self->trips;

    my $common_stop = $common_stop_cr->(@trips);

    if ( defined $common_stop ) {

        # sort trips with a common stop
        
        my @cache = map {
            [   $_->stoptime($common_stop),    # 0
                $_->average_stoptime,          # 1
                $_,                            # 2
            ]
          } @trips; 
          
        @cache = sort {
                 $a->[0] <=> $b->[0]
              or $a->[1] <=> $b->[1]
              or $a->[2]->sortable_days cmp $b->[2]->sortable_days
          } @cache;
          
        @trips = map { $_->[2] } @cache;
          

        # a schwartzian transform with two criteria --
        # either the common stop, or if those times are the same,
        # the average.
        # if both of those tie, use sortable_days (not put into the
        # cache because will be used very very rarely)

    } ## tidy end: if ( defined $common_stop)
    else {
        # sort trips without a common stop for all of them

        @trips = sort {

            my $common = $common_stop_cr->( $a, $b );

            defined $common
              ? ( $a->stoptime($common) <=> $b->stoptime($common)
                  or $a->average_stoptime <=> $b->average_stoptime
                  or $a->sortable_days cmp $b->sortable_days )
              : $a->average_stoptime <=> $b->average_stoptime
              or $a->sortable_days cmp $b->sortable_days;

            # if these two trips have a common stop, sort first
            # on those common times, and then by the average.

            # if they don't, just sort by the average.

        } @trips;

    } ## tidy end: else [ if ( defined $common_stop)]

    $self->_set_trip_r(\@trips);

} ## tidy end: sub stoptimes_sort

sub merge_trips_if_same {
    my $class  = shift;
    my %params = %{ +shift };

    my @trips   = @{ $params{trips} };
    my @methods = @{ $params{methods_to_compare} };

    my @newtrips = shift @trips;

  TRIP_TO_MERGE:
    while (@trips) {
        my $thistrip = shift @trips;
        my $prevtrip = $newtrips[-1];

        foreach my $this_test (@methods) {
            if ( $thistrip->$this_test ne $prevtrip->$this_test ) {
                push @newtrips, $thistrip;
                next TRIP_TO_MERGE;
            }
        }
        # so now we know they are the same

        $newtrips[-1] = $prevtrip->merge_trips($thistrip);

    }

    return \@newtrips;

} ## tidy end: sub merge_trips_if_same

__PACKAGE__->meta->make_immutable; ## no critic (RequireExplicitInclusion)

1;
