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
    trigger  => &_sort_by_stoptimes,
);

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

    \my %trips_of_skedday = $self->_assemble_skeddays( \%trips_of_day );

    my %tripcollection_of;

    for my $skedday ( keys %trips_of_skedday ) {

        $tripcollection_of{$skedday}
          = $class->new( trips_r => $trips_of_skedday{$skedday} );

    }

    return \%tripcollection_of;

} ## tidy end: sub trips_by_day

sub _assemble_skeddays {
    my $self           = shift;
    my $trips_of_day_r = shift;
    my @days           = sort keys %{$trips_of_day_r};
    my ( %already_found_day, %trips_of_skedday );

    # Go through list of days. Compare the first one to the subsequent ones.
    # If any of the subsequent ones are identical to the first day, mark them
    # as such, and put them as part of the original list.

    foreach my $i ( 0 .. $#days ) {
        my $outer_day = $days[$i];
        next if $already_found_day{$outer_day};
        my @found_days = $outer_day;

        my $found_trips_r = $trips_of_day_r->{$outer_day};

        for my $j ( $i + 1 .. $#days ) {
            my $inner_day = $days[$j];
            next if $already_found_day{$inner_day};

            my $inner_trips_r = $trips_of_day_r->{$inner_day};

            if ( my $merged_trips_r
                = $self->_merge_if_appropriate( $found_trips_r, $inner_trips_r )
              )
            {
                push @found_days, $inner_day;
                $found_trips_r = $merged_trips_r;
                $already_found_day{$inner_day} = $outer_day;
            }
        }

        # so @found_days now has all the days that are identical to
        # the outer day

        my $skedday = u::joinempty(@found_days);
        $trips_of_skedday{$skedday} = $found_trips_r;

    } ## tidy end: foreach my $i ( 0 .. $#days)

    return \%trips_of_skedday;

} ## tidy end: sub _assemble_skeddays

const my $MAXIMUM_DIFFERING_TIMES  => 4;
const my $MINIMUM_TIMES_MULTIPLIER => 5;

sub _merge_if_appropriate {
    my $self = shift;

    my $outer_trips_r = shift;
    my $inner_trips_r = shift;

    my $outer_count = scalar @{$outer_trips_r};
    my $inner_count = scalar @{$inner_trips_r};

    # Are the quantities so different that there's no point comparing them?

    my $difference = abs( $outer_count - $inner_count );

    return if $difference > $MAXIMUM_DIFFERING_TIMES;

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
        {   lists       => [ \@outer_times, \@inner_times ],
            unsorted    => 1,
            accelerated => 1,
        }
    );

    my $only_in_either = scalar( $compare->get_symmetric_difference );

    # if all the trips have identical times, then merge them

    if ( not $only_in_either ) {

        my @merged_trips;
        for my $i ( 0 .. $#outer_times ) {

            push @merged_trips,
              $outer_trips_r->[$i]->merge_trips( $inner_trips_r->[$i] );

        }

        return \@merged_trips;

    }

    # if they are *almost* identical -- that is, 4 or fewer differing
    # times, and the number of times is at least 5 times the number of
    # differing ones, then merge them

    # (the 5 times bit was commented out for wacky wednesday reasons)

    # In weird situations where, for example, you have several different sets --
    # -- 30 trips that are every day, plus two separate ones on Monday,
    # two separate ones on Tuesday, two separate ones on Wednesday,
    # etc. -- this will give inconsistent results, with Monday's
    # and Tuesday's trips combined but Wednesday's not.
    # To do that you'd need to compare them all to each other simultaneously,
    # which code I am not prepared to write at this point.

    my $in_both = ( u::max( $inner_count, $outer_count ) ) - $only_in_either;

    if ($only_in_either <= $MAXIMUM_DIFFERING_TIMES
        #        and $in_both > ( $MINIMUM_TIMES_MULTIPLIER * $only_in_either )
      )
    {
        my $trips_to_merge_r
          = Actium::O::Sked::Trip->stoptimes_sort( @{$outer_trips_r},
            @{$inner_trips_r} );

        return Actium::O::Sked::Trip->merge_trips_if_same(
            {   trips              => $trips_to_merge_r,
                methods_to_compare => ['stoptimes_comparison_str'],
            }
        );

    }

    # no merging

    return;

} ## tidy end: sub _merge_if_appropriate

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

    my $self  = shift;
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

    $self->_set_trip_r( \@trips );

} ## tidy end: sub _sort_by_stoptimes

u::immut;

1;
