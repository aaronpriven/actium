package Actium::Import::GTFS::TripCalendars 0.012;

use Actium;
use Actium::Import::GTFS (':all');
use Actium::Time;
use Actium::O::DateTime;
use DateTime::Duration;
use DateTime::Event::Recurrence;
use DateTime::Event::ICal;
use DateTime::Span;
use List::Compare::Functional ('is_LsubsetR');

# "dow" in identifiers means day of week

use Data::Printer { filters => { 'Actium::O::DateTime' => sub { $_[0]->ymd }, },
};

const my @DAYS_OF_WEEK =>
  qw/sunday monday tuesday wednesday thursday friday saturday/;
const my @FOLLOWING_DAYS_OF_WEEK => @DAYS_OF_WEEK[ 1 .. 6, 0 ];

const my @NOTE_DOW =>
  ( undef, qw/Monday Tuesday Wednesday Thursday Friday Saturday Sunday/ );

my (%calendar,    %exceptions,        $initial,
    $final,       %dt_set_of,         %serviceids_of_dow,
    $holiday_set, %note_of_serviceid, %noteletter_of_note,
    %note_of_trip,
);

func calendar_notes_of_trips ( Actium::O::Folders::Signup $signup) {

    read_calendar($signup);

    # Delete Dumbarton, which is an ugly thing but I don't know how
    # else to do it right now

    my @db_ids = grep {/-DBDB1-/} keys %calendar;
    delete @calendar{@db_ids};

    adjust_calendar_for_midnight($signup);
    read_calendar_dates($signup);

    @db_ids = grep {/-DBDB1-/} keys %exceptions;
    delete @exceptions{@db_ids};

    adjust_exceptions_for_midnight();
    make_unexceptional_sets();
    place_exceptions_in_sets();
    holidays();
    delete_unexceptional_sets();
    make_ons_and_offs();

    text_notes();

    read_tripids($signup);

    return \%note_of_trip;

} ## tidy end: func calendar_notes_of_trips

func read_calendar ($signup) {

    %calendar = hash_read_gtfs(
        signup => $signup,
        file   => 'calendar',
        key    => 'service_id',
    )->%*;

    # get DateTime objects

    foreach my $service_id ( keys %calendar ) {
        my $start = dt_from_gtfs_date( $calendar{$service_id}{start_date} );
        my $end   = dt_from_gtfs_date( $calendar{$service_id}{end_date} );

        $calendar{$service_id}{_dt_start_date} = $start;
        $calendar{$service_id}{_dt_end_date}   = $end;

    }
    return;    # results in %calendar

} ## tidy end: func read_calendar

func adjust_calendar_for_midnight ($signup) {
    \my %attributes = hash_read_gtfs(
        signup => $signup,
        file   => 'calendar_attributes',
        key    => 'service_id',
    );

    my %adjusted_calendar;

    foreach my $service_id ( keys %calendar ) {

        \my %old_calendar = $calendar{$service_id};
        my %new_calendar = %old_calendar;
        $new_calendar{_description}
          = $attributes{$service_id}{service_description} // $EMPTY;

        # adjust before-midnight schedules so they are on the correct days

        my ( $start, $end );

        if (    exists $attributes{$service_id}
            and exists $attributes{$service_id}{service_description}
            and $attributes{$service_id}{service_description} =~ /before/i )
          # this is fragile.
          # it should be replaced by an analysis of the times in trip.txt

        {
            @new_calendar{@FOLLOWING_DAYS_OF_WEEK}
              = @old_calendar{@DAYS_OF_WEEK};

            my $old_start = $old_calendar{'_dt_start_date'};
            $start                              = following_day($old_start);
            $new_calendar{"_old_dt_start_date"} = $old_start;
            $new_calendar{"_old_start_date"}    = $old_calendar{'start_date'};
            $new_calendar{'_dt_start_date'}     = $start;
            $new_calendar{start_date}           = $start->ymd($EMPTY);

            my $old_end = $old_calendar{'_dt_end_date'};
            $end                              = following_day($old_end);
            $new_calendar{"_old_dt_end_date"} = $old_end;
            $new_calendar{"_old_end_date"}    = $old_calendar{'end_date'};
            $new_calendar{'_dt_end_date'}     = $end;
            $new_calendar{end_date}           = $end->ymd($EMPTY);
            $new_calendar{'_adjusted'}        = 1;

        } ## tidy end: if ( exists $attributes...)
        else {
            $new_calendar{'_adjusted'} = 0;
            $start                     = $new_calendar{'_dt_start_date'};
            $end                       = $new_calendar{'_dt_end_date'};
        }

        $initial = $start
          if not defined $initial
          or $start < $initial;
        $final = $end if not defined $final or $final < $end;

        $adjusted_calendar{$service_id} = \%new_calendar;
    } ## tidy end: foreach my $service_id ( keys...)

    %calendar = %adjusted_calendar;

    return;    # results in %calendar, $initial, $final

} ## tidy end: func adjust_calendar_for_midnight

func read_calendar_dates ($signup) {

    ( \my %date_column, \my @calendar_dates )
      = array_read_gtfs( signup => $signup, file => 'calendar_dates' );

    foreach \my @calendar_date(@calendar_dates) {
        my ( $service_id, $date, $exception_type )
          = @calendar_date[ @date_column{qw/service_id date exception_type/} ];
        my $dt = dt_from_gtfs_date($date);
        push $exceptions{$service_id}->@*,
          { '_dt'          => $dt,
            date           => $date,
            exception_type => $exception_type
          };
    }

    return;    # results in %exceptions

}

func adjust_exceptions_for_midnight {

    my %adjusted_exceptions;

    foreach my $service_id ( keys %exceptions ) {

        if ( $calendar{$service_id}{'_adjusted'} ) {
            foreach \my @exceptions( $exceptions{$service_id} ) {
                foreach \my %exception (@exceptions) {

                    my $adj_dt   = following_day( $exception{'_dt'} );
                    my $adj_date = $adj_dt->ymd($EMPTY);

                    my %adj_exception = %exception;
                    $adj_exception{'_dt'} = $adj_dt;
                    $adj_exception{date} = $adj_date;
                    push $adjusted_exceptions{$service_id}->@*, \%adj_exception;
                }
            }
        }
        else {
            $adjusted_exceptions{$service_id} = $exceptions{$service_id};
        }
    } ## tidy end: foreach my $service_id ( keys...)

    %exceptions = %adjusted_exceptions;
    return;    # results in %exceptions

} ## tidy end: func adjust_exceptions_for_midnight

func make_unexceptional_sets {

    foreach my $service_id ( keys %calendar ) {

        my $start = $calendar{$service_id}{_dt_start_date};
        my $end   = $calendar{$service_id}{_dt_end_date};

        my @days = grep { $calendar{$service_id}{$_} } @DAYS_OF_WEEK;

        my @ical_days = map { substr( $_, 0, 2 ) } @days;
        my $set = DateTime::Event::Recurrence->weekly( days => \@ical_days );

        $set
          = $set->intersection(
            DateTime::Span->from_datetimes( start => $start, end => $end ) );

        $dt_set_of{$service_id} = $set;
        foreach my $dow (@days) {
            push $serviceids_of_dow{$dow}->@*, $service_id;
        }

    } ## tidy end: foreach my $service_id ( keys...)

    return;    # results in %dt_set_of, %serviceids_of_dow

} ## tidy end: func make_unexceptional_sets

const my $EXCEPTION_TYPE_ADD    => 1;
const my $EXCEPTION_TYPE_REMOVE => 2;

func place_exceptions_in_sets {

    foreach my $service_id ( keys %exceptions ) {
        my ( @additions, @removals );
        foreach \my %exception ( $exceptions{$service_id}->@* ) {
            my $dt   = $exception{'_dt'};
            my $type = $exception{'exception_type'};
            if ( $type == $EXCEPTION_TYPE_REMOVE ) {
                push @removals, $dt;
            }
            elsif ( $type == $EXCEPTION_TYPE_ADD ) {
                push @additions, $dt;
            }
            else {
                die qq{Unknown exception type in calendar_dates: "$type"};
            }
        }
        my $set;
        if ( not exists $dt_set_of{$service_id} ) {
            $set = DateTime::Set->empty_set;
        }
        else {
            $set = $dt_set_of{$service_id};
        }
        if (@additions) {
            $dt_set_of{$service_id} = $set->union(@additions);
        }
        if (@removals) {
            $dt_set_of{$service_id} = $set->complement(@removals);
        }

    } ## tidy end: foreach my $service_id ( keys...)

    return;    # results in %dt_set_of

} ## tidy end: func place_exceptions_in_sets

func holidays {

    # the idea is to go through the exception dates. If none of the
    # services that normally operate on that weekday really operate
    # on that date, then that day must be a holiday.

    # first, assemble a list of all the exception dates.
    # (Have to do this _after_ adjustment.)

    my (%dt_of_date);
    foreach my $service_id ( keys %exceptions ) {
        foreach \my @exceptions( $exceptions{$service_id} ) {
            foreach \my %exception (@exceptions) {
                $dt_of_date{ $exception{date} } //= $exception{_dt};
            }
        }
    }

    # then, for each date, go through all services that are supposed
    # to operate on that weekday and see if any of them actually do.

    my @holidays;

  DATE:
    foreach my $dt ( values %dt_of_date ) {

        my $dow_idx = $dt->dow;
        $dow_idx = 0 if $dow_idx == 7;
        my $dow = $DAYS_OF_WEEK[$dow_idx];

        foreach my $service_id ( $serviceids_of_dow{$dow}->@* ) {
            my $set = $dt_set_of{$service_id};
            next DATE if $set->contains($dt);
        }

        # no set matched, so must be a holiday
        push @holidays, $dt;

    }

    $holiday_set = DateTime::Set->from_datetimes( dates => \@holidays );

    return;
} ## tidy end: func holidays

func delete_unexceptional_sets {
    # these are sets without any exceptions at all,
    # or sets with only holiday exceptions

    # delete sets without any exceptions at all
    foreach my $service_id ( sort keys %dt_set_of ) {
        if ( not exists $exceptions{$service_id} ) {
            delete $dt_set_of{$service_id};
        }
    }

    # delete sets with only holiday exceptions,
    foreach my $service_id ( sort keys %exceptions ) {
        my (@exception_dts);
        foreach \my %exception ( $exceptions{$service_id}->@* ) {
            my $dt   = $exception{_dt};
            my $type = $exception{exception_type};
            push @exception_dts, $dt;
        }

        #my @exception_dts = map { $_->{_dt} } $exceptions{$service_id}->@*;
        if (    $holiday_set->count == @exception_dts
            and $holiday_set->contains(@exception_dts) )
        {
            delete $dt_set_of{$service_id};
        }
    }

    return;

} ## tidy end: func delete_unexceptional_sets

const my @ICAL_DOW       => ( undef, qw/mo tu we th fr sa su/ );
const my @NOTE_DOW_ABBR  => ( undef, qw/Mon. Tue. Wed. Thurs. Fri. Sat. Sun./ );
const my @NOTELETTER_DOW => ( undef, qw/M T W Th F Sa Su/ );
# element 0 not used

my (%ons_and_offs_of);

func make_ons_and_offs {

    my ( %quantity_of_dow, %recurrence_set_of );

    # just in case not every signup begins and ends on the same day...
    foreach my $dow ( 1 .. 7 ) {
        my $ical_dow = $ICAL_DOW[$dow];

        my $set = DateTime::Event::ICal::->recur(
            dtstart => $initial,
            until   => $final,
            freq    => 'weekly',
            byday   => [$ical_dow],
        );

        my @list = $set->as_list;
        $quantity_of_dow{$dow}   = scalar @list;
        $recurrence_set_of{$dow} = $set;

    }

    foreach my $service_id ( keys %dt_set_of ) {
        my @dts = $dt_set_of{$service_id}->as_list;
        my %dts_of_dow;

        foreach my $dt (@dts) {
            my $dow = $dt->dow;
            push $dts_of_dow{$dow}->@*, $dt;
        }

        foreach my $dow ( sort keys %dts_of_dow ) {
            \my @dts = $dts_of_dow{$dow};
            my $on_count  = scalar @dts;
            my $off_count = $quantity_of_dow{$dow} - $on_count;

            if ( not $off_count ) {
                push $ons_and_offs_of{$service_id}{all_on_days}->@*, $dow;
                push $ons_and_offs_of{$service_id}{all_or_mostly_on_days}->@*,
                  $dow;
            }
            elsif ( $off_count < $on_count ) {
                push $ons_and_offs_of{$service_id}{all_or_mostly_on_days}->@*,
                  $dow;

                my $except_set
                  = $recurrence_set_of{$dow}->clone->complement(@dts);

                $ons_and_offs_of{$service_id}{except_days}{$dow}
                  = [ $except_set->as_list ];
            }
            else {
                push $ons_and_offs_of{$service_id}{individual_dates}->@*, @dts;
            }

        } ## tidy end: foreach my $dow ( sort keys...)

    } ## tidy end: foreach my $service_id ( keys...)

    return;    # data in %ons_and_offs_of

} ## tidy end: func make_ons_and_offs

func text_notes {

    my %highest_note_of;

    foreach my $service_id ( keys %ons_and_offs_of ) {

        \my @all_on_days = $ons_and_offs_of{$service_id}{all_on_days} // [];
        \my @all_or_mostly_on_days
          = $ons_and_offs_of{$service_id}{all_or_mostly_on_days} // [];
        \my %except_days = $ons_and_offs_of{$service_id}{except_days} // {};
        \my @individual_dates
          = $ons_and_offs_of{$service_id}{individual_dates} // [];

        my $note_text = "Operates ";
        my $noteletter;

        if (@all_or_mostly_on_days) {

            if ( @all_or_mostly_on_days < 4 ) {
                $noteletter = Actium::joinempty( map { $NOTELETTER_DOW[$_] }
                      @all_or_mostly_on_days );
            }
            elsif (
                @all_or_mostly_on_days == 4
                and Actium::all { 1 <= $_ and $_ <= 5 }
                @all_or_mostly_on_days
              )
            {
                my $dow = Actium::first {
                    not Actium::in( $_, @all_or_mostly_on_days )
                }
                1 .. 5;
                $noteletter = 'X' . $NOTELETTER_DOW[$dow];
            }
            elsif ( "@all_or_mostly_on_days" eq '1 2 3 4 5' ) {
                $noteletter = 'WD';
            }
            else {
                $noteletter = 'B';
            }

            if ( @all_or_mostly_on_days == @all_on_days ) {
                $note_text
                  .= 'every ' . Actium::joinseries( @NOTE_DOW[@all_on_days] );
            }
            else {
                $note_text .= 'every ';
                my @everies;
                foreach my $dow (@all_or_mostly_on_days) {
                    my $every = $NOTE_DOW[$dow];
                    if ( exists $except_days{$dow} ) {
                        my @except_dates = map { $_->format_cldr("MMM. d") }
                          $except_days{$dow}->@*;
                        $every
                          .= ' except ' . Actium::joinseries(@except_dates);
                    }
                    push @everies, $every;
                }
                $note_text .= joinseries_semicolon_with( 'and', @everies );

            }

            if (@individual_dates) {
                $note_text .= '; and also on ';
            }

        } ## tidy end: if (@all_or_mostly_on_days)

        if (@individual_dates) {

            if ( not @all_or_mostly_on_days ) {
                $note_text .= "only on ";
                $noteletter = 'A';
            }

            my @individual_date_text = map { $_->format_cldr("EEE., MMM. d") }
              sort @individual_dates;

            $note_text
              .= joinseries_semicolon_with( 'and', @individual_date_text );

        }
        $note_text = $note_text . '.';

        if ( exists $noteletter_of_note{$note_text} ) {
            $noteletter = $noteletter_of_note{$note_text};
        }
        else {
            if ( exists $highest_note_of{$noteletter} ) {
                $highest_note_of{$noteletter}++;
                $noteletter .= '-' . $highest_note_of{$noteletter};
                $noteletter_of_note{$note_text} = $noteletter;
            }
            else {
                $highest_note_of{$noteletter} = '1';
                $noteletter .= '-1';
                $noteletter_of_note{$note_text} = $noteletter;
            }
            $note_of_serviceid{$service_id} = $note_text;
        }

    } ## tidy end: foreach my $service_id ( keys...)

} ## tidy end: func read_calendar0

func read_tripids ($signup) {

    ( \my %trip_column, \my @trips )
      = array_read_gtfs( signup => $signup, file => 'trips' );

    foreach \my @trip(@trips) {

        my ( $trip_id, $service_id, $route_id )
          = @trip[ @trip_column{qw/trip_id service_id route_id/} ];

        if ( exists $note_of_serviceid{$service_id} ) {

            my ( $route, $signup_code ) = split( /-/, $route_id );

            if ( $service_id =~ '1712WR-D4-Weekday-13'
                and ( not $route =~ /\A6[0-9][0-9]\z/ ) )
            {
                next;
            }

            my $note       = $note_of_serviceid{$service_id};
            my $noteletter = $noteletter_of_note{$note};

            #say join(" => " , $trip_id, $service_id , $noteletter, $note);
            $note_of_trip{$trip_id} = "$noteletter $note";
        }
    } ## tidy end: foreach \my @trip(@trips)

    return;

} ## tidy end: func read_calendar1

func joinseries_semicolon_with (Str $and!, Str @things!) {
    return $things[0] if 1 == @things;
    return "$things[0] $and $things[1]" if 2 == @things;
    my $final = pop @things;
    return ( join( q{; }, @things ) . "; $and $final" );
}

#######################################
## DateTime conversion / math routines

func dt_from_gtfs_date ( Str $date) {
    state %dt_of;
    return $dt_of{$date} if exists $dt_of{date};
    my $year  = substr( $date, 0, 4 );
    my $month = substr( $date, 4, 2 );
    my $day   = substr( $date, 6, 2 );
    my $dt = Actium::O::DateTime::->new( ymd => [ $year, $month, $day ] );
    return $dt_of{$date} = $dt;
}

func following_day ( Actium::O::DateTime $dt) {
    state $one_day = DateTime::Duration->new( days => 1 );
    my $new_dt = Actium::O::DateTime::->from_object( object => $dt );
    $new_dt->add_duration($one_day);
    return $new_dt;
}

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
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

