package Octium::Import::Xhea 0.012;

# Using XML::Pastor, reads XML Hastus Exports for Actium files
# (exports from Hastus) and imports them into Actium.
#
# Also other routines with Xhea files or results from them, such as
# creating mock HASI files

## no critic (ProhibitAmbiguousNames)

use Actium;
use Octium;
use Octium::Import::CalculateFields;
use Octium::O::DateTime;

use List::MoreUtils('pairwise');    ### DEP ###
use Params::Validate(':all');       ### DEP ###
use Actium::Time;
use Octium::O::2DArray;

const my $PREFIX => 'Octium::Import::Xhea';

const my $STOPS     => 'stop';
const my $STOPS_PC  => 'stop_with_i';
const my $PLACES    => 'place';
const my $PLACES_PC => 'place_with_i';

const my %tripfield_of_day => qw(
  1  trp_operates_mon
  2  trp_operates_tue
  3  trp_operates_wed
  4  trp_operates_thu
  5  trp_operates_fri
  6  trp_operates_sat
  7  trp_operates_sun
);

const my %blockfield_of_day => qw(
  1   blk_oper_monday
  2   blk_oper_tuesday
  3   blk_oper_wednesday
  4   blk_oper_thursday
  5   blk_oper_friday
  6   blk_oper_saturday
  7   blk_oper_sunday
);

sub xhea_import {

    my %p = Octium::validate(
        @_,
        {   signup       => 1,
            xhea_folder  => 1,
            tab_folder   => 1,
            sch_cal_data => 0,
            note_of_trip => 0,
        }
    );

    my $signup         = $p{signup};
    my $xhea_folder    = $p{xhea_folder};
    my $tab_folder     = $p{tab_folder};
    my $sch_cal_data   = $p{sch_cal_data};
    my $note_of_trip_r = $p{note_of_trip};

    my ( $fieldnames_of_r, $fields_of_r, $adjusted_values_of_r )
      = Octium::Import::Xhea::load_adjusted($xhea_folder);

    if ( exists $fieldnames_of_r->{event_date} ) {
        $note_of_trip_r = _get_trip_notes_from_event_date(
            fieldnames => $fieldnames_of_r,
            fields     => $fields_of_r,
            values     => $adjusted_values_of_r,
            signup     => $signup,
        );

    }

    if ($note_of_trip_r) {
        my $adjusted_trips_r = adjust_trip_note(
            note_of_trip => $note_of_trip_r,
            fieldnames   => $fieldnames_of_r,
            fields       => $fields_of_r,
            values       => $adjusted_values_of_r,
        );

        foreach (qw/trip/) {
            my $orig = $_ . '_orig';
            $fieldnames_of_r->{$orig}      = $fieldnames_of_r->{$_};
            $fields_of_r->{$orig}          = $fields_of_r->{$_};
            $adjusted_values_of_r->{$orig} = $adjusted_values_of_r->{$_};
        }

        $adjusted_values_of_r->{trip} = $adjusted_trips_r;

    }
    elsif ($sch_cal_data) {

        my ( $adjusted_blocks_r, $adjusted_trips_r ) = adjust_sch_cal(
            sch_cal_data => $sch_cal_data,
            fieldnames   => $fieldnames_of_r,
            fields       => $fields_of_r,
            values       => $adjusted_values_of_r,
        );

        foreach (qw/block trip/) {
            my $orig = $_ . '_orig';
            $fieldnames_of_r->{$orig}      = $fieldnames_of_r->{$_};
            $fields_of_r->{$orig}          = $fields_of_r->{$_};
            $adjusted_values_of_r->{$orig} = $adjusted_values_of_r->{$_};
        }

        $adjusted_values_of_r->{block} = $adjusted_blocks_r;
        $adjusted_values_of_r->{trip}  = $adjusted_trips_r;

    }    ## tidy end: elsif ($sch_cal_data)

    my $tab_strings_r
      = Octium::Import::Xhea::tab_strings( $fieldnames_of_r, $fields_of_r,
        $adjusted_values_of_r );

    if ( exists( $fieldnames_of_r->{$STOPS} ) ) {
        my ( $new_s_heads_r, $new_s_records_r )
          = Octium::Import::CalculateFields::hastus_stops_import(
            $fieldnames_of_r->{$STOPS},
            $adjusted_values_of_r->{$STOPS} );

        $tab_strings_r->{$STOPS_PC}
          = Octium::O::2DArray->new($new_s_records_r)->tsv( @{$new_s_heads_r} );

    }

    if ( exists( $fieldnames_of_r->{$PLACES} ) ) {

        my ( $new_p_heads_r, $new_p_records_r )
          = Octium::Import::CalculateFields::hastus_places_import(
            $fieldnames_of_r->{$PLACES},
            $adjusted_values_of_r->{$PLACES} );

        $tab_strings_r->{$PLACES_PC}
          = Octium::O::2DArray->new($new_p_records_r)->tsv( @{$new_p_heads_r} );
    }

    $tab_folder->write_files_from_hash( $tab_strings_r, qw(tab txt) );

    $tab_folder->json_store_pretty( $fields_of_r, 'records.json' );

    return;

}    ## tidy end: sub xhea_import

sub tab_strings {

    my ( $fieldnames_of_r, $fields_of_r, $values_of_r ) = (@_);
    my %tab_of;

    my $cry = cry('Processing XHEA data into tab-delimited text');

    foreach my $record_name ( keys %{$fields_of_r} ) {

        $cry->over($record_name);

        my $fieldnames_r = $fieldnames_of_r->{$record_name};
        my $records_r    = $values_of_r->{$record_name};

        $tab_of{$record_name}
          = Octium::O::2DArray->new($records_r)->tsv( @{$fieldnames_r} );
        # = aoa2tsv( $records_r, $fieldnames_r );

    }

    $cry->over($EMPTY);
    $cry->done;

    return \%tab_of;

}    ## tidy end: sub tab_strings

{

    sub adjust_sch_cal {

        my $cry = cry('Adjusting XHEA data from school calendars');

        my %p = Octium::validate(
            @_,
            {   fields       => 1,
                values       => 1,
                fieldnames   => 1,
                sch_cal_data => 1,
            }
        );
        \my %fields              = $p{fields};
        \my %fieldnames          = $p{fieldnames};
        \my %values              = $p{values};
        \my %calendar_of_tripkey = $p{sch_cal_data};

        #### Block ###

        ### I don't think block adjustments are used at the moment
        ### -- just trip adjustments. And since school calendars don't
        ### necessarily apply to the whole block, it's best just not to
        ### work on these.  I think.

        my @block_headers = @{ $fieldnames{block} };
        my @block_records = @{ $values{block} };
        my @returned_block_records;

        foreach \my @block_record(@block_records) {

            my %field;
            @field{@block_headers} = @block_record;

            my $block = $field{blk_number};
            #            if ( not exists $calendar_of_tripkey{$block} ) {
            push @returned_block_records, [@block_record];
   #            }
   #            else {
   #
   #                if ( Octium::is_arrayref( $calendar_of_tripkey{$block} ) ) {
   #                    $field{blk_evt_stat_dsp}
   #                      = $calendar_of_tripkey{$block}[0]
   #                      . $SPACE
   #                      . $calendar_of_tripkey{$block}[1];
   #                }
   #                else {
   #                    my $days = $calendar_of_tripkey{$block};
   #                    foreach my $day ( keys %blockfield_of_day ) {
   #                        $field{ $blockfield_of_day{$day} }
   #                          = ( $days =~ m/$day/ ) ? 1 : 0;
   #                    }
   #
   #                }
   #
   #                my @new_record = @field{@block_headers};
   #                push @returned_block_records, \@new_record;
   #            } ## tidy end: else [ if ( not exists $calendar_of_tripkey...)]

        }    ## tidy end: foreach \my @block_record(@block_records)

        #### Trip ###

        my @trip_headers = @{ $fieldnames{trip} };
        my @trip_records = @{ $values{trip} };
        my @returned_trip_records;
        #my @display_trip_records;

        foreach \my @trip_record(@trip_records) {

            my %field;
            @field{@trip_headers} = @trip_record;

            my $block = $field{trp_block};
            my $starttime
              = Actium::Time->from_str( $field{trp_time_start} )->timenum;
            my $tripkey = "$block/$starttime";
            $cry->over($tripkey);

            if ( not exists $calendar_of_tripkey{$tripkey} ) {
                push @returned_trip_records, [@trip_record];
            }
            else {

                if ( Octium::is_arrayref( $calendar_of_tripkey{$tripkey} ) ) {
                    $field{trp_event_and_status}
                      = $calendar_of_tripkey{$tripkey}[0]
                      . $SPACE
                      . $calendar_of_tripkey{$tripkey}[1];
                }
                else {
                    my $days = $calendar_of_tripkey{$tripkey};
                    foreach my $day ( keys %tripfield_of_day ) {
                        $field{ $tripfield_of_day{$day} }
                          = ( $days =~ m/$day/ ) ? 1 : 0;
                    }

                }
                my @new_record = @field{@trip_headers};
                push @returned_trip_records, \@new_record;
                #push @display_trip_records, \@new_record;
                delete $calendar_of_tripkey{$tripkey};
            }    ## tidy end: else [ if ( not exists $calendar_of_tripkey...)]
        }    ## tidy end: foreach \my @trip_record(@trip_records)

        foreach my $tripkey ( sort keys %calendar_of_tripkey ) {
            $cry->text("Didn't find $tripkey in schedules");
        }

        $cry->done;

        return \@returned_block_records, \@returned_trip_records;

    }    ## tidy end: sub adjust_sch_cal
}

const my @HOLIDAYS => map Octium::O::DateTime->new( strptime => $_ ),
  qw/
  2018-09-03 2018-11-22 2018-12-25
  2019-01-01 2019-01-21 2019-02-18 2019-05-27
  2019-07-04 2019-09-02 2019-11-28 2019-12-25
  2020-01-01 2020-01-20 2020-02-17 2020-05-25
  2020-07-04 2020-09-07 2020-11-26 2020-12-25
  /;
const my @ICAL_DOW       => ( undef, qw/mo tu we th fr sa su/ );
const my @NOTE_DOW_ABBR  => ( undef, qw/Mon. Tue. Wed. Thurs. Fri. Sat. Sun./ );
const my @NOTELETTER_DOW => ( undef, qw/M T W Th F Sa Su/ );
const my @NOTE_DOW =>
  ( undef, qw/Monday Tuesday Wednesday Thursday Friday Saturday Sunday/ );

sub _get_trip_notes_from_event_date {

    my $cry = cry('Creating trip calendar notes from XHEA event dates');

    require Octium::O::DateTime;
    require DateTime::Event::ICal;

    my %p = Octium::validate(
        @_,
        {   fields     => 1,
            values     => 1,
            fieldnames => 1,
            signup     => 1,
        }
    );
    \my %fields     = $p{fields};
    \my %fieldnames = $p{fieldnames};
    \my %values     = $p{values};
    my $signup = $p{signup};

    my ( %dt_cache, %dts_of_event );

    my @event_date_headers = @{ $fieldnames{event_date} };
    my @event_date_records = @{ $values{event_date} };

    foreach \my @event_date_record(@event_date_records) {

        my %field;
        @field{@event_date_headers} = @event_date_record;
        my ( $date_str, $event, $status )
          = @field{qw/evtd_date evtd_event evtd_status/};

        my $dt = $dt_cache{$date_str} //= Octium::O::DateTime->new($date_str);

        next if Octium::fne( $status, 'on' );

        push $dts_of_event{$event}->@*, $dt;
    }

    my $start = Octium::O::DateTime->oldest_date( values %dt_cache );
    my $end   = Octium::O::DateTime->newest_date( values %dt_cache );

    my ( %quantity_of_dow, %recurrence_set_of );

    foreach my $dow ( 1 .. 7 ) {

        my $set = DateTime::Event::ICal::->recur(
            dtstart => $start,
            until   => $end,
            freq    => 'weekly',
            byday   => [ $ICAL_DOW[$dow] ],
        );

        $set->complement(@HOLIDAYS);

        my @list = $set->as_list;
        $quantity_of_dow{$dow}   = scalar @list;
        $recurrence_set_of{$dow} = $set;

    }

    my %ons_and_offs_of;

    foreach my $event ( keys %dts_of_event ) {
        my %dts_of_dow;

        foreach my $dt ( $dts_of_event{$event}->@* ) {
            my $dow = $dt->dow;
            push $dts_of_dow{$dow}->@*, $dt;
        }

        foreach my $dow ( sort keys %dts_of_dow ) {
            \my @dts_of_dow = $dts_of_dow{$dow};
            my $on_count  = scalar @dts_of_dow;
            my $off_count = $quantity_of_dow{$dow} - $on_count;

            if ( not $off_count ) {
                push $ons_and_offs_of{$event}{all_on_days}->@*,           $dow;
                push $ons_and_offs_of{$event}{all_or_mostly_on_days}->@*, $dow;
            }
            elsif ( $off_count < $on_count ) {
                push $ons_and_offs_of{$event}{all_or_mostly_on_days}->@*, $dow;

                my $except_set
                  = $recurrence_set_of{$dow}->clone->complement(@dts_of_dow);

                $ons_and_offs_of{$event}{except_days}{$dow}
                  = [ $except_set->as_list ];
            }
            else {
                push $ons_and_offs_of{$event}{individual_dates}->@*,
                  @dts_of_dow;
            }

        }    ## tidy end: foreach my $dow ( sort keys...)

    }    ## tidy end: foreach my $event ( keys %dts_of_event)

    my $edumpfh = $signup->open_write('events.dump');
    foreach my $event ( sort keys %ons_and_offs_of ) {
        say $edumpfh "\n$event";
        if ( $ons_and_offs_of{$event}{all_on_days} ) {
            say $edumpfh "All on days: ",
              join( " ", sort $ons_and_offs_of{$event}{all_on_days}->@* );
        }
        if ( $ons_and_offs_of{$event}{all_or_mostly_on_days} ) {
            say $edumpfh "All or mostly on days: ",
              join( " ",
                sort $ons_and_offs_of{$event}{all_or_mostly_on_days}->@* );
        }
        foreach my $dow ( sort keys $ons_and_offs_of{$event}{except_days}->%* )
        {
            say $edumpfh "Except set, day $dow:",
              join( " ",
                sort
                  map { $_->ymd }
                  $ons_and_offs_of{$event}{except_days}{$dow}->@* );
        }
        if ( $ons_and_offs_of{$event}{individual_dates} ) {
            say $edumpfh "Individual dates: ",
              join( " ",
                sort
                  map { $_->ymd }
                  $ons_and_offs_of{$event}{individual_dates}->@* );
        }
    }    ## tidy end: foreach my $event ( sort keys...)

    close $edumpfh;

    my ( %note_of_trip, %notecache, %noteletter_of_note );

    my @trip_headers = @{ $fieldnames{trip} };
    my @trip_records = @{ $values{trip} };

    my %highest_note_of;

  TRIP:
    foreach \my @trip_record(@trip_records) {

        my %field;
        @field{@trip_headers} = @trip_record;
        my ( $direction, $event, $trip_number )
          = @field{qw/tpat_direction trp_event_and_status trp_int_number/};

        next if $direction eq $EMPTY or $event eq $EMPTY;
        die "Unimplemented type of event $event" unless $event =~ /on\z/;
        $event =~ s/on\z//;

        my @trip_operating_days
          = grep { $field{ $tripfield_of_day{$_} } == 1 } 1 .. 7;
        my %is_a_trip_operating_day = map { $_ => 1 } @trip_operating_days;

        my $cachekey = "$event:" . Octium::joinempty(@trip_operating_days);
        if ( exists $notecache{$cachekey} ) {
            $note_of_trip{$trip_number} = $notecache{$cachekey};
            next TRIP;
        }

        my @all_on_days = grep { $is_a_trip_operating_day{$_} }
          @{ $ons_and_offs_of{$event}{all_on_days} // [] };
        my @all_or_mostly_on_days
          = grep { $is_a_trip_operating_day{$_} }
          @{ $ons_and_offs_of{$event}{all_or_mostly_on_days} // [] };
        my %except_days
          = %{ $ons_and_offs_of{$event}{except_days} }{@trip_operating_days};
        my @individual_dates
          = grep { $is_a_trip_operating_day{ $_->dow } }
          @{ $ons_and_offs_of{$event}{individual_dates} // [] };

        #\my @all_on_days = $ons_and_offs_of{$event}{all_on_days} // [];
        #\my @all_or_mostly_on_days
        #  = $ons_and_offs_of{$event}{all_or_mostly_on_days} // [];
        #\my %except_days = $ons_and_offs_of{$event}{except_days} // {};
        #\my @individual_dates
        #  = $ons_and_offs_of{$event}{individual_dates} // [];

        my $note_text = "Operates ";
        my $noteletter;

        if (@all_or_mostly_on_days) {

            if ( @all_or_mostly_on_days < 4 ) {
                $noteletter = Octium::joinempty( map { $NOTELETTER_DOW[$_] }
                      @all_or_mostly_on_days );
            }
            elsif (
                @all_or_mostly_on_days == 4
                and Octium::all { 1 <= $_ and $_ <= 5 }
                @all_or_mostly_on_days
              )
            {
                my $dow = Octium::first {
                    not Octium::in( $_, @all_or_mostly_on_days )
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
                  .= 'every '
                  . Actium::joinseries( items => \@NOTE_DOW[@all_on_days] );
            }
            else {
                $note_text .= 'every ';
                my @everies;
                foreach my $dow (@all_or_mostly_on_days) {
                    my $every = $NOTE_DOW[$dow];
                    if (    exists $except_days{$dow}
                        and defined $except_days{$dow}
                        and @{ $except_days{$dow} } )
                    {
                        my @except_dates = map { $_->format_cldr("MMM. d") }
                          $except_days{$dow}->@*;
                        $every
                          .= ' except '
                          . Actium::joinseries( items => \@except_dates );
                    }
                    push @everies, $every;
                }
                $note_text .= joinseries_semicolon_with( 'and', @everies );

            }

            if (@individual_dates) {
                $note_text .= '; and also on ';
            }

        }    ## tidy end: if (@all_or_mostly_on_days)

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

        }

        my $fullnote = "$noteletter $note_text";
        $note_of_trip{$trip_number} = $fullnote;
        $notecache{$cachekey}       = $fullnote;

    }    ## tidy end: TRIP: foreach \my @trip_record(@trip_records)

    my $dumpfh = $signup->open_write('note_of_trip.dump');
    say $dumpfh Actium::dumpstr(%note_of_trip);
    close $dumpfh;

    return \%note_of_trip;

}    ## tidy end: sub _get_trip_notes_from_event_date

func joinseries_semicolon_with (Str $and!, Str @things!) {
    return $things[0] if 1 == @things;
    return "$things[0] $and $things[1]" if 2 == @things;
    my $final = pop @things;
    return ( join( q{; }, @things ) . "; $and $final" );
}

sub adjust_trip_note {

    my $cry = cry('Adding trip calendar notes to XHEA trips');

    my %p = Octium::validate(
        @_,
        {   fields       => 1,
            values       => 1,
            fieldnames   => 1,
            note_of_trip => 1,
        }
    );
    \my %fields     = $p{fields};
    \my %fieldnames = $p{fieldnames};
    \my %values     = $p{values};
    my %note_of_trip = $p{note_of_trip}->%*;
    # copy so that deletion doesn't affect anything else using that

    #### Trip ###

    my @trip_headers = @{ $fieldnames{trip} };
    my @trip_records = @{ $values{trip} };
    my @returned_trip_records;

    foreach \my @trip_record(@trip_records) {

        my %field;
        @field{@trip_headers} = @trip_record;

        my $tripnum = $field{trp_int_number};

        if ( not exists $note_of_trip{$tripnum} ) {
            push @returned_trip_records, [@trip_record];
        }
        else {
            $field{trp_event_and_status} = $note_of_trip{$tripnum};

            my @new_record = @field{@trip_headers};
            push @returned_trip_records, \@new_record;

            delete $note_of_trip{$tripnum};
        }

    }    ## tidy end: foreach \my @trip_record(@trip_records)

    foreach my $tripnum ( sort keys %note_of_trip ) {
        $cry->text("Didn't find $tripnum in schedules");
    }

    $cry->done;

    return \@returned_trip_records;

}    ## tidy end: sub adjust_trip_note

sub load_adjusted {

    my ( $fieldnames_of_r, $fields_of_r, $values_of_r ) = load(@_);
    my $adjusted_values_of_r
      = adjust_for_basetype( $fields_of_r, $values_of_r );
    return ( $fieldnames_of_r, $fields_of_r, $adjusted_values_of_r );

}

my %basetype_adjust = (
    string            => \&_adjust_string,
    normalized_string => \&_adjust_string,
    boolean           => \&_adjust_boolean,
);

sub adjust_for_basetype {

    my ( $fields_of_r, $values_of_r ) = (@_);
    my %adjusted_values_of;

    my $cry = cry('Adjusting XHEA data for its base type');

    foreach my $record_name ( keys %{$fields_of_r} ) {

        my %adjustments;

        foreach my $field_name ( keys %{ $fields_of_r->{$record_name} } ) {

            my $base = $fields_of_r->{$record_name}{$field_name}{base};

            if ( exists $basetype_adjust{$base} ) {
                $adjustments{$field_name} = $basetype_adjust{$base};
            }

        }

        next unless scalar keys %adjustments;

        foreach my $record ( @{ $values_of_r->{$record_name} } ) {

            my @adjusted_record;

            foreach my $field_name ( keys %{ $fields_of_r->{$record_name} } ) {

                my $idx      = $fields_of_r->{$record_name}{$field_name}{idx};
                my $as_given = $record->[$idx];

                my $adjusted;
                if ( exists $adjustments{$field_name} ) {
                    $adjusted = $adjustments{$field_name}->($as_given);
                }
                else {
                    $adjusted = $as_given;
                }

                $adjusted_record[$idx] = $adjusted;

            }

            push @{ $adjusted_values_of{$record_name} }, \@adjusted_record;

        }    ## tidy end: foreach my $record ( @{ $values_of_r...})

    }    ## tidy end: foreach my $record_name ( keys...)

    $cry->done;

    return \%adjusted_values_of;

}    ## tidy end: sub adjust_for_basetype

sub _adjust_string {
    my $adjusted = shift;
    $adjusted =~ s/\A\s+//s;
    $adjusted =~ s/\s+\z//s;
    $adjusted =~ s/\n+/ /g;
    # change line feeds to a space. Not sure what the right thing to do here is
    # Should I remove other white space before and after line feeds?
    # Should I convert them to something other than spaces?
    return $adjusted;
}

sub _adjust_boolean {
    my $adjusted = shift;

    if ( $adjusted eq 'true' ) {
        $adjusted = 1;
    }
    elsif ( $adjusted eq 'false' ) {
        $adjusted = 0;
    }

    return $adjusted;

}

{

    const my $placepatfile => 'PlacePattern.xml';
    const my @fieldnames   => qw/line direction place rank/;
    const my %fields       => (
        line      => { base => 'string', type => 'string',        idx => 0, },
        direction => { base => 'string', type => 'Dir_ch_String', idx => 1, },
        place     => { base => 'string', type => 'string',        idx => 2, },
        rank      => { base => 'int',    type => 'int',           idx => 3, },
    );

    sub _load_placepatterns {

        my $ppat_cry = cry("Processing place patterns");

        my $xheafolder = shift;
        return unless $xheafolder->file_exists($placepatfile);

        my $fh = $xheafolder->open_read($placepatfile);
        my ( @ppat_records, $line, $direction );

        my $rank = 0;

        while (<$fh>) {
            if (m[<rte_identifier>(.*?)</rte_identifier>]) {
                $line = $1;
                $rank = 0;
            }
            elsif (m[<ppat_direction>(.*?)</ppat_direction>]) {
                $direction = $1;
                $rank      = 0;
            }
            elsif (m[<pplc_id>(.*?)</pplc_id>]) {
                my $place = $1;
                push @ppat_records, [ $line, $direction, $place, $rank ];
                $rank++;
            }
        }

        $ppat_cry->done;

        return ( \@fieldnames, \%fields, \@ppat_records );

    }    ## tidy end: sub _load_placepatterns

}

sub load {

    my $xheafolder = shift;

    my ( %fieldnames_of, %fields_of, %values_of );

    my @ppat_results = _load_placepatterns($xheafolder);

    if (@ppat_results) {
        ( $fieldnames_of{ppat}, $fields_of{ppat}, $values_of{ppat} )
          = @ppat_results;
    }
    my @xhea_filenames = _get_xhea_filenames($xheafolder);

    require XML::Pastor;    ### DEP ###

    my $pastor = XML::Pastor->new();

    my $load_cry = cry('Loading XHEA files');

    foreach my $filename (@xhea_filenames) {

        my $file_cry = cry("Processing $filename");

        my $class_cry = cry('Generating classes from XSD');

        my $xsd       = $xheafolder->make_filespec("$filename.xsd");
        my @xml       = $xheafolder->make_filespec("$filename.xml");
        my @filenames = $filename;

        if ( $xheafolder->file_exists("W$filename.xml") ) {
            push @xml,       $xheafolder->make_filespec("W$filename.xml");
            push @filenames, "W$filename";
        }

        my $newprefix = $PREFIX . "::$filename";

        $pastor->generate(
            mode         => 'eval',
            schema       => $xsd,
            class_prefix => $newprefix,
        );

        $class_cry->done;    # generating classes

        my $model  = ( $newprefix . '::Pastor::Meta' )->Model;
        my $tree_r = _build_tree($model);

        my ( $fieldnames_of_r, $records_of_r, $fields_of_r )
          = _records_and_fields( $tree_r, $filename );

        %fieldnames_of = ( %fieldnames_of, %{$fieldnames_of_r} );
        %fields_of     = ( %fields_of,     %{$fields_of_r} );

        my $newvalues_r = _load_values(
            tree       => $tree_r,
            model      => $model,
            xmlfiles   => \@xml,
            records_of => $records_of_r,
            fields_of  => $fields_of_r,
            filenames  => \@filenames,
        );

        %values_of = ( %values_of, %{$newvalues_r} );

        $file_cry->done;

    }    ## tidy end: foreach my $filename (@xhea_filenames)

    $load_cry->done;

    return ( \%fieldnames_of, \%fields_of, \%values_of );

}    ## tidy end: sub load

sub _load_values {

    my %p = Octium::validate(
        @_,
        {   tree       => 1,
            model      => 1,
            fields_of  => 1,
            records_of => 1,
            xmlfiles   => 1,
            filenames  => 1,
            #tfolder    => 1,
        }
    );

    my @xmlfiles  = $p{xmlfiles}->@*;
    my @filenames = $p{filenames}->@*;

    my %values_of;

    for my $table_name ( keys %{ $p{tree} } ) {
        my $table_class = $p{model}->xml_item_class($table_name);

        my @tables;

        foreach my $i ( 0 .. $#xmlfiles ) {
            my $filename = $filenames[$i];
            my $xmlfile  = $xmlfiles[$i];
            my $load_cry = cry("Loading $table_name from $filename.xml");
            #$load_cry->text('(This can take quite a while; be patient)');
            push @tables, $table_class->from_xml_file($xmlfile);
            $load_cry->done;

        }

        my $record_cry = cry("Processing $table_name into records");

        for my $record_name ( @{ $p{records_of}{$table_name} } ) {

            my @field_names = sort keys %{ $p{fields_of}{$record_name} };

            my %index_of;
            $index_of{$_} = $p{fields_of}{$record_name}{$_}{idx}
              foreach @field_names;

            my @record_objs = map { @{ $_->$record_name } } @tables;

            foreach my $record_obj (@record_objs) {
                my @record_data;
                while ( my ( $field_name, $idx ) = each %index_of ) {
                    $record_data[$idx] = $record_obj->$field_name->__value();
                }
                push @{ $values_of{$record_name} }, \@record_data;
            }

        }

        $record_cry->done;

    }    ## tidy end: for my $table_name ( keys...)

    return \%values_of;

}    ## tidy end: sub _load_values

sub _records_and_fields {

    my $xsd_cry = cry('Processing XSD to record and field info');

    # Hastus exports XML files with three levels:
    # table level (contains records)
    # record level (contains fields), and field level (contains field data).
    # So far there has been only one table per table level
    # and one type of record per record level.
    # This allows more than table and more than one kind of
    # record per table (although names of all record types must be unique
    # across all tables ).
    # However, it does not allow any variations on what the levels are.

    my ( $tree_r, $filename ) = @_;

    $filename = "$filename.xsd";

    my %fields_of;
    my %records_of;
    my %fieldnames_of;

    for my $table ( keys %{$tree_r} ) {
        $xsd_cry->over("table: $table");

        if ( not $tree_r->{$table}{has_subelements} ) {
            _unexpected_croak(
                {   foundtype    => 'data field',
                    foundname    => $table,
                    expectedtype => 'table',
                    filename     => $filename,
                }
            );
        }

        my %info_of_record = %{ $tree_r->{$table}{children} };

        for my $record ( keys %info_of_record ) {
            $xsd_cry->over("record: $record");

            if ( not $info_of_record{$record}{has_subelements} ) {

                _unexpected_croak(
                    {   foundtype    => 'data field',
                        foundname    => $record,
                        expectedtype => 'record',
                        filename     => $filename,
                    }
                );

            }

            push @{ $records_of{$table} }, $record;

            my %info_of_field = %{ $info_of_record{$record}{children} };

            my $field_idx = 0;

            my @fieldnames = sort keys %info_of_field;
            $fieldnames_of{$record} = \@fieldnames;

            for my $field (@fieldnames) {
                $xsd_cry->over("field: $field");

                if ( $info_of_record{$field}{has_subelements} ) {

                    _unexpected_croak(
                        {   foundtype    => 'record',
                            foundname    => $field,
                            expectedtype => 'data field',
                            filename     => $filename,
                        }
                    );

                }

                my %info_of_this_field
                  = %{ $info_of_record{$record}{children}{$field} };

                my $base = $info_of_this_field{base}
                  // $info_of_this_field{type};
                my $type = $info_of_this_field{type};

                for ( $base, $type ) {
                    s{\Q|http://www.w3.org/2001/XMLSchema\E\z}{}sx;
                }

                $fields_of{$record}{$field}
                  = { base => $base, type => $type, idx => $field_idx };

                $field_idx++;
            }    ## tidy end: for my $field (@fieldnames)

        }    ## tidy end: for my $record ( keys %info_of_record)

    }    ## tidy end: for my $table ( keys %{...})

    $xsd_cry->over($EMPTY);

    $xsd_cry->done;

    return \%fieldnames_of, \%records_of, \%fields_of;

}    ## tidy end: sub _records_and_fields

sub _unexpected_croak {

    my %p = Octium::validate(
        @_,
        {   foundtype    => 1,
            foundname    => 1,
            expectedtype => 1,
            filename     => 1,
        }
    );

    croak qq[Unexpected $p{foundtype} "$p{foundname}" ]
      . qq[where $p{expectedtype} expected in $p{filename}];
}

sub _build_tree {

    my $model = shift;

    my $cry = cry('Building element tree');

    my %element_obj_of = %{ $model->element };

    my ( @queue, %tree );

    foreach my $element ( keys %element_obj_of ) {
        push @queue, [ $element, $element_obj_of{$element}, \%tree ];
    }

    while (@queue) {
        my ( $element, $element_obj, $parent_hr ) = @{ shift @queue };

        my $type = $element_obj->type;
        my ( $type_obj, $base, @subelements );

        if ( exists $model->type->{$type} ) {
            $type_obj = $model->type->{$type};
            $base     = $type_obj->base;         # MAY BE UNDEFINED

            if ( $type_obj->contentType eq 'complex' ) {
                @subelements = $type_obj->effectiveElements;
            }
        }

        if (@subelements) {
            my $children_hr = {};
            $parent_hr->{$element} = {
                has_subelements => 1,
                type            => $type,
                children        => $children_hr
            };

            my %element_info_of = %{ $type_obj->effectiveElementInfo };

            foreach my $subelement ( keys %element_info_of ) {
                push @queue,
                  [ $subelement, $element_info_of{$subelement}, $children_hr ];
            }

        }
        else {
            $parent_hr->{$element} = { has_subelements => 0, type => $type };
            $parent_hr->{$element}{base} = $base if $base;
        }

    }    ## tidy end: while (@queue)

    $cry->done;

    return \%tree;

}    ## tidy end: sub _build_tree

sub _get_xhea_filenames {

    my $xheafolder = shift;

    my @xmlfiles = $xheafolder->glob_files('*.xml');
    my @xsdfiles = $xheafolder->glob_files('*.xsd');

    foreach ( @xmlfiles, @xsdfiles ) {
        ( $_, undef ) = Octium::file_ext($_);
    }

    my @xhea_filenames;

    foreach my $filename (@xmlfiles) {

        next if fc($filename) eq fc('PlacePattern');

        # skip PlacePattern, which has a different XML structure
        # than the simple one this part of the program can deal with

        push @xhea_filenames, $filename
          if Octium::in( $filename, @xsdfiles );
    }

    # so @xhea_filenames contains filename piece of all filenames where
    # there is both an .xsd and .xml file

    croak 'No xsd / xml file pairs found when trying to import xhea files'
      unless @xhea_filenames;

    return @xhea_filenames;

}    ## tidy end: sub _get_xhea_filenames

##########################
#### All below is part of the legacy HASI converter

# From trip_pattern.txt
#
#  PAT PAT noparent
#  5 Route!               tpat_route
#  4 Identifier!          tpat_id
# 10 Direction            map from tpat_direction
#  2 DirectionValue       map from tpat_direction
#  8 VehicleDisplay       tpat_veh_display
#  1 IsInService          tpat_in_serv
#  8 Via                  tpat_via
# 40 ViaDescription       [not available...]
#
# from trip_stop.txt
#
#  TPS PAT PAT
#  5 StopIdentifier       stp_511_id
#  6 Place                tstp_place
#  8 VehicleDisplay       [not available, doesn't matter]
#  1 IsATimingPoint       if there's a tstp_place, this is 1
#  1 IsRoutingPoint       not available, doesn't matter
#
# from trip_stop.txt
#
#  TRP TRP noparent
# 10 InternalNumber!      trp_int_number
#  8 Number               (not used)
#  7 OperatingDays        available from all those trp_operates_xxx fields
#  5 RouteForStatistics   get from tpat_route in trip.txt
#  4 Pattern              trp_pattern
# 15 Type                 (not used)
#  2 TypeValue            (not used)
#  1 IsSpecial            (not used)
#  1 IsPublic             (apparently no private trips...)
#
#  PTS TRP TRP
#  8 PassingTime           Not important for Flagspecs

{

    # originally the XHEA files got the capitalized set of directions,
    # but this changed at one point to use the older HASI directions
    # instead, except that it spelled out "Counterclockwise" since
    # the field didn't have the length limit of HASI.

    # So all these are put in, just in case.

    const my %DIRECTION_MAP => (
        '1'              => 1,
        A                => 'A',
        B                => 'B',
        Counterclo       => 'Counterclo',
        Counterclockwise => 'Counterclo',
        Clockwise        => 'Clockwise',
        Eastbound        => 'Eastbound',
        Westbound        => 'Westbound',
        Northbound       => 'Northbound',
        Southbound       => 'Southbound',
        Outbound         => 'Outbound',
        Inbound          => 'Inbound',
        DIR1             => 1,
        DIRA             => 'A',
        DIRB             => 'B',
        CCW              => 'Counterclo',
        CW               => 'Clockwise',
        EAST             => 'Eastbound',
        WEST             => 'Westbound',
        NORTH            => 'Northbound',
        SOUTH            => 'Southbound',
        $EMPTY           => $EMPTY,
    );

    const my %DIRECTION_VALUE_MAP => (
        DIR1             => 10,
        DIRA             => 14,
        DIRB             => 15,
        CCW              => 9,
        CW               => 8,
        EAST             => 2,
        WEST             => 3,
        NORTH            => 0,
        SOUTH            => 1,
        '1'              => 10,
        A                => 14,
        B                => 15,
        Counterclo       => 9,
        Counterclockwise => 9,
        Clockwise        => 8,
        Eastbound        => 2,
        Westbound        => 3,
        Northbound       => 0,
        Southbound       => 1,
        Outbound         => 5,
        Inbound          => 4,
        $EMPTY           => $EMPTY,
    );

    sub to_hasi {
        my ( $xhea_tab_folder, $hasi_folder ) = @_;

        my $cry = cry("Loading XHEA files to memory");

        require Octium::Storage::TabDelimited;

        my ( %trp, %pat, %tps, %pts, %plc );

        my $pattern_callback = sub {
            my $hr = shift;

            #return unless $hr->{tpat_direction};

            my $id        = $hr->{tpat_id};
            my $direction = $DIRECTION_MAP{ $hr->{tpat_direction} };
            my $dirvalue  = $DIRECTION_VALUE_MAP{ $hr->{tpat_direction} };
            my $in_serv   = $hr->{tpat_in_serv};
            my $route     = $hr->{tpat_route};
            my $display   = $hr->{tpat_veh_display};
            my $via       = $hr->{tpat_via};

            my $patid = "$route\t$id";

            $pat{Direction}{$patid}      = $direction;
            $pat{DirectionValue}{$patid} = $dirvalue;
            $pat{IsInService}{$patid}    = $in_serv;
            $pat{Route}{$patid}          = $route;
            $pat{VehicleDIsplay}{$patid} = $display;
            $pat{Via}{$patid}            = $via;
            $pat{Identifier}{$patid}     = $id;

        };

        Octium::Storage::TabDelimited::read_tab_files(
            {   files    => ['trip_pattern.txt'],
                folder   => $xhea_tab_folder,
                callback => $pattern_callback,
            }
        );

        my $trip_callback = sub {
            my $hr = shift;

            my $days = $EMPTY;
            $days .= '1' if $hr->{trp_operates_mon};
            $days .= '2' if $hr->{trp_operates_tue};
            $days .= '3' if $hr->{trp_operates_wed};
            $days .= '4' if $hr->{trp_operates_thu};
            $days .= '5' if $hr->{trp_operates_fri};
            $days .= '6' if $hr->{trp_operates_sat};
            $days .= '7' if $hr->{trp_operates_sun};

            my $route   = $hr->{tpat_route};
            my $tripnum = $hr->{trp_int_number};
            my $pattern = $hr->{trp_pattern};

            my $event = $hr->{trp_event_and_status};

            my $patid = "$route\t$pattern";
            my $is_public = $patid eq "\t" ? 0 : $pat{IsInService}{$patid};

            # if trip has no route or pattern, then make it non-public
            # I don't know why trips without routes or patterns exist...

            $trp{InternalNumber}{$tripnum}     = $tripnum;
            $trp{OperatingDays}{$tripnum}      = $days;
            $trp{RouteForStatistics}{$tripnum} = $route;
            $trp{Pattern}{$tripnum}            = $pattern;
            $trp{IsPublic}{$tripnum}           = $is_public;
            $trp{IsSpecial}{$tripnum}          = $event ? 'X' : $EMPTY;

        };

        Octium::Storage::TabDelimited::read_tab_files(
            {   files    => ['trip.txt'],
                folder   => $xhea_tab_folder,
                callback => $trip_callback,
            }
        );

        my $stop_callback = sub {
            my $hr = shift;

            my %this_row;

            my $stopid   = $hr->{stp_511_id};
            my $tripnum  = $hr->{trp_int_number};
            my $place    = $hr->{tstp_place};
            my $position = $hr->{tstp_position} - 1;

            # we are zero-based, this is one-based
            my $passing_time = $hr->{tstp_passing_time};

            my $route   = $trp{RouteForStatistics}{$tripnum};
            my $pattern = $trp{Pattern}{$tripnum};
            my $patid   = "$route\t$pattern";

            $tps{$patid}[$position]{StopIdentifier} = $stopid;
            $tps{$patid}[$position]{Place}          = $place;
            $tps{$patid}[$position]{IsATimingPoint} = $place ? 1 : 0;

            $pts{$tripnum}[$position]
              = Actium::Time->from_str($passing_time)->apbx_noseparator;
        };

        Octium::Storage::TabDelimited::read_tab_files(
            {   files    => ['trip_stop.txt'],
                folder   => $xhea_tab_folder,
                callback => $stop_callback,
            }
        );

        my $place_callback = sub {
            my $hr = shift;

            my $place = $hr->{plc_identifier};
            $plc{Place}{$place}           = $place;
            $plc{Description}{$place}     = $hr->{plc_description};
            $plc{ReferencePlace}{$place}  = $hr->{plc_reference_place};
            $plc{District}{$place}        = $hr->{plc_district};
            $plc{AlternateNumber}{$place} = $hr->{plc_number};

        };

        Octium::Storage::TabDelimited::read_tab_files(
            {   files    => ['place.txt'],
                folder   => $xhea_tab_folder,
                callback => $place_callback,
            }
        );

        my $signup = $hasi_folder->signup;

        #my $dump_fh = $hasi_folder->open_write("$signup.dump");
        #say $dump_fh Actium::dumpstr (\%pat, \%tps, \%trp, \%pts);
        #close $dump_fh;

        $cry->done;

        my $hasi_cry = cry("Writing HASI files");

        my $pat_cry = cry("Writing $signup.PAT");

        my $pat_fh = $hasi_folder->open_write("$signup.PAT");

        $pat_cry->prog( ( scalar keys %{ $pat{Route} } ) . ' records' );

        foreach my $patid ( keys %{ $pat{Route} } ) {

            printf $pat_fh
              "PAT,%-5s,%-4s,%-10s,%-2s,%-8s,%-1s,%-8s,%-40s$CRLF",
              $pat{Route}{$patid},             # Route
              $pat{Identifier}{$patid},        # Identifier
              $pat{Direction}{$patid},         # Direction
              $pat{DirectionValue}{$patid},    # DirectionValue
              $pat{VehicleDIsplay}{$patid},    # VehicleDisplay
              $pat{IsInService}{$patid},       # IsInService
              $pat{Via}{$patid},               # Via
              $EMPTY,                          # ViaDescription
              ;

            for my $tps_hr ( @{ $tps{$patid} } ) {
                printf $pat_fh "TPS,%-5s,%-6s,%-8s,%-1s,%-1s$CRLF",
                  $tps_hr->{StopIdentifier},    # StopIdentifier
                  $tps_hr->{Place},             # Place
                  $EMPTY,                       # VehicleDisplay
                  $tps_hr->{IsATimingPoint},    # IsATimingPoint
                  0,                            # IsAARoutingPoint
                  ;
            }

        }    ## tidy end: foreach my $patid ( keys %{...})

        close $pat_fh;

        $pat_cry->done;

        my $trip_cry = cry("Writing $signup.TRP");
        $trip_cry->prog(
            ( scalar keys %{ $trp{InternalNumber} } ) . ' records' );

        my $trp_fh = $hasi_folder->open_write("$signup.TRP");

        foreach my $tripnum ( keys %{ $trp{InternalNumber} } ) {

            unless ( defined $trp{IsPublic}{$tripnum} ) {
                $trip_cry->text($tripnum);
            }

            printf $trp_fh
              "TRP,%-10s,%-8s,%-7s,%-5s,%-4s,%-15s,%-2s,%-1s,%-1s$CRLF",
              $trp{InternalNumber}{$tripnum},        # InternalNumber
              $EMPTY,                                # Number
              $trp{OperatingDays}{$tripnum},         # OperatingDays
              $trp{RouteForStatistics}{$tripnum},    # RouteForStatistics
              $trp{Pattern}{$tripnum},               # Pattern
              $EMPTY,                                # Type
              $EMPTY,                                # TypeValue
              $trp{IsSpecial}{$tripnum},             # IsSpecial
              $trp{IsPublic}{$tripnum},              # IsPublic
              ;

            foreach my $passing_time ( @{ $pts{$tripnum} } ) {
                printf $trp_fh "PTS,%-8s$CRLF", $passing_time;
            }

        }    ## tidy end: foreach my $tripnum ( keys ...)

        $trip_cry->done;

        my $plc_cry = cry("Writing $signup.PLC");
        $plc_cry->prog( ( scalar keys %{ $plc{Place} } ) . ' records' );

        my $plc_fh = $hasi_folder->open_write("$signup.PLC");

        foreach my $place ( sort keys %{ $plc{Place} } ) {
            printf $plc_fh
              "PLC,%-6s,%-40s,%-6s,%-6s,%-8s,%-20s,%-10s,%-10s$CRLF",
              $plc{Place}{$place},              # Identifier
              $plc{Description}{$place},        # Description
              $plc{ReferencePlace}{$place},     # Reference place
              $plc{District}{$place},           # District
              $plc{AlternateNumber}{$place},    # AlternateNumber
              $EMPTY,                           # AlternatteName
              $EMPTY,                           # XCoordinate
              $EMPTY,                           # YCoordinate
              ;

        }

        close $plc_fh;

        $plc_cry->done;

        last_cry()->done;

    }    ## tidy end: sub to_hasi

}

1;

__END__

=encoding utf8

=head1 NAME

Octium::Import::Xhea - Routines for loading and processing XML Hastus
exports

=head1 VERSION

This documentation refers to version 0.009

=head1 SYNOPSIS

 use Octium::O::Folder;
 use Octium::Import::Xhea;
 
 my $folder = Octium::O::Folder->new("/path/to/folder");
 # folder should have paired xsd and xml files
 
 my ($fields_r, $values_r) = Octium::Import::Xhea::load_adjusted ($folder);
 
 my $recordname = 'place';
 my $fieldname = 'plc_identifier';
 my $idx = $fields_r->{$recordname}->{$fieldname}->idx;
 say "The first place is " .  $values_r->{$recordname}[0][$idx];
 
=head1 DESCRIPTION

Octium::Import::Xhea is a series of routines for loading XML Hastus
exports and  processing them into perl data structures. It uses
L<XML::Pastor|XML::Pastor> to process the XSD and read XML files, and
so has the limitations of that  module.

B<It ignores all attributes in all XML elements.> The only attribute 
normally found in Hastus XML exports is ' xsi:nil="true" ', which
indicates an empty element.  No practical advantage would be had by
replacing the empty string with an undefined value in the results, so
an empty string is given for such elements and this attribute, along
with all others, is ignored.

=head1 SUBROUTINES 

No subroutines are exported. Use the fully qualified name to invoke
them. (e.g., "Octium::Import::Xhea::load_adjusted($folder)")

=over

=item B<xhea_import>

This routine runs the other routines, performing a complete XHEA import
process. First, it loads and then adjusts the XHEA files  (see load and
adjust_for_basetype below). Then, using routines in 
Octium::Import::CalculateFields, it creates the updated i_ fields. 
Finally, it saves those files in the "tab" folder, and creates a
"records.json"  file storing  the field names and assoocated
information.

It takes three named parameters, all of which should be folder objects.

=over

=item signup

The signup folder.

=item xhea_folder

The folder with XHEA files.

=item tab_folder

The folder to store the tab files in.

=back

=item B<load(I<folderobj>)>

This routine takes a folder object (such as an  Octium::O::Folder or
Octium::O::Folders::Signup object ), looks for paired xml and xsd files
in that folder, and returns three structs: one contains a summary of
the fields and records, one contains further information about the
records and fields, and the other contains the values from the file.

The XML and XSD structure is somewhat limited and assumes the sort of
XML  typically exported from Hastus.

Hastus exports XML files with three levels: table level (contains
records), record level (contains fields),  and field level (contains
field data).

This routine allows multiple tables per file (which hasn't happened)
and  multiple record types per file (which also hasn't happened).   It
does not allow any variations of the levels (so there can't be nested
record types or anything like that). Names of all record types across
all XML files loaded much be unique.

 my ($fieldnames_r, $fields_r, $values_r) = 
    Octium::Import::Xhea::load($folder);

The structure of $fieldnames_r will be:

 $fieldnames_r = 
   { recordname => 
       [ "fieldname", "fieldname", ... ]
   };

The structure of $fields_r will be:

 $fields_r =
   { recordname => 
      { fieldname => 
          {
          base => "basetype",
          type => "type",
          idx => "idx",
          },
       fieldname => I<etc...>
      },
    recordname => I<etc...>
   };
      
It contains a hash whose keys are the record names. The values of that
hash are other hashes whose keys are fieldnames and whose values are a
third hash.  That hash has the literal keys 'base', 'type', and 'idx.'

The 'base' and 'type' entries  both refer to the XSD data type. The
'type' can be either an XSD built-in type  such as string, int, date,
etc., or a custom XML  simple type definition from the XSD. The 'base'
is always an XSD built-in type.  If 'type' is an XSD built-in type,
then 'base' and 'type' are identical.

The 'idx' entry provides an offset into the array of field data for
this field.

The structure of $values_r will be:

 $values_r = 
  { I<recordname> => 
      [
        [ I<data> , I<data> , I<data> ... ], # first record
        [ I<data> , I<data> , I<data> ... ], # second record
        I<etc...>
      ],
    I<recordname> => 
      I<etc...>
  }
      
It contains a hash whose keys are the record names. The values of that
hash are arrays representing individual records. Each record is an
array of scalars, each of which is the data from a field. The 'idx'
entry in the $field_r  struct says which field corresponds to each
entry in the record.

=item B<adjust_for_basetype(I<$fields_r>, I<$values_r>)>

This routine takes the result of load() and adjusts the resulting data
to better match expectations of someone using Perl.

At the moment it does only the following:

=over

=item 1

It removes leading and trailing whitespaces from fields whose base type
is 'string' or 'normalizedString'.

=item 2

For fields whose base type is 'boolean', it changes the values 'true'
to 1  and 'false' to 0.

=back

In future this would be the place to decode base64Binary and hexBinary
types, or possibly other adjustments should that prove necessary.

=item B<load_adjusted(I<folderobj>)>

Equivalent to adjust_for_basetype(load(...))

=item B<tab_strings(I<$fields_r>, I<$values_r>)>

Takes the result of I<load> or I<load_adjusted> and changes them into 
a hash, where the keys are the record types and the values are 
strings. Records are separated by line feeds and fields are separated
by tabs. The first record contains the field names.

=back

=head1 DIAGNOSTICS

=over

=item Unexpected data field "field" where record expected in $filename

=item Unexpected data field "field" where table expected in $filename

=item Unexpected record "record" where data field expected in $filename

While processing an XSD file, a complex type with elements was found
when a  type with no elements was expected, or vice versa.  The program
doesn't know how to  deal with this more complicated schema.

=item No xsd / xml file pairs found when trying to import xhea files

No pairs of XSD and XML files were found in the appropriate folder.
Check that the folder is correct and that the files are present.

=back

=head1 DEPENDENCIES

=over 

=item *

Actium

=item *

Params::Validate

=item *

List::MoreUtils

=item *

XML::Pastor

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2014

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

