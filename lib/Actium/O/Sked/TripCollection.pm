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

########################
### SORTING BY STOPTIMES

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

###########################
### TRIPS BY DAY

my $all_are_weekdays_cr = sub {
    my (@days) = shift;
    return u::all {m/\A 1? 2? 3? 4? 5? \z/x} @days;
};

my $compare_range_cr = sub {

    my $compstrs_of_day_r = shift;
    my $callback_cr       = shift;

    my @days = sort keys %$compstrs_of_day_r;

    my ( %already_found_day, %compstrs_of_return_day );

    # Go through list of days. Compare the first one to the subsequent ones.
    # If any of the subsequent ones should be merged with the first day,
    # mark them  as such, and put them as part of the original list.

    foreach my $outer_idx ( 0 .. $#days ) {
        my $outer_day = $days[$outer_idx];
        next if $already_found_day{$outer_day};
        my @found_days = $outer_day;

        my $found_compstrs_r = $compstrs_of_day_r->{$outer_day};

        for my $inner_idx ( $outer_idx + 1 .. $#days ) {
            my $inner_day = $days[$inner_idx];

            next if $already_found_day{$inner_day};

            my $both_are_weekdays
              = $all_are_weekdays_cr->( $outer_day, $inner_day );

            my $inner_compstrs_r = $compstrs_of_day_r->{$inner_day};

            my $merged_compstrs_r = $callback_cr->(
                $found_compstrs_r, $inner_compstrs_r, $both_are_weekdays
            );

            if ($merged_compstrs_r) {
                push @found_days, $inner_day;
                $found_compstrs_r = $merged_compstrs_r;
                $already_found_day{$inner_day} = $outer_day;
            }
        } ## tidy end: for my $inner_idx ( $outer_idx...)

        # so @found_days now has all the days that are identical to
        # the outer day

        @found_days = map { split(//) } @found_days;

        $compstrs_of_return_day{ u::joinempty( sort @found_days ) }
          = $found_compstrs_r;

    } ## tidy end: foreach my $outer_idx ( 0 .....)

    return \%compstrs_of_return_day;

};

my $compstrs_are_identical_cr = sub {
    my ( $found_compstrs_r, $inner_compstrs_r ) = @_;

    my $outer = join( "\t", sort @$found_compstrs_r );
    my $inner = join( "\t", sort @$inner_compstrs_r );
    return $found_compstrs_r if $outer eq $inner;
    return;

};

my $compstrs_should_be_merged_cr = sub {

    my ( $found_compstrs_r, $inner_compstrs_r, $both_are_weekdays ) = @_;
    my $outer_count = scalar @$found_compstrs_r;
    my $inner_count = scalar @$inner_compstrs_r;

    const my $MAX_DIFFERING_TIMES      => 10;
    const my $MINIMUM_TIMES_MULTIPLIER => 4;
    const my $WKDY_ALWAYS_MERGE_BELOW  => 11;

    my $compare = List::Compare->new(
        {   lists    => [ $found_compstrs_r, $inner_compstrs_r ],
            unsorted => 1,
        }
    );

    my $only_in_either = scalar( $compare->get_symmetric_difference );
    my $in_both        = scalar( $compare->get_intersection );

    return $compare->get_union_ref
      if $both_are_weekdays
      and $outer_count + $inner_count < $WKDY_ALWAYS_MERGE_BELOW;

    return $compare->get_union_ref
      if $both_are_weekdays
      and ( $only_in_either <= $MAX_DIFFERING_TIMES );

    return $compare->get_union_ref
      if $only_in_either <= $MAX_DIFFERING_TIMES
      and $in_both > ( $MINIMUM_TIMES_MULTIPLIER * $only_in_either );

    return;    # else no merging

};

# First, go through days, and combine any *completely* identical
# sets. Then, go through days, and decide whether to combine
# close-to-identical sets.
#
# Doing it in two passes will, I think, avoid some issues where
# we have different behavior depending on when in the comparison
# the exception happens (e.g., if Wacky Wednesday compares after
# rather than before normal days).

sub trips_by_day {
    my $self  = shift;
    my $class = u::blessed $self;
    my @trips = $self->trips;

    # compstr = stoptimes_comparison_str

    my $compstrs_of_day_r;

    foreach my $trip (@trips) {
        my $compstr = $trip->stoptimes_comparison_str;
        my @days = split( //s, $trip->daycode );
        foreach my $day (@days) {
            push @{ $compstrs_of_day_r->{$day} }, $compstr;
        }
    }

    $compstrs_of_day_r
      = $compare_range_cr->( $compstrs_of_day_r, $compstrs_are_identical_cr )
      if ( scalar keys %$compstrs_of_day_r ) > 1;

    $compstrs_of_day_r
      = $compare_range_cr->( $compstrs_of_day_r, $compstrs_should_be_merged_cr )
      if ( scalar keys %$compstrs_of_day_r ) > 1;

    my (%tripcollection_of);

    for my $skedday ( keys %$compstrs_of_day_r ) {

        my @trips_of_this_skedday;

        for my $trip (@trips) {

            my $sked_day_obj = Actium::O::Days->instance( $skedday, 'B' );
            my $trip_day_obj = $trip->days_obj;

            if (   $skedday eq $trip_day_obj->daycode
                or $sked_day_obj->is_a_superset_of($trip_day_obj) )
            {

                push @trips_of_this_skedday, $trip;
            }
            else {
                my $isect_obj = $sked_day_obj->intersection($trip_day_obj);
                if ($isect_obj) {
                    push @trips_of_this_skedday,
                      $trip->clone( days => $isect_obj );
                }
            }
        }

        $tripcollection_of{$skedday}
          = $class->new( trips_r => \@trips_of_this_skedday );
        $tripcollection_of{$skedday}->_merge;

    } ## tidy end: for my $skedday ( keys ...)

    return \%tripcollection_of;

} ## tidy end: sub trips_by_day

sub _merge {

    my $self           = shift;
    my $trips_r        = $self->trips_r;
    my $merged_trips_r = $self->_merge_trips($trips_r);
    $self->_set_trips_r($merged_trips_r);
    return;

}

sub _merge_trips {
    my $self = shift;

    my @trips_rs = @_;

    my @trips = $self->stoptime_sort( map {@$_} @trips_rs )->@*;

    my @methods  = ('stoptimes_comparison_str');
    my @newtrips = shift @trips;

  TRIP_TO_MERGE:
    while (@trips) {
        my $thistrip = shift @trips;
        my $prevtrip = $newtrips[-1];

        next if ( $thistrip == $prevtrip );
        # skip this trip if it's the same object as the previous trip

        foreach my $this_test (@methods) {
            if ( $thistrip->$this_test ne $prevtrip->$this_test ) {
                push @newtrips, $thistrip;
                next TRIP_TO_MERGE;
            }
        }
        # so now we know they are the same

        $newtrips[-1] = $prevtrip->merge_pair($thistrip);

    }

    return \@newtrips;

} ## tidy end: sub _merge_trips

u::immut;

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

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
