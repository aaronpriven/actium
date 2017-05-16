__END__

###################
### STOP OBJECTS

# An earlier attempt at replacing some of the work done by
# kpoints and flagspecs, I believe

sub stop_objects {
    my $self = shift;

    my @stopplaces = map {s/-[AD12]$//} $self->stopplaces;
    my @stopids    = $self->stopids;
    my $stopcount  = $self->stop_count;

    my ( @stop_objs, @time_objs );

    foreach my $trip ( $self->trips ) {

        my $tripdays = $trip->days_obj;

        my @times = $trip->stoptimes;

        my ( $origin,     $destination, $previous_place );
        my ( @previouses, @followers,   @newtimes );
        my $previous_place_idx = 0;

        for my $stop_idx ( 0 .. $stopcount ) {

            my $time         = $times[$stop_idx];
            my $stopid       = $stopids[$stop_idx];
            my $previous_idx = $stop_idx - 1;
            my $stopplace    = $stopplaces[$stop_idx];

            #### Check -- same stop as last time?
            #### If so, and last entry has values, copy them over.

            if (    $stop_idx
                and $newtimes[$previous_idx]
                and $stopid eq $stopids[$previous_idx] )
            {
                # This stop has the same stop id
                # as the previous stop, and
                # the previous time was valid.

                if ( not defined $time ) {
                    # if only the previous stop had a time, move that entry
                    # forward to this entry, and go to the next one.
                    splice( @newtimes,   -1, 0, undef );
                    splice( @previouses, -1, 0, undef );
                    if ( $followers[$previous_idx] ) {
                        splice( @followers, -1, 0, undef );
                    }
                    next;
                }

                if ( u::isempty($stopplace) ) {
                    # If this stop has a time but no place, and the previous
                    # stop had a place,
                    # use the previous place and go to the next stop.
                    splice( @previouses, -1, 0, undef );
                    if ( $followers[$previous_idx] ) {
                        splice( @followers, -1, 0, undef );
                    }
                    undef $newtimes[$previous_idx];
                    $newtimes[$stop_idx] = $time;
                    next;
                }

                # otherwise, just null out the previous entry as though
                # it was never there.

                undef $previouses[$previous_idx];
                undef $followers[$previous_idx];
                undef $newtimes[$previous_idx];

            } ## tidy end: if ( $stop_idx and $newtimes...)

            ###

            next unless defined($time);

            $newtimes[$stop_idx] = $time;

            if ( u::isempty($stopplace) ) {
                # Not a timepoint
                $previouses[$stop_idx] = $previous_place;
            }
            else {
                # Is a timepoint

                my $place = $stopplace;
                $previouses[$stop_idx] = $place;
                $followers[$stop_idx]  = $place;

                if ( defined $origin ) {
                    # Timepoint after the origin
                    $destination = $place;
                    # That gets set for every place until the last one

                    my @followers_to_set
                      = ( $previous_place_idx + 1 .. $stop_idx - 1 );
                    foreach my $j (@followers_to_set) {
                        next unless $previouses[$j];
                        $followers[$j] = $place;
                    }

                    $previous_place_idx = $stop_idx;

                }
                else {
                    # Origin timepoint
                    $origin         = $place;
                    $previous_place = $place;
                }

            } 

        } ## tidy end: for my $stop_idx ( 0 .....)

        for my $stop_idx ( 0 .. $stopcount ) {
            next unless $newtimes[$stop_idx];
            push @{ $time_objs[$stop_idx] },
              Actium::O::Sked::Stop::Time->new(
                {   origin      => $origin,
                    destination => $destination,
                    follower    => $followers[$stop_idx],
                    previous    => $previouses[$stop_idx],
                    days        => $self->days_obj,
                    times       => $newtimes[$stop_idx],
                    line        => $self->line,
                    stop_index  => $stop_idx,
                }
              );
        }

    } ## tidy end: foreach my $trip ( $self->trips)

    for my $stop_idx ( 0 .. $stopcount ) {
        next unless $time_objs[$stop_idx];
        push @stop_objs,
          Actium::O::Sked::Stop->new(
            {   time_objs => $time_objs[$stop_idx],
                direction => $self->dir_obj,
                days      => $self->days_obj,
                linegroup => $self->linegroup,
            }
          );
    }

    return @stop_objs;

} ## tidy end: sub stop_objects

