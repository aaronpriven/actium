package Octium::Sked::StopSkedMaker 0.013;
#vimcolor: #002600

use Actium ('role');

my ( @has_a_time, $patternkey, @stopids, %stopinfo_of_pattern, @stopplaces,
    @stoptimes, );

func _stoptrip ( :$trip, :$stop_idx, :\%stopinfo ) {

    my $stoppattern = Octium::Sked::StopTrip::StopPattern->new(
        destination_place => $stopinfo{destination_place},
        place_in_effect   => $stopinfo{places_in_effect}[$stop_idx],
        is_at_place       => $stopinfo{is_at_places}[$stop_idx],
        next_place        => $stopinfo{next_places}[$stop_idx],
        ensuingstops      => $stopinfo{ensuingstops}[$stop_idx],
    );

    my %stoptripspec = (
        time        => Actium::Time->from_num( $trip->stoptime($stop_idx) ),
        line        => $trip->line,
        days        => $trip->days,
        calendar_id => $trip->daysexceptions,
        stoppattern => $stoppattern,
    );

    return Octium::Sked::StopTrip->new( \%stoptripspec );

}

func _make_stoppattern {

    my %stopinfo;

    # reverse loop gets @next_places, @ensuingstops

    my $next_place = $EMPTY;
    my ( @these_ensuingstops, %seen_stop );

    for my $stop_idx ( reverse( 0 .. $#stoptimes ) ) {
        next unless $has_a_time[$stop_idx];

        # Skip stops that are duplicates.  Take the latest instance
        # that the bus passes this stop, unless the latest instance is
        # the very last stop. This will make sure that
        # arrival/departure pairs always use the departure times, and
        # also weird curling-back-on-itself loops use the last time it
        # passes the stop, but regular
        # loops that begin and end at the same point will use the first
        # time, not the last one.

        my $stopid = $stopids[$stop_idx];
        if ( not exists $seen_stop{$stopid} ) {
            $seen_stop{$stopid} = $stop_idx == $#stoptimes ? 'SKIP' : 'LAST';
        }
        elsif ( $seen_stop{$stopid} eq 'LAST' ) {
            # seen this stop before, and it was the last stop
            # have it skip the last stop, and then change it so
            # it's seen this one
            $stopinfo{skip_stop}[$#stoptimes] = 1;
            $stopinfo{seen_stop}{$stopid} = 'SKIP';
        }
        else {    # ( $seen_stop{$stopid} eq 'SKIP' )
                  # seen this stop before, and it was not the last stop
            $stopinfo{skip_stop}[$stop_idx] = 1;
            next;
        }

        $stopinfo{ensuingstops}[$stop_idx]
          = Octium::Sked::StopTrip::EnsuingStops->new( [@these_ensuingstops] );
        $stopinfo{next_places}[$stop_idx] = $next_place;

        push @these_ensuingstops, $stopids[$stop_idx];
        $next_place = $stopplaces[$stop_idx] if $stopplaces[$stop_idx];
    }

    # forward loop gets $destination_place, @places_in_effect,
    # @is_at_places

    my $prev_place = $EMPTY;
    for my $stop_idx ( 0 .. $#stoptimes ) {
        next
          if $stopinfo{skip_stop}[$stop_idx]
          or not $has_a_time[$stop_idx];
        $stopinfo{is_at_places}[$stop_idx]
          = ( not not $stopplaces[$stop_idx] );
        $stopinfo{places_in_effect}[$stop_idx]
          = $stopplaces[$stop_idx] || $prev_place;
        $prev_place = $stopinfo{places_in_effect}[$stop_idx];
    }
    $stopinfo{destination_place} = $prev_place;

    return $stopinfo_of_pattern{$patternkey} = \%stopinfo;

}

method stopskeds {

    require Octium::Sked::StopSked;
    require Octium::Sked::StopTrip;
    require Octium::Sked::StopTrip::StopPattern;
    require Octium::Sked::StopTrip::EnsuingStops;

    my %trips_of_stop;

    @stopids    = $self->stopids;
    @stopplaces = $self->stopplaces;

    # go through each trip and build all the sked trips

    my @trips = $self->trips;
    undef %stopinfo_of_pattern;

  TRIP:
    foreach my $trip_idx ( 0 .. $#trips ) {
        my $trip = $trips[$trip_idx];
        @stoptimes  = $trip->stoptimes;
        @has_a_time = map { defined $_ ? 1 : 0 } @stoptimes;
        $patternkey = join( '', @has_a_time );
        my $line = $trip->line;

        my %stopinfo;

        if ( not exists $stopinfo_of_pattern{$patternkey} ) {
            \%stopinfo = _make_stoppattern();
        }
        else {
            \%stopinfo = $stopinfo_of_pattern{$patternkey};
        }

        for my $stop_idx ( 0 .. $#stoptimes ) {
            next if $stopinfo{skip_stop}[$stop_idx];

            if ( not $has_a_time[$stop_idx] ) {
                next if $stop_idx == 0;

                # This combines arrival/departure columns into one.
                # If there is no time, and the previous stop is the same as
                # this one, and that one has a time and isn't marked skip, use
                # that time instead.

                my $stop_idx_prev = $stop_idx - 1;
                next
                  if ( not $has_a_time[$stop_idx_prev]
                    or $stopids[$stop_idx] ne $stopids[$stop_idx_prev] )
                  or $stopinfo{skip_stop}[$stop_idx_prev];

                push $trips_of_stop{$line}{ $stopids[$stop_idx_prev] }->@*,
                  _stoptrip(
                    stopinfo => \%stopinfo,
                    stop_idx => $stop_idx_prev,
                    trip     => $trip,
                  );

                next;

            }

            push $trips_of_stop{$line}{ $stopids[$stop_idx] }->@*,
              _stoptrip(
                stopinfo => \%stopinfo,
                stop_idx => $stop_idx,
                trip     => $trip,
              );

        }
    }

    my @stopskeds;

    foreach my $line ( keys %trips_of_stop ) {

        push @stopskeds, map {
            Octium::Sked::StopSked->new(
                stopid => $_,
                dir    => $self->dir_obj,
                days   => $self->days,
                trips  => $trips_of_stop{$line}{$_},
            );
        } ( keys $trips_of_stop{$line}->%* );

        return @stopskeds;

    }

}

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use <name>;
 # do something with <name>

=head1 DESCRIPTION

A full description of the module and its features.

=head1 CLASS METHODS

=head2 method

Description of method.

=head1 OBJECT METHODS or ATTRIBUTES

=head2 method

Description of method.

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

The Actium system, and...

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues|https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2020

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item *

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item *

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

