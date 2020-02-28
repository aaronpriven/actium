package Octium::O::Sked::Storage::Tabxchange 0.013;

use Octium ('role');
use Actium::Time;

const my $LAST_LINE_IN_FIRST_LOCAL_LIST => 70;
# arbitrary choice, but it must always be the same or links will break

method tabxchange (
    :destinationcode($dc)!,
    :$actiumdb!,
    :collection($skedcollection)!,
  ) {

    # tab files for AC Transit web site
    #  my $self = shift;

    #  my %params = Octium::validate(
    #      @_,
    #      {   destinationcode => 1,
    #          actiumdb        => 1,
    #          collection      => 1,
    #      },
    #  );
    #
    #  my $dc             = $params{destinationcode};
    #  my $actiumdb       = $params{actiumdb};
    #  my $skedcollection = $params{collection};

    require Octium::O::2DArray;

    # line 1 - skedid

    my $skedid = $self->transitinfo_id;
    my $aoa = Octium::O::2DArray->bless( [ [$skedid] ] );

    my $p = sub { $aoa->push_row( @_, $EMPTY ) };
    # the $EMPTY is probably not needed but the old program
    # added a tab at the end of every line

    my $p_blank = sub { push @{$aoa}, [] };
    # to push an actual blank line

    # line 2 - days
    my $days             = $self->days_obj;
    my $days_transitinfo = $self->days_obj->as_transitinfo;
    $p->(
        $days_transitinfo, $days->as_adjectives,
        $days->as_abbrevs, $days->as_plurals,
    );

    # line 3 - direction/destination
    my $final_place = $self->place4(-1);
    my $destination = $actiumdb->destination($final_place);
    my $dir_obj     = $self->dir_obj;
    my $dir         = $dir_obj->dircode;
    if ( $dir eq 'CC' ) {
        $destination = "Counterclockwise to $destination,";
    }
    elsif ( $dir eq 'CW' ) {
        $destination = "Clockwise to $destination,";
    }
    elsif ( $dir eq 'A' ) {
        $destination = "A Loop to $destination,";
    }
    elsif ( $dir eq 'B' ) {
        $destination = "B Loop to $destination,";
    }
    else {
        $destination = "To $destination,";
    }

    my $destcode = $dc->code_of($destination);
    $p->( $dir_obj->as_onechar . $destcode, $dir_obj->as_bound, $destination );

    # line 4 - upcoming/current and linegroup
    my $linegroup       = $self->linegroup;
    my $linegroup_row_r = $actiumdb->line_row_r($linegroup);

    $p->(
        'U',
        $linegroup,
        $EMPTY,    # LineGroupWebNote - no longer valid
        $linegroup_row_r->{LineGroupType},
        $EMPTY,    # UpComingOrCurrentLineGroup
    );

    # line 5 - all lines
    $p->( $self->lines );

    # line 6 - associated schedules
    $p->( $skedcollection->sked_transitinfo_ids_of_lg($linegroup) );

    # lines 7 - one line per bus line
    foreach my $line ( $self->lines ) {
        my $line_row_r = $actiumdb->line_row_r($line);
        my $color      = $line_row_r->{Color} // 'Default';
        $color = 'Default'
          if not $actiumdb->color_exists($color);
        my $color_row_r = $actiumdb->color_row_r($color);

        $p->(
            $line,
            $line_row_r->{Description},
            '',    # DirectionFile
            '',    # StopListFile
            '',    # MapFileName,
            '',    # LineNote,
            $line_row_r->{TimetableDate},
            $color_row_r->{Cyan},
            $color_row_r->{Magenta},
            $color_row_r->{Yellow},
            $color_row_r->{Black},
            $color_row_r->{RGB}
        );

    }    ## tidy end: foreach my $line ( $self->lines)

    # lines 8 - timepoints
    my @place4s = $self->place4s;
    $p->(@place4s);

    # lines 9 - lines per timepoint

    my @placedescs;

    foreach my $place (@place4s) {

        my $desc = $actiumdb->field_of_referenced_place(
            place => $place,
            field => 'c_description',
        );
        push @placedescs, $desc;
        my $city = $actiumdb->field_of_referenced_place(
            place => $place,
            field => 'c_city',
        );
        my $usecity = (
            $actiumdb->field_of_referenced_place(
                place => $place,
                field => 'ux_usecity_description',
            ) ? 'Yes' : 'No'
        );

        $p->(
            $place,
            $desc,
            $city,
            $usecity,
            $EMPTY,    # Neighborhood
            $EMPTY,    # TPNote
            $EMPTY,    # fake timepoint note
        );
    }    ## tidy end: foreach my $place (@place4s)

    # lines 10 - footnotes for a trip

    $p_blank->();
    # make an actual blank line

    #$p->($EMPTY);

    # lines 11 - schedule notes

    my $fullnote      = $EMPTY;
    my $schedule_note = $linegroup_row_r->{schedule_note};
    $fullnote .= $schedule_note if $schedule_note;

    my $govtopic = $linegroup_row_r->{GovDeliveryTopic};

    if ($govtopic) {
        $fullnote
          .= '<p>'
          . q{<a href="https://public.govdelivery.com/}
          . q{accounts/ACTRANSIT/subscriber/new?topic_id=}
          . $govtopic . q{">}
          . 'Get timely, specific updates about '
          . "Line $linegroup from AC Transit eNews."
          . '</a></p>';
    }

    $fullnote .= '<p>The times provided are for '
      . 'important landmarks along the route.';

    my %stoplist_url_of;

    foreach my $line ( $self->lines ) {
        my $line_row_r = $actiumdb->line_row_r($line);

        my $linegrouptype = lc( $line_row_r->{LineGroupType} );
        $linegrouptype =~ s/ /-/g;    # converted to dashes by wordpress
        if ($linegrouptype) {
            if ( $linegrouptype eq 'local' ) {
                no warnings 'numeric';
                if ( $line <= $LAST_LINE_IN_FIRST_LOCAL_LIST ) {
                    $linegrouptype = 'local1';
                }
                else {
                    $linegrouptype = 'local2';
                }
            }

            $stoplist_url_of{$line}
              = qq{http://www.actransit.org/rider-info/stops/$linegrouptype/#$line};
        }
        else {
            carp "No linegroup type for line $line";
        }

    }    ## tidy end: foreach my $line ( $self->lines)

    my @linklines = Octium::sortbyline keys %stoplist_url_of;
    my $numlinks  = scalar @linklines;

    if ( 1 == $numlinks ) {
        my $linkline = $linklines[0];

        $fullnote
          .= $SPACE
          . qq{<a href="$stoplist_url_of{$linkline}">}
          . qq{A complete list of stops for Line $linkline is also available.</a>};
    }
    elsif ( $numlinks != 0 ) {

        my @stoplist_links
          = map {qq{<a href="$stoplist_url_of{$_}">$_</a>}} @linklines;

        $fullnote
          .= ' Complete lists of stops for lines '
          . Octium::joinseries(@stoplist_links)
          . ' are also available.';
    }

    $fullnote .= '</p>';

    # This was under lines 13 - special days notes, but has been moved here
    # because the PHP code is apparently broken

    my ( %specday_of_specdayletter, %trips_of_letter,
        @specdayletters, @noteletters, @lines );

    #    foreach my $daysexception ( $self->daysexceptions ) {
    #        next unless $daysexception;
    #        my ( $specdayletter, $specday ) = split( / /, $daysexception, 2 );
    #        $specday_of_specdayletter{$specdayletter} = $specday;
    #    }

    foreach my $trip ( $self->trips ) {

        my $daysexception = $trip->daysexceptions;

        my $tripdays = $trip->days_obj;
        my ( $specdayletter, $specday )
          = $tripdays->specday_and_specdayletter($days);

        if ($daysexception) {
            my ( $dspecdayletter, $dspecday ) = split( / /, $daysexception, 2 );
            $specday_of_specdayletter{$dspecdayletter} = $dspecday;
            push @specdayletters, $specdayletter;
            push @{ $trips_of_letter{$dspecdayletter} }, $trip;
        }
        elsif ($specdayletter) {
            $specday_of_specdayletter{$specdayletter} = $specday;
            push @specdayletters, $specdayletter;
            push @{ $trips_of_letter{$specdayletter} }, $trip;
        }
        else {
            push @specdayletters, $EMPTY;
        }

        push @noteletters, $EMPTY;
        push @lines,       $trip->line;

    }    ## tidy end: foreach my $trip ( $self->trips)

    my ( @specdaynotes, @specdaytrips );

    foreach my $noteletter ( keys %specday_of_specdayletter ) {

        my $specday = $specday_of_specdayletter{$noteletter};

        push @specdaynotes,
            '<p>'
          . $noteletter
          . ' &mdash; '
          . $specday_of_specdayletter{$noteletter} . '</p>';

        my @trips = $trips_of_letter{$noteletter}->@*;

        my $specdaytrip = $specday =~ s/\.*\z/:/r;
        $specdaytrip = "<dt>$specdaytrip</dt>";

        foreach my $trip (@trips) {

            my @placetimes = $trip->placetimes;
            my $idx        = Octium::firstidx {defined} @placetimes;
            my $time       = Actium::Time->from_num( $placetimes[$idx] )->ap;

            $specdaytrip .= "<dd>Trip leaving $placedescs[$idx] at $time</dd>";

        }

        push @specdaytrips, $specdaytrip;

    }    ## tidy end: foreach my $noteletter ( keys...)

    @specdaytrips = sort @specdaytrips;

    #$p->(@specdaynotes);

    #$fullnote .= Octium::joinempty(@specdaynotes);

    if (@specdaytrips) {
        $fullnote .= '<dl>' . Octium::joinempty(@specdaytrips) . '</dl>';
    }

    $p->( $fullnote, $linegroup_row_r->{LineGroupNote} );

    # lines 12 - current or upcoming schedule equivalent. Not used

    $p->('');

    # lines 13 - Definitions of special day codes

    $p_blank->();    # special day notes, moved above

    # FLIPPING NOTE LETTERS AND SPECIAL DAY CODES TO SEE IF THAT WORKS

    # lines 14  - special day code for each trip

    # $p->(@specdayletters);
    # lines 15 - note letters for each trip

    $p->(@noteletters);

    $p->(@specdayletters);

    # lines 16 - lines

    $p->(@lines);

    # lines 17 - times

    my $placetimes_aoa = Octium::O::2DArray->new;

    foreach my $trip ( $self->trips ) {
        my @placetimes = map { Actium::Time->from_num($_)->ap_noseparator }
          $trip->placetimes;
        $placetimes_aoa->push_col(@placetimes);
    }

    # so, the old program had a bug, I think, that added an extra tab
    # to every line.

    # Here we are being bug-compatible.

    $placetimes_aoa->push_col( $EMPTY x $placetimes_aoa->height() );

    return $aoa->tsv . $placetimes_aoa->tsv;

}    ## tidy end: method tabxchange

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

