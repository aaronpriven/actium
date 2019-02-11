package Actium::O::Sked::Comparison 0.014;

use Actium ('class');
use Algorithm::Diff;
use Actium::O::Sked;

const my $ONLY_NEW  => 2;
const my $ONLY_OLD  => 3;
const my $DIFFER    => 1;
const my $IDENTICAL => 0;

has [qw/oldsked newsked/] => (
    isa      => 'Maybe[Actium::O::Sked]',
    is       => 'ro',
    required => 0,
);

has difference_type => (
    is       => 'rwp',
    isa      => 'Int',
    init_arg => undef,
);

method is_identical {
    return $self->difference_type == $IDENTICAL;
}

method isnt_identical {
    return $self->difference_type != $IDENTICAL;
}

method differs {
    return $self->difference_type == $DIFFER;
}

method is_only_new {
    return $self->difference_type == $ONLY_NEW;
}

method is_only_old {
    return $self->difference_type == $ONLY_OLD;
}

has [qw/ids sortkey/] => (
    is       => 'rwp',
    isa      => 'Str',
    init_arg => undef,
);

method old_id {
    my $oldsked = $self->oldsked;
    return $EMPTY unless defined $oldsked;
    return $oldsked->skedid;
}

method new_id {
    my $newsked = $self->newsked;
    return $EMPTY unless defined $newsked;
    return $newsked->skedid;
}

method _set_sortkey_from_id ($id!) {
    my ( $lg, $rest ) = split( /_/, $id, 2 );
    $lg = Actium::Sorting::Line::linekeys($lg);
    $self->_set_sortkey( $lg . "_$rest" );
    # avoids doing a natural sort on the days,
    # which would sort "67" before "12345"
}

method BUILD {
    my $oldsked = $self->oldsked;
    my $newsked = $self->newsked;

    if ( not defined($oldsked) and not defined($newsked) ) {
        croak "Must specify at least one sked "
          . "when creating a Sked::Comparison";
    }

    if ( not defined $oldsked ) {
        $self->_set_difference_type($ONLY_NEW);
        my $id = $self->new_id;
        $self->_set_ids($id);
        $self->_set_sortkey_from_id($id);
    }
    elsif ( not defined $newsked ) {
        $self->_set_difference_type($ONLY_OLD);
        my $id = $self->old_id;
        $self->_set_ids($id);
        $self->_set_sortkey_from_id($id);
    }
    else {
        if ( $self->oldsked->place_md5 ne $self->newsked->place_md5 ) {
            $self->_set_difference_type($DIFFER);
        }
        else {
            $self->_set_difference_type($IDENTICAL);
        }

        my $old_id = $self->old_id;
        my $new_id = $self->new_id;
        $self->_set_sortkey_from_id($old_id);

        if ( $old_id eq $new_id ) {
            $self->_set_ids($old_id);
        }
        else {
            $self->_set_ids("$old_id>$new_id");
        }

    } ## tidy end: else [ if ( not defined $oldsked)]

} ## tidy end: method BUILD

method differ_text (Str :$new_signup = 'new', Str :$old_signup = 'old') {

    if ( $self->difference_type == $ONLY_NEW ) {
        return "Only in $new_signup: " . $self->new_id;
    }
    elsif ( $self->difference_type == $ONLY_OLD ) {
        return "Only in $old_signup: " . $self->old_id;
    }

    my $old_id = $self->old_id;
    my $new_id = $self->new_id;

    my $ids
      = $old_id ne $new_id
      ? "$old_id in $old_signup and $new_id in $new_signup"
      : $old_id;

    if ( $self->difference_type == $IDENTICAL ) {
        return "$ids: identical";
    }
    else {
        return "$ids: differ";
    }

} ## tidy end: method differ_text

has has_place_differences => (
    is       => 'ro',
    isa      => 'Bool',
    builder  => '_build_has_place_differences',
    lazy     => 1,
    init_arg => undef,
);

method _build_has_place_differences {
    my @sdiffs = $self->place_sdiffs;
    my @changetypes = map { $_->[0] } @sdiffs;
    return Actium::any { $_ ne 'u' } @changetypes;
}

has _place_sdiff_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[ArrayRef]',
    lazy    => 1,
    handles => { place_sdiffs => 'elements' },
    builder => '_build_place_sdiffs',
);

method _build_place_sdiffs {
    # build map of which columns should compare, from old to new

    my @newtps     = $self->newsked->place4s;
    my @oldtps     = $self->oldsked->place4s;
    my $oldcol_idx = 0;
    my $newcol_idx = 0;
    my @place_sdiffs;

    for \my @sdiff( Algorithm::Diff::sdiff( \@oldtps, \@newtps ) ) {
        my ( $changetype, $oldvalue, $newvalue ) = @sdiff;

        if ( $changetype eq '+' ) {
            push @place_sdiffs, [ @sdiff, undef, $newcol_idx ];
            $newcol_idx++;
            next;
        }
        if ( $changetype eq '-' ) {
            push @place_sdiffs, [ @sdiff, undef, $newcol_idx ];
            $newcol_idx++;
            next;
        }

        # changetype is either c or u
        push @place_sdiffs, [ @sdiff, $oldcol_idx, $newcol_idx ];
        $oldcol_idx++;
        $newcol_idx++;
        next;

    } ## tidy end: for \my @sdiff( Algorithm::Diff::sdiff...)

    return \@place_sdiffs;

} ## tidy end: method _build_place_sdiffs

method trips {

    # match up the old and new trips so that similar trips
    # can be compared on the same line

    my @oldtrips = $self->oldsked->trips;
    my @newtrips = $self->newsked->trips;

    my @oldtrips_without_comparison;
    my @matched_trips;
    my @place_sdiffs = $self->place_sdiffs;

    # For each old trip, see if there is any new trip
    # with the same time in the same column. If there is,
    # use the new trip with the most identical times, and
    # compare the two trips on the same line.
    # Remove the new trip from the list of new trips,
    # so it doesn't get compared twice.
    # If there's no new trip wtih the same times, add the old
    # trip to the list of old trips without comparisons.

    for my $oldtrip (@oldtrips) {

        my @old_placetimes = $oldtrip->placetimes;
        my $matched_trip_idx;
        my $matched_trip_time_count = 0;

        for my $newtripidx ( 0 .. $#newtrips ) {
            my $newtrip            = $newtrips[$newtripidx];
            my @new_placetimes     = $newtrip->placetimes;
            my $thistrip_timecount = 0;

            for \my @place_sdiff(@place_sdiffs) {
                my ( $changetype, $oldplace, $newplace, $oldidx, $newidx )
                  = @place_sdiff;
                next if $changetype eq '+' or $changetype eq '-';

                if (    defined $old_placetimes[$oldidx]
                    and defined $new_placetimes[$newidx]
                    and $old_placetimes[$oldidx] == $new_placetimes[$newidx] )
                {
                    $thistrip_timecount++;
                }

            }

            if ( $thistrip_timecount > $matched_trip_time_count ) {
                $matched_trip_idx        = $newtripidx;
                $matched_trip_time_count = $thistrip_timecount;
            }

        } ## tidy end: for my $newtripidx ( 0 ...)

        if ( defined $matched_trip_idx ) {

            my $newtrip = splice( @newtrips, $matched_trip_idx, 1 );
            push @matched_trips, [ $oldtrip, $newtrip ];

        }
        else {
            push @matched_trips, [ $oldtrip, undef ];
        }

    } ## tidy end: for my $oldtrip (@oldtrips)

    # any new trips that weren't used for a comparison, keep them around
    push @matched_trips, map { [ undef, $_ ] } @newtrips;

    # now merged trips
    my @merged_trips;

  TRIP_TO_MERGE:
    for my $matched_trip (@matched_trips) {

        my $oldtrip = $matched_trip->[0];
        my $newtrip = $matched_trip->[1];

        my @merged_trip;
        if ( defined $oldtrip and defined $newtrip ) {
            @merged_trip = ("=");
            my @oldtimes = $oldtrip->placetimes;
            my @newtimes = $newtrip->placetimes;

            for \my @place_sdiff(@place_sdiffs) {
                my ( $changetype, $oldplace, $newplace, $oldidx, $newidx )
                  = @place_sdiff;

                my $oldtime = defined $oldidx ? $oldtimes[$oldidx] : undef;
                my $newtime = defined $newidx ? $newtimes[$newidx] : undef;

                push @merged_trip, [ $oldtime, $newtime ];

            }
            push @merged_trips, \@merged_trip;
            next TRIP_TO_MERGE;
        }

        my ( $this_idx, $this_trip );
        if ( defined $oldtrip ) {
            @merged_trip = "<";
            my @oldtimes = $oldtrip->placetimes;
            for \my @place_sdiff(@place_sdiffs) {
                my ( $changetype, $oldplace, $newplace, $oldidx, $newidx )
                  = @place_sdiff;
                my $oldtime = defined $oldidx ? $oldtimes[$oldidx] : undef;
                push @merged_trip, [$oldtime];

            }

        }
        else {
            @merged_trip = ">";
            my @newtimes = $newtrip->placetimes;
            for \my @place_sdiff(@place_sdiffs) {
                my ( $changetype, $oldplace, $newplace, $oldidx, $newidx )
                  = @place_sdiff;
                my $newtime = defined $newidx ? $newtimes[$newidx] : undef;
                push @merged_trip, [$newtime];

            }

        }

        push @merged_trips, \@merged_trip;

    } ## tidy end: TRIP_TO_MERGE: for my $matched_trip (@matched_trips)

    #### sort the trips in time order

    my $column_to_compare;
  FIND_COLUMN_TO_COMPARE:
    foreach my $col_idx ( 1 .. scalar @place_sdiffs ) {
        # skips one to account for the + - or = at the beginning

        my @times
          = map { $_->[$col_idx][0] // $_->[$col_idx][1] } @merged_trips;
        # gets a list of all the times for this column

        next FIND_COLUMN_TO_COMPARE
          if Actium::any { not defined $_ } @times;

        $column_to_compare = $col_idx;

    }

    if ( defined $column_to_compare ) {

        @merged_trips = sort {
            ( $a->[$column_to_compare][0] // $a->[$column_to_compare][1] )
              <=> ( $b->[$column_to_compare][0] // $b->[$column_to_compare][1] )
        } @merged_trips;

    }
    else {

        # this is basically a Schwartzian transform but I didn't want to put
        # this whole thing in a single big map statement

        my @interim_list;
        foreach my $trip (@merged_trips) {
            my @times = $trip->@[ 1 .. $trip->$#* ];    # copy
            @times = map { $_->[0] // $_->[1] } @times;
            @times = grep {defined} @times;
            my $average = Actium::mean(@times);
            push @interim_list, [ $trip, $average ];
        }

        @interim_list = sort { $a->[1] <=> $b->[1] } @interim_list;
        @merged_trips = map  { $_->[0] } @interim_list;

    }

    return \@merged_trips;

} ## tidy end: method trips

method text {

    my $placetext = "\t" . $self->_place_text;
    $placetext = "x$placetext";

    my @texts = ($placetext);

    foreach my $trip ( $self->trips->@* ) {

        my $changemarker = $trip->[0];
        my @row_of_times = $trip->@[ 1 .. $#{$trip} ];

        if ( $changemarker eq '=' ) {

            my ( $has_difference, $row_text );

            foreach \my @times(@row_of_times) {

                @times = map {
                    defined($_)
                      ? Actium::Time->from_num($_)->formatted( format => '24+' )
                      : "-"
                } @times;

                my $thistime;
                if ( $times[0] eq $times[1] ) {
                    $thistime = $times[0];
                }
                else {
                    $has_difference = 1;
                    $thistime       = $times[0] . " > " . $times[1];
                }

                $row_text .= "\t$thistime";

            } ## tidy end: foreach \my @times(@row_of_times)

            if ($has_difference) {
                $row_text = "x$row_text";
            }

            push @texts, $row_text;

        } ## tidy end: if ( $changemarker eq ...)
        else {
            push @texts, join(
                "\t",
                $changemarker,
                map {
                    Actium::Time->from_num( $_->[0] )
                      ->formatted( format => '24+' )
                } @row_of_times
            );

        }

    } ## tidy end: foreach my $trip ( $self->trips...)

    return join( "\n", @texts, '' );

} ## tidy end: method text

method _place_text {
    my @places;
    foreach \my @sdiff( $self->place_sdiffs ) {
        my ( $changetype, $oldvalue, $newvalue ) = @sdiff;
        if ( $changetype eq '+' ) {
            push @places, "- > $newvalue";
        }
        elsif ( $changetype eq '-' ) {
            push @places, "$oldvalue > -";
        }
        elsif ( $changetype eq 'c' ) {
            push @places, "$oldvalue > $newvalue";
        }
        else {
            push @places, $oldvalue;
        }
    }
    return join( "\t", @places );

} ## tidy end: method _place_text

1;

__END__
