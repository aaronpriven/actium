# /Actium/Files/Thea/Trips.pm

# The part of the theaImport routine that reads the trips files

# Subversion: $Id$

# Legacy status: 4 (still in progress...)

use 5.014;
use warnings;

package Actium::Files::Thea::Trips 0.002;

use Actium::Term;
use Actium::Constants;
use Actium::Sked::Days;
use Actium::Time('timenum');
use Actium::Sked::Trip;
use Actium::Util ('j');
use Actium::Files::TabDelimited 'read_tab_files';
use Actium::Sorting::Line 'sortbyline';

use List::Util('max');
use List::MoreUtils ('uniq');
use List::Compare;
use Const::Fast;

use Sub::Exporter -setup => { exports => ['thea_trips'] };

## no critic (ProhibitConstantPragma)
use constant {
    T_DAYS           => 0,
    T_VEHICLE        => 1,
    T_TIMES          => 2,
    T_DAYSEXCEPTIONS => 3,
    T_PATTERN        => 4,
    T_LINE           => 5,
    T_TYPE           => 6,
    T_INTNUM         => 7,
};
## use critic

sub thea_trips {

    emit "Loading THEA trips into trip objects";

    my $theafolder               = shift;
    my $pat_lineids_of_lgdir_r = shift;
    my $uindex_of_r              = shift;

    my $tripstructs_of_lineid_r = _load_trips_from_file($theafolder);

    my $trips_of_lgdir_r
      = _make_trip_objs( $pat_lineids_of_lgdir_r, $tripstructs_of_lineid_r,
        $uindex_of_r );

    my $trips_of_sked_r = _get_trips_of_sked($trips_of_lgdir_r);

    emit_done;

    return $trips_of_sked_r;

} ## tidy end: sub thea_trips

my %required_headers = (
    trips => [
        qw<trp_int_number trp_route trp_pattern trp_is_in_service
          trp_blkng_day_digits trp_event>
    ],
    tripstops => [qw<trp_int_number tstp_position tstp_passing_time>],
);

sub _load_trips_from_file {
    my $theafolder = shift;
    emit 'Reading THEA trip files';

    my %trip_of_tnum;
    my %tnums_of_lineid;

    my $trip_callback = sub {
        my $value_of_r = shift;

        return unless $value_of_r->{trp_is_in_service};
        #        return unless $is_a_valid_trip_type{ $value_of_r->{trp_type} };
        my $tnum = $value_of_r->{trp_int_number};

        my $line    = $value_of_r->{trp_route};
        my $pattern = $value_of_r->{trp_pattern};

        my $lineid = $line . '_' . $pattern;

        push @{ $tnums_of_lineid{$lineid} }, $tnum;

        my $vehicle = $value_of_r->{trp_veh_groups};
        $trip_of_tnum{$tnum}[T_VEHICLE] = $vehicle if $vehicle;

        my $event = $value_of_r->{trp_event};

        my $daydigits = $value_of_r->{trp_blkng_day_digits};

        if ( $daydigits =~ s/0/7/sg ) {
            $daydigits = j( sort split( //s, $daydigits ) );
        }

        my $days_obj = _make_days_obj( $daydigits, $event );

        $trip_of_tnum{$tnum}[T_DAYSEXCEPTIONS] = $event;

        $trip_of_tnum{$tnum}[T_PATTERN] = $pattern;
        $trip_of_tnum{$tnum}[T_LINE]    = $line;
        $trip_of_tnum{$tnum}[T_TYPE]    = $value_of_r->{trp_type};
        $trip_of_tnum{$tnum}[T_DAYS]    = $days_obj;
        $trip_of_tnum{$tnum}[T_INTNUM]  = $tnum;

    };

    read_tab_files(
        {   globpatterns     => ['*trips.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trips'},
            callback         => $trip_callback,
        }
    );

    emit_done;

    emit 'Reading THEA trip stop (time) files';

    my $tripstops_callback = sub {
        my $value_of_r = shift;
        my $tnum       = $value_of_r->{trp_int_number};

        return unless exists $trip_of_tnum{$tnum};

        $trip_of_tnum{$tnum}[T_TIMES][ $value_of_r->{tstp_position} - 1 ]
          = $value_of_r->{tstp_passing_time};

    };

    read_tab_files(
        {   globpatterns     => ['*tripstops.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'tripstops'},
            callback         => $tripstops_callback,
        }
    );

    emit_done;

    my %trips_of_lineid;
    foreach my $lineid ( keys %tnums_of_lineid ) {
        foreach my $tnum ( @{ $tnums_of_lineid{$lineid} } ) {
            push @{ $trips_of_lineid{$lineid} }, $trip_of_tnum{$tnum};
        }
    }

    return \%trips_of_lineid;

} ## tidy end: sub _load_trips_from_file

sub _make_days_obj {

    my $day_digits = shift;
    my $trp_event  = shift;

    $day_digits =~ s/0/7H/s;
    # Thea uses 0 instead of 7 for Sunday, as Hastus Standard AVL did.
    $day_digits = j( sort ( split( //s, $day_digits ) ) );
    # sort $theaday by characters - putting 7 at end

    my $schooldaycode
      = $trp_event eq 'SD' ? 'D'
      : $trp_event eq 'SH' ? 'H'
      :                      'B';

    return Actium::Sked::Days->new( $day_digits, $schooldaycode );
}

sub _make_trip_objs {
    my $pat_lineids_of_lgdir_r = shift;
    my $trips_of_lineid_r        = shift;
    my $uindex_of_r              = shift;

    my %trips_of_lgdir;

    # so the idea here is to go through each trip, and create a new
    # trip struct in trips_of_lgdir that has the various information,
    # putting the times in the correct column as in uindex_of_r.

    # Then we turn them into objects, and sort the objects.

    emit 'Making Trip objects (padding out columns, merging double trips)';

    foreach my $lgdir ( sortbyline keys $pat_lineids_of_lgdir_r ) {

        emit_over $lgdir;

        my $trip_objs_r;
        my @lineids = @{ $pat_lineids_of_lgdir_r->{$lgdir} };

        foreach my $lineid (@lineids) {
         
            foreach my $trip_r ( @{ $trips_of_lineid_r->{$lineid} } ) {

                my $unified_trip_r = [ @{$trip_r} ];
                # copy everything

                my @times = @{ $trip_r->[T_TIMES] };

                my @unified_times;

                for my $old_column_idx ( 0 .. $#times ) {

                    my $new_column_idx
                      = $uindex_of_r->{$lineid}[$old_column_idx];

                    $unified_times[$new_column_idx] = $times[$old_column_idx];

                }

                $unified_trip_r->[T_TIMES] = \@unified_times;

                push @{$trip_objs_r}, _tripstruct_to_tripobj($unified_trip_r);

            } ## tidy end: foreach my $trip_r ( @{ $trips_of_lineid_r...})

        } ## tidy end: foreach my $lineid (@lineids)
        $trip_objs_r = Actium::Sked::Trip->stoptimes_sort( @{$trip_objs_r} );

        $trip_objs_r = Actium::Sked::Trip->merge_trips_if_same(
            {   trips => $trip_objs_r,
                methods_to_compare =>
                  [qw <stoptimes_comparison_str sortable_days>]
            }
        );
        # merges double trips -- some trips (mostly school trips) have so many
        # passengers we send two buses out. Scheduling system has to have these
        # twice, but we only want to display them once

        $trips_of_lgdir{$lgdir} = $trip_objs_r;

    } ## tidy end: foreach my $lgdir ( sortbyline...)

    emit_done;

    return \%trips_of_lgdir;

} ## tidy end: sub _make_trip_objs

sub _tripstruct_to_tripobj {
    my $tripstruct = shift;

    return Actium::Sked::Trip->new(
        {   days           => $tripstruct->[T_DAYS],
            vehicletype    => $tripstruct->[T_VEHICLE],
            stoptime_r     => $tripstruct->[T_TIMES],
            daysexceptions => $tripstruct->[T_DAYSEXCEPTIONS],
            type           => $tripstruct->[T_TYPE],
            pattern        => $tripstruct->[T_PATTERN],
            line           => $tripstruct->[T_LINE],
            internal_num   => $tripstruct->[T_INTNUM],
            # DAYSDIGITS - no attribute in Actium::Sked::Trips,
            # but incorporated in days
        }
    );

}

sub _get_trips_of_sked {

    my $trips_of_lgdir_r = shift;
    my %trips_of_sked;

    emit "Assembling trips into schedules by day";

    foreach my $lgdir ( sortbyline keys $trips_of_lgdir_r ) {

        emit_over $lgdir;

        # first, this separates them out by individual days.
        # then, it reassembles them in groups.
        # The reason for this is that sometimes we end up getting
        # weird sets of days across the schedules we receive
        # (e.g., same trips Fridays and Saturdays)
        # and it's easier to do it this way if that's the case.

        my $trips_of_day_r
          = _get_trips_by_day( $trips_of_lgdir_r->{$lgdir} );

        my $trips_of_skedday_r = _assemble_skeddays($trips_of_day_r);

        for my $skedday ( keys $trips_of_skedday_r ) {

            my $skedid = "${lgdir}_$skedday";
            $trips_of_sked{$skedid} = $trips_of_skedday_r->{$skedday};

        }

    } ## tidy end: foreach my $lgdir ( sortbyline...)

    emit_done;

    return \%trips_of_sked;

} ## tidy end: sub _get_trips_of_sked

sub _get_trips_by_day {

    my $trips_r = shift;
    my %trips_of_day;

    foreach my $trip ( @{$trips_r} ) {
        my @days = split( //s, $trip->daycode );
        foreach my $day (@days) {
            push @{ $trips_of_day{$day} }, $trip;
        }
    }
    return \%trips_of_day;
}

sub _assemble_skeddays {
    my $trips_of_day_r = shift;
    my @days           = sort keys $trips_of_day_r;
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
                = _merge_if_appropriate( $found_trips_r, $inner_trips_r ) )
            {
                push @found_days, $inner_day;
                $found_trips_r = $merged_trips_r;
                $already_found_day{$inner_day} = $outer_day;
            }
        }

        # so @found_days now has all the days that are identical to
        # the outer day

        my $skedday = j(@found_days);
        $trips_of_skedday{$skedday} = $found_trips_r;

    } ## tidy end: foreach my $i ( 0 .. $#days)

    return \%trips_of_skedday;

} ## tidy end: sub _assemble_skeddays

const my $MAXIMUM_DIFFERING_TIMES  => 4;
const my $MINIMUM_TIMES_MULTIPLIER => 5;

sub _merge_if_appropriate {

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
        and _trips_are_identical( $outer_trips_r, $inner_trips_r ) );

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

    # In weird situations where, for example, you have several different sets
    # 30 trips that are every day, plus two separate ones on Monday,
    # two separate ones on Tuesday, two separate ones on Wednesday,
    # etc. -- this will give inconsistent results, with Monday's
    # and Tuesday's trips combined but Wednesday's not.
    # To do that you'd need to compare them all to each other simultaneously,
    # which code I am not prepared to write at this point.

    my $in_both = ( max( $inner_count, $outer_count ) ) - $only_in_either;

    if (    $only_in_either <= $MAXIMUM_DIFFERING_TIMES
        and $in_both > ( $MINIMUM_TIMES_MULTIPLIER * $only_in_either ) )
    {
        my $trips_to_merge_r
          = Actium::Sked::Trip->stoptimes_sort( @{$outer_trips_r},
            @{$inner_trips_r} );

        return Actium::Sked::Trip->merge_trips_if_same(
            {   trips              => $trips_to_merge_r,
                methods_to_compare => ['stoptimes_comparison_str'],
            }
        );

    }

    # no merging

    return;

} ## tidy end: sub _merge_if_appropriate

sub _trips_are_identical {
    my $outer_trips_r = shift;
    my $inner_trips_r = shift;

    for my $i ( 0 .. $#{$outer_trips_r} ) {
        return unless $outer_trips_r->[$i] == $inner_trips_r->[$i];
    }

    return 1;

}

1;
