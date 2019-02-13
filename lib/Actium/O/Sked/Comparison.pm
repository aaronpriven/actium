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

has trips_count => (
    is       => 'ro',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_trips_count',
);

method _build_trips_count {
    return
        "Trip count: "
      . $self->oldsked->trip_count . ' > '
      . $self->newsked->trip_count;
}

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

has [qw/ids lgdir sortkey/] => (
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

        my $old_lgdir
          = $self->oldsked->linegroup . '_' . $self->oldsked->dircode;
        my $new_lgdir
          = $self->newsked->linegroup . '_' . $self->newsked->dircode;

        $self->_set_lgdir(
              $old_lgdir eq $new_lgdir
            ? $old_lgdir
            : "$old_lgdir > $new_lgdir"
        );

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
            $self->_set_ids("$old_id > $new_id");
        }

    }

}

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

}

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

for my $attr (qw/line daycode specday/) {
    has "shows_$attr" => (
        traits => ['Bool'],
        is     => 'ro',
        isa    => 'Bool',
        #handles => { "_show_$attr" => 'set' },
        lazy    => 1,
        builder => "_build_shows_$attr",
    );
}

method _build_shows_attr (:$trip_attribute, :$sked_attribute) {

    my $oldattr = $self->oldsked->$sked_attribute;
    my $newattr = $self->newsked->$sked_attribute;

    foreach \my %trip ( $self->trips ) {
        my $change = $trip{change};
        if ( $change eq '=' ) {
            return 1
              if $trip{$trip_attribute}[0] ne $oldattr
              or $trip{$trip_attribute}[1] ne $newattr;
        }
        elsif ( $change eq '<' ) {
            return 1 if $trip{$trip_attribute}[0] ne $oldattr;
        }
        else {
            return 1 if $trip{$trip_attribute}[0] ne $newattr;
        }
    }
    return 0;
}

method _build_shows_line {
    return $self->_build_shows_attr(
        trip_attribute => 'line',
        sked_attribute => 'linegroup'
    );
}

method _build_shows_daycode {
    return $self->_build_shows_attr(
        trip_attribute => 'daycode',
        sked_attribute => 'daycode'
    );
}

method _build_shows_specday {
    foreach \my %trip ( $self->trips ) {
        my @specdays = $trip{specday}->@*;
        return 1 if Actium::any {$_} @specdays;
    }
    return 0;

}

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

    }

    return \@place_sdiffs;

}

has _trips_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[HashRef]',
    lazy    => 1,
    handles => { trips => 'elements' },
    builder => '_build_trips',
);

method _build_trips {

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

        }

        if ( defined $matched_trip_idx ) {

            my $newtrip = splice( @newtrips, $matched_trip_idx, 1 );
            push @matched_trips, [ $oldtrip, $newtrip ];

        }
        else {
            push @matched_trips, [ $oldtrip, undef ];
        }

    }

    # any new trips that weren't used for a comparison, keep them around
    push @matched_trips, map { [ undef, $_ ] } @newtrips;

    # now merged trips
    my @merged_trips;

  TRIP_TO_MERGE:
    for my $matched_trip (@matched_trips) {

        my $oldtrip = $matched_trip->[0];
        my $newtrip = $matched_trip->[1];

        #my @merged_trip;

        my %merged_trip;

        if ( defined $oldtrip and defined $newtrip ) {
            $merged_trip{change} = ("=");
            my @oldtimes = $oldtrip->placetimes;
            my @newtimes = $newtrip->placetimes;

            for \my @place_sdiff(@place_sdiffs) {
                my ( $changetype, $oldplace, $newplace, $oldidx, $newidx )
                  = @place_sdiff;

                my $oldtime = defined $oldidx ? $oldtimes[$oldidx] : undef;
                my $newtime = defined $newidx ? $newtimes[$newidx] : undef;

                push $merged_trip{times}->@*, [ $oldtime, $newtime ];

            }

            $merged_trip{daycode} = [ $oldtrip->daycode, $newtrip->daycode ];
            $merged_trip{specday} = [
                $oldtrip->daysexceptions ? '*' : $EMPTY,
                $newtrip->daysexceptions ? '*' : $EMPTY
            ];
            $merged_trip{line} = [ $oldtrip->line, $newtrip->line ];

            push @merged_trips, \%merged_trip;
            next TRIP_TO_MERGE;
        }

        my ( $this_idx, $this_trip );
        if ( defined $oldtrip ) {
            $merged_trip{change} = "<";
            my @oldtimes = $oldtrip->placetimes;
            for \my @place_sdiff(@place_sdiffs) {
                my ( $changetype, $oldplace, $newplace, $oldidx, $newidx )
                  = @place_sdiff;
                my $oldtime = defined $oldidx ? $oldtimes[$oldidx] : undef;
                push $merged_trip{times}->@*, [$oldtime];

            }

            $merged_trip{daycode} = [ $oldtrip->daycode ];
            $merged_trip{specday} = [ $oldtrip->daysexceptions ? '*' : $EMPTY ];
            $merged_trip{line}    = [ $oldtrip->line ];

        }
        else {
            $merged_trip{change} = ">";
            my @newtimes = $newtrip->placetimes;
            for \my @place_sdiff(@place_sdiffs) {
                my ( $changetype, $oldplace, $newplace, $oldidx, $newidx )
                  = @place_sdiff;
                my $newtime = defined $newidx ? $newtimes[$newidx] : undef;
                push $merged_trip{times}->@*, [$newtime];

                $merged_trip{daycode} = [ $newtrip->daycode ];
                $merged_trip{specday}
                  = [ $newtrip->daysexceptions ? '*' : $EMPTY ];
                $merged_trip{line} = [ $newtrip->line ];

            }

        }

        push @merged_trips, \%merged_trip;

    }

    #### sort the trips in time order

    my $column_to_compare;
  FIND_COLUMN_TO_COMPARE:
    foreach my $col_idx ( 0 .. $#place_sdiffs ) {

        my @times
          = map { $_->{times}[$col_idx][0] // $_->{times}[$col_idx][1] }
          @merged_trips;
        # gets a list of all the times for this column

        next FIND_COLUMN_TO_COMPARE
          if Actium::any { not defined $_ } @times;

        $column_to_compare = $col_idx;

    }

    if ( defined $column_to_compare ) {

        @merged_trips = sort {
            ( $a->{times}[$column_to_compare][0]
                  // $a->{times}[$column_to_compare][1] )
              <=> ( $b->{times}[$column_to_compare][0]
                  // $b->{times}[$column_to_compare][1] )
        } @merged_trips;

    }
    else {

        # this is basically a Schwartzian transform but I didn't want to put
        # this whole thing in a single big map statement

        my @interim_list;
        foreach my $trip (@merged_trips) {
            my @times = $trip->{times}->@*;    # copy
            @times = map { $_->[0] // $_->[1] } @times;
            @times = grep {defined} @times;
            my $average = Actium::mean( $times[0], $times[-1] );
            push @interim_list, [ $trip, $average ];
        }

        @interim_list = sort { $a->[1] <=> $b->[1] } @interim_list;
        @merged_trips = map  { $_->[0] } @interim_list;

    }

    return \@merged_trips;

}

method strings_and_formats (:$show_line , :$show_daycode , :$show_specday ) {
    $show_line    //= $self->shows_line;
    $show_daycode //= $self->shows_daycode;
    $show_specday //= $self->shows_specday;
    # Kavorka can't have defaults using the invocant

    my @headers = (
        $self->has_place_differences
        ? [ 'x', 'changed_header' ]
        : [ $EMPTY, 'unchanged_header' ]
    );

    push @headers, [ 'LN',  'unchanged_header' ] if $show_line;
    push @headers, [ 'DAY', 'unchanged_header' ] if $show_daycode;
    push @headers, [ 'EXC', 'unchanged_header' ] if $show_specday;

    foreach \my @sdiff( $self->place_sdiffs ) {
        my ( $changetype, $oldvalue, $newvalue ) = @sdiff;
        if ( $changetype eq '+' ) {
            push @headers, [ "- > $newvalue", 'changed_header' ];
        }
        elsif ( $changetype eq '-' ) {
            push @headers, [ "$oldvalue > -", 'changed_header' ];
        }
        elsif ( $changetype eq 'c' ) {
            push @headers, [ "$oldvalue > $newvalue", 'changed_header' ];
        }
        else {
            push @headers, [ $oldvalue, 'unchanged_header' ];
        }
    }

    my @results = ( \@headers );

    foreach \my %trip ( $self->trips ) {

        my $changemarker = $trip{change};
        my @row_of_times = $trip{times}->@*;
        my @lines        = $trip{line}->@*;
        my @daycodes     = $trip{daycode}->@*;
        my @specdays     = $trip{specday}->@*;

        if ( $changemarker eq '=' ) {

            my $has_difference;
            my @row;

            if ($show_line) {
                if ( $lines[0] ne $lines[1] ) {
                    push @row, [ "$lines[0] > $lines[1]", 'changed_line' ];
                }
                else {
                    push @row, [ $lines[0], 'unchanged_line' ];
                }
            }

            if ($show_daycode) {
                if ( $daycodes[0] ne $daycodes[1] ) {
                    push @row,
                      [ "$daycodes[0] > $daycodes[1]", 'changed_attr' ];
                }
                else {
                    push @row, [ $daycodes[0], 'unchanged_attr' ];
                }
            }

            if ($show_specday) {
                if ( $specdays[0] ne $specdays[1] ) {
                    push @row,
                      [ "$specdays[0] > $specdays[1]", 'changed_attr' ];
                }
                else {
                    push @row, [ $specdays[0], 'unchanged_attr' ];
                }
            }

            foreach \my @times(@row_of_times) {

                @times = map {
                    defined($_)
                      ? Actium::Time->from_num($_)->formatted( format => '24+' )
                      : "-"
                } @times;

                if ( $times[0] eq $times[1] ) {
                    push @row, [ $times[0], 'unchanged_time' ];
                }
                else {
                    $has_difference = 1;
                    push @row, [ "$times[0] > $times[1]", 'changed_time' ];
                }

            }

            if ($has_difference) {
                unshift @row, [ 'x', 'changed_marker' ];
            }
            else {
                unshift @row, [ '', 'unchanged_marker' ];
            }

            push @results, \@row;

        }
        else {
            my $format     = $changemarker eq '<' ? 'old_row'    : 'new_row';
            my $markformat = $changemarker eq '<' ? 'old_marker' : 'new_marker';

            #my @cols = ($changemarker);
            my @cols;
            push @cols, $lines[0]    if $show_line;
            push @cols, $daycodes[0] if $show_daycode;
            push @cols, $specdays[0] if $show_specday;
            push @cols, map {
                Actium::Time->from_num( $_->[0] )->formatted( format => '24+' )
            } @row_of_times;

            push @results,
              [ [ $changemarker, $markformat ], map { [ $_, $format ] } @cols ];

        }

    }

    return @results;

}

method plain_text (:$show_line , :$show_daycode , :$show_specday ) {
    my @strings_and_formats = $self->strings_and_formats(
        show_line    => $show_line,
        show_daycode => $show_daycode,
        show_specday => $show_specday
    );

    my @texts;

    foreach \my @row(@strings_and_formats) {
        my @strings = map { $_->[0] } @row;
        push @texts, join( "\t", @strings );
    }

    return join( "\n", @texts ) . "\n";

}

1;

__END__

method text (:$show_line , :$show_daycode , :$show_specday ) {
    $show_line    //= $self->show_line;
    $show_daycode //= $self->show_daycode;
    $show_specday //= $self->show_specday;
    # Kavorka can't have defaults using the invocant

    my $headers = "\t";
    $headers .= "LN\t"  if $show_line;
    $headers .= "DAY\t" if $show_daycode;
    $headers .= "EXC\t" if $show_specday;
    $headers .= $self->_place_text;
    $headers = "x$headers" if $self->has_place_differences;

    my @texts = ($headers);

    foreach my $trip ( $self->trips->@* ) {

        my $changemarker = $trip->{change};
        my @row_of_times = $trip->{times}->@*;
        my @lines        = $trip->{line}->@*;
        my @daycodes     = $trip->{daycode}->@*;
        my @specdays     = $trip->{specday}->@*;

        if ( $changemarker eq '=' ) {

            my $has_difference;
            my $row_text = $EMPTY;

            if ($show_line) {
                if ( $lines[0] ne $lines[1] ) {
                    $row_text .= "\t$lines[0] > $lines[1]";
                }
                else {
                    $row_text .= "\t$lines[0]";
                }
            }

            if ($show_daycode) {
                if ( $daycodes[0] ne $daycodes[1] ) {
                    $row_text .= "\t$daycodes[0] > $daycodes[1]";
                }
                else {
                    $row_text .= "\t$daycodes[0]";
                }
            }

            if ($show_specday) {
                if ( $specdays[0] ne $specdays[1] ) {
                    $row_text .= "\t$specdays[0] > $specdays[1]";
                }
                else {
                    $row_text .= "\t$specdays[0]";
                }
            }

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

            }

            if ($has_difference) {
                $row_text = "x$row_text";
            }

            push @texts, $row_text;

        }
        else {

            my @cols;
            push @cols, $lines[0]    if $show_line;
            push @cols, $daycodes[0] if $show_daycode;
            push @cols, $specdays[0] if $show_specday;

            push @texts, join(
                "\t",
                $changemarker,
                @cols,
                map {
                    Actium::Time->from_num( $_->[0] )
                      ->formatted( format => '24+' )
                } @row_of_times
            );

        }

    }

    return join( "\n", @texts, '' );

}

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

}

1;

__END__
