package Actium::O::Sked::TripCollection 0.012;

use Actium::Moose;
use List::Compare;

has 'trips_r' => (
    traits   => ['Array'],
    is       => 'ro',
    writer   => '_set_trips_r',
    isa      => 'ArrayRef[Actium::O::Sked::Trip]',
    required => 1,
    handles  => { trips => 'elements', trip => 'get', trip_count => 'count' },
);

sub BUILD {
    my $self = shift;
    $self->_sort_by_stoptimes;
}

my $all_are_weekdays_cr = sub {

    my (@days) = shift;
    return u::all {m/\A 1? 2? 3? 4? 5? \z/x} @days;

};

sub trips_by_day {
    my $self  = shift;
    my $class = u::blessed $self;
    my @trips = $self->trips;

    my %trips_of_day;

    foreach my $trip ( $self->trips ) {
        my @days = split( //s, $trip->daycode );
        foreach my $day (@days) {
            push @{ $trips_of_day{$day} }, $trip;
        }
    }

    my @days = sort keys %trips_of_day;
    my ( %already_found_day, %trips_of_skedday );

    # Go through list of days. Compare the first one to the subsequent ones.
    # If any of the subsequent ones are identical to the first day, mark them
    # as such, and put them as part of the original list.

    foreach my $outer_idx ( 0 .. $#days ) {
        my $outer_day = $days[$outer_idx];
        next if $already_found_day{$outer_day};
        my @found_days = $outer_day;

        my $found_trips_r = $trips_of_day{$outer_day};

        for my $inner_idx ( $outer_idx + 1 .. $#days ) {
            my $inner_day = $days[$inner_idx];

            next if $already_found_day{$inner_day};

            my $both_are_weekdays
              = $all_are_weekdays_cr->( $outer_day, $inner_day );

            my $inner_trips_r = $trips_of_day{$inner_day};

            if (my $merged_trips_r = $self->_merge_if_appropriate(
                    $found_trips_r, $inner_trips_r, $both_are_weekdays
                )
              )
            {
                push @found_days, $inner_day;
                $found_trips_r = $merged_trips_r;
                $already_found_day{$inner_day} = $outer_day;
            }
        } ## tidy end: for my $inner_idx ( $outer_idx...)

        # so @found_days now has all the days that are identical to
        # the outer day

        my $skedday = u::joinempty(@found_days);
        $trips_of_skedday{$skedday} = $found_trips_r;

    } ## tidy end: foreach my $outer_idx ( 0 .....)

    my %tripcollection_of;

    for my $skedday ( keys %trips_of_skedday ) {

        $tripcollection_of{$skedday}
          = $class->new( trips_r => $trips_of_skedday{$skedday} );

    }

    return \%tripcollection_of;

} ## tidy end: sub trips_by_day

sub _merge_if_appropriate {
    my $self = shift;
    const my $MAX_DIFFERING_TIMES      => 5;
    const my $MINIMUM_TIMES_MULTIPLIER => 5;
    const my $MAX_WEEKDAY_MERGE        => 10;

    my ( $outer_trips_r, $inner_trips_r, $both_are_weekdays ) = @_;

    my $outer_count = scalar @{$outer_trips_r};
    my $inner_count = scalar @{$inner_trips_r};

    # Are the quantities so different that there's no point comparing them?

    my $difference = abs( $outer_count - $inner_count );

    return if $difference > $MAX_DIFFERING_TIMES;

    # check to see if all the trips themselves are the same object.
    # This will frequently be the case

    return $outer_trips_r
      if ( not $difference
        and $self->_trips_are_identical( $outer_trips_r, $inner_trips_r ) );

    ## now check if times are the same even if trips are not
    ## identical (as with Saturday/Sunday). First, make lists of times

    my @outer_times = map { $_->stoptimes_comparison_str } @{$outer_trips_r};
    my @inner_times = map { $_->stoptimes_comparison_str } @{$inner_trips_r};

    # Then compare them using List::Compare

    my $compare = List::Compare->new(
        {   lists    => [ \@outer_times, \@inner_times ],
            unsorted => 1,
        }
    );

    my $only_in_either = scalar( $compare->get_symmetric_difference );
    # if all the trips have identical times, then merge them

    if ( not $only_in_either ) {
        return [
            map { $outer_trips_r->[$_]->merge_trips( $inner_trips_r->[$_] ) }
              ( 0 .. $#outer_times )
        ];

    }
    ### DEBGUG ###
    # Will only merge schedules with identical times
    
    #### SOMETHING AFTER THIS IS NOT WORKING PROPERLY ###

    return;

    # if they are *almost* identical -- that is, 5 or fewer differing
    # times, and the number of times is at least 5 times the number of
    # differing ones, then merge them

    # or, if they're weekdays,  (e.g., school trips), merge them unless
    # they're very different

    # In weird situations where, for example, you have several different sets --
    # -- 30 trips that are every day, plus two separate ones on Monday,
    # two separate ones on Tuesday, two separate ones on Wednesday,
    # etc. -- this will give inconsistent results, with Monday's
    # and Tuesday's trips combined but Wednesday's not.
    # To do that you'd need to compare them all to each other simultaneously,
    # which code I am not prepared to write at this point.

    my $in_both = scalar( $compare->get_intersection );

    last_cry()->text( 'pre_mis:', $outer_trips_r->[0]->line );

    return $self->_merge_trips_if_same( $outer_trips_r, $inner_trips_r )
      if $both_are_weekdays
      and $outer_count + $inner_count <= $MAX_WEEKDAY_MERGE;

    return $self->_merge_trips_if_same( $outer_trips_r, $inner_trips_r )
      if $both_are_weekdays
      and ( u::min( $outer_count, $inner_count ) < $MAX_DIFFERING_TIMES );

    return $self->_merge_trips_if_same( $outer_trips_r, $inner_trips_r )
      if $only_in_either <= $MAX_DIFFERING_TIMES
      and $in_both > ( $MINIMUM_TIMES_MULTIPLIER * $only_in_either );
    # no merging

    return;

} ## tidy end: sub _merge_if_appropriate

sub _merge_trips_if_same {
    my $self = shift;

    my @trips_rs = @_;

    my @trips = $self->stoptime_sort( map {@$_} @trips_rs )->@*;

    last_cry()->text( 'mis', $trips[0]->line );
    my @methods  = ('stoptimes_comparison_str');
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

} ## tidy end: sub _merge_trips_if_same

sub _trips_are_identical {
    my $self          = shift;
    my $outer_trips_r = shift;
    my $inner_trips_r = shift;

    for my $i ( 0 .. $#{$outer_trips_r} ) {
        return unless $outer_trips_r->[$i] == $inner_trips_r->[$i];
    }

    return 1;

}

my $common_stop_cr = sub {
    # returns undef if there's no stop in common, or
    # the stop to sort by if there is one

    my @trips = @_;
    my $common_stop;
    my $last_to_search
      = ( u::min( map { $_->stoptime_count } @trips ) ) - 1;

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
    my $self  = shift;
    my @trips = $self->trips;

    my $sorted_r = $self->stoptime_sort(@trips);

    $self->_set_trips_r($sorted_r);
    return;

}

sub stoptime_sort {

    my $invocant = shift;
    my @trips    = @_;

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

    return \@trips;
} ## tidy end: sub stoptime_sort

u::immut;

1;
