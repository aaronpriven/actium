package Octium::Cmd::AVL2Points 0.013;

use Actium;
use Octium;
use sort ('stable');    ### DEP ###
use Storable();         ### DEP ###

use Octium::Set('ordered_union');
use Actium::Time;

const my @COMBOS_TO_PROCESS => (
    [qw( 5 6 56 )],     [qw( 1 234 1234 )], [qw( 1234 5 12345 )],
    [qw( 234 5 2345 )], [qw( 6 7 67 )],     [qw( 12345 67 1234567 )],
);

const my $KEY_SEPARATOR => "\c]";

sub joinkey {
    return join( $KEY_SEPARATOR, map { $_ // q[] } @_ );
}

sub OPTIONS {
    return qw/actiumdb signup/;
}

sub HELP {

    my $helptext = <<'EOF';
avl2points reads the data written by readavl and turns it into 
a list of times that buses pass each stop.
It is saved in the directory "kpoints" in the directory for that signup.
EOF

    print $helptext;
    return;
}

sub START {

    my ($class) = @_;
    my $actiumdb = env->actiumdb;

    my ( %stops, %cities );

    $actiumdb->load_tables(
        requests => {
            Cities => {
                hash        => \%cities,
                index_field => 'City',
                fields      => [qw[City Side]],
            },
            Stops_Neue => {
                hash        => \%stops,
                index_field => 'h_stp_511_id',
                fields      => [qw[h_stp_511_id c_city ]],
            },
        }
    );

    my $signup = env->signup;
    chdir $signup->path();

    # retrieve data

    my ( %stopinfo, %note_of );

    {    # more scoping

        my $somedata_r;

        {    # scoping

            my $avldata_r = $signup->retrieve('avl.storable');

            foreach (qw<PAT TRP>) {
                $somedata_r->{$_} = $avldata_r->{$_};
            }

        }

        %stopinfo = makestoptimes($somedata_r);

    }

    print "Combining combo routes...\n";

    #my %combo_of = (
    #    qw<
    #      L   LC      LA  LC
    #      NX1 NC      NX2 NC     NX3 NC   >
    #);

    my %combo_of = ( '-', '--' );

    my %is_combo;
    $is_combo{$_}++ foreach values %combo_of;

    foreach my $stop ( sort keys %stopinfo ) {

        foreach my $combolg ( sort keys %{ $stopinfo{$stop} } ) {

            if ( $is_combo{$combolg} ) {
                foreach my $singlelg ( sort keys %{ $stopinfo{$stop} } ) {
                    if (    $combo_of{$singlelg}
                        and $combo_of{$singlelg} eq $combolg )
                    {

                        foreach my $dir_code (
                            sort keys %{ $stopinfo{$stop}{$combolg} } )
                        {
                            foreach my $days (
                                sort
                                keys %{ $stopinfo{$stop}{$combolg}{$dir_code} }
                              )
                            {
                                foreach my $time_r (
                                    @{  $stopinfo{$stop}{$combolg}{$dir_code}
                                          {$days}
                                    }
                                  )
                                {
                                    $time_r->{LINE} = $singlelg;
                                    push
                                      @{ $stopinfo{$stop}{$singlelg}{$dir_code}
                                          {$days} }, $time_r;

                                 # TODO - override destinations, so that
                                 # it doesn't say "L to Hilltop Mall" or
                                 # "NX2 to Castro Valley" -- but for now
                                 # this is irrelevant as that will be overridden
                                 # by DROPOFF anyway (no locals on L, NX2, NX3)

                                }

                            }    ## tidy end: foreach my $days ( sort keys...)

                        }    ## <perltidy> end foreach my $dir_code ( keys...)

                    }    ## <perltidy> end if ( $combo_of{$singlelg...})
                }    ## <perltidy> end foreach my $singlelg ( keys...)
                delete $stopinfo{$stop}{$combolg};
            }    ## <perltidy> end if ( $is_combo {$combolg...})

        }    ## <perltidy> end foreach my $combolg ( keys ...)

    }    ## <perltidy> end foreach my $stop ( keys %stopinfo)

    # now each of $stopinfo{$stop}{$linegroup}{$dir_code}{$days}[0..n]
    # is a hashref, with the keys TIME , DESTINATION, and LINE

    print "Sorting times and merging days...\n";

    #my @nolocals = qw<FS L NX NX1 NX2 NX3 OX U W>;
    my @nolocals = @TRANSBAY_NOLOCALS;    # from Actium
    my %is_a_nolocal_route;
    $is_a_nolocal_route{$_} = 1 foreach @nolocals;

    #my @routenotes = qw<1R 72R>;
    my @routenotes = ();
    my %is_a_routenote;
    $is_a_routenote{$_} = 1 foreach @routenotes;

    foreach my $stop ( sort keys %stopinfo ) {

        next if ( $stops{$stop}{c_city} =~ /Virtual/i );

        foreach my $linegroup ( sort keys %{ $stopinfo{$stop} } ) {

            my ( %has_last_stop, %has_non_last_stop );

            # processing times within each day
            foreach my $dir_code ( sort keys %{ $stopinfo{$stop}{$linegroup} } )
            {

                my %concatenated;

                foreach my $days (
                    sort keys %{ $stopinfo{$stop}{$linegroup}{$dir_code} } )
                {

                    my @times_hr
                      = @{ $stopinfo{$stop}{$linegroup}{$dir_code}{$days} };

                    # sort @times_hr first by time, then by line, then by dest

                    @times_hr = sort {
                             ( timenum( $a->{TIME} ) <=> timenum( $b->{TIME} ) )
                          or $a->{LINE} cmp $b->{LINE}
                          or $a->{DESTINATION} cmp $b->{DESTINATION}
                    } @times_hr;

                    $stopinfo{$stop}{$linegroup}{$dir_code}{$days} = \@times_hr;

                    my @each_time_concat = map {
                        join( ':', $_->{TIME}, $_->{LINE}, $_->{DESTINATION} )
                    } @times_hr;

                    $concatenated{$days} = join( ':', @each_time_concat );

                }    ## <perltidy> end foreach my $days ( keys %{ ...})

                # merge days (columns with times)

                foreach my $combo (@COMBOS_TO_PROCESS) {
                    my ( $from1, $from2, $to ) = @{$combo};

                    if (    exists( $concatenated{$from1} )
                        and exists( $concatenated{$from2} )
                        and $concatenated{$from1} eq $concatenated{$from2} )
                    {

                        $concatenated{$to} = $concatenated{$from1};
                        $stopinfo{$stop}{$linegroup}{$dir_code}{$to}
                          = $stopinfo{$stop}{$linegroup}{$dir_code}{$from1};

                        delete $concatenated{$from1};
                        delete $concatenated{$from2};
                        delete $stopinfo{$stop}{$linegroup}{$dir_code}{$from1};
                        delete $stopinfo{$stop}{$linegroup}{$dir_code}{$from2};

                    }

                }    ## tidy end: foreach my $combo (@COMBOS_TO_PROCESS)

                # LAST STOP PROCESSING

              DAYS_NOTESLOOP:
                foreach my $days (
                    sort keys %{ $stopinfo{$stop}{$linegroup}{$dir_code} } )
                {

                    # loop - deal with final stops. Add notes

                    my $times_r
                      = $stopinfo{$stop}{$linegroup}{$dir_code}{$days};

                    # DROPOFF

                    if ( $is_a_nolocal_route{$linegroup} ) {

                        my $city = $stops{$stop}{c_city};
                        my $side = $cities{$city}{Side};

                 #if ( (not (defined $side)) and (fc($city) ne fc('Virtual'))) {
                        if ( not defined $side ) {

                            warn "No side for city $city";

                        }
                        else {

                            if (   $side eq 'E' and $dir_code eq '2'
                                or $side eq 'W' and $dir_code eq '3' )
                            {

                                $note_of{"$stop:$linegroup:$dir_code:$days"}
                                  {NOTE} = "DROPOFF";
                                $has_last_stop{$linegroup} = 1;

                            }
                        }

                    }    ## tidy end: if ( $is_a_nolocal_route...)
                    elsif
                      # LASTSTOP
                      ( Actium::all { $_->{LASTSTOP} } @{$times_r} ) {

          #if ( Actium::all { $_->{PLACE} eq $_->{DESTINATION} } @{$times_r} ) {
                        $has_last_stop{$linegroup} = 1;
                        $note_of{"$stop:$linegroup:$dir_code:$days"}{NOTE}
                          = "LASTSTOP";
                    }
                    else {

                        $has_non_last_stop{$linegroup} = 1;
                        foreach my $i ( reverse 0 .. $#{$times_r} ) {

                            #if ( $times_r->[$i]->{PLACE} eq
                            #    $times_r->[$i]->{DESTINATION} )

                            if ( $times_r->[$i]->{LASTSTOP} ) {
                                splice( @{$times_r}, $i, 1 );
                            }
                        }
                    }

                    # TODO - figure out how to do line U

                    if ( $is_a_routenote{$linegroup} ) {
                        $note_of{"$stop:$linegroup:$dir_code:$days"}{NOTE}
                          = $linegroup;
                    }

                    if ( $note_of{"$stop:$linegroup:$dir_code:$days"} ) {

                        my ( %lines, %destinations );
                        foreach my $time_r (
                            @{ $stopinfo{$stop}{$linegroup}{$dir_code}{$days} }
                          )
                        {
                            $lines{ $time_r->{LINE} }++;
                            $destinations{ $time_r->{DESTINATION} }++;
                        }

                        my @lines = Actium::sortbyline keys %lines;
                        my @destinations
                          = sort { $destinations{$b} <=> $destinations{$a} }
                          keys %destinations;

                        $note_of{"$stop:$linegroup:$dir_code:$days"}{INFO}
                          = join( ":", @lines ) . "\t"
                          . join( ":", @destinations );

                        $note_of{"$stop:$linegroup:$dir_code:$days"}{COMP}
                          = $note_of{"$stop:$linegroup:$dir_code:$days"}{NOTE}
                          . join( ":", @lines )
                          . "\t$destinations[0]";

                    }    ## <perltidy> end if ( $note_of{...})

                }    ## <perltidy> end foreach my $days ( keys %{ ...})

                # merge notes

                foreach my $combo (@COMBOS_TO_PROCESS) {
                    my ( $from1, $from2, $to ) = @{$combo};

                    if (    $note_of{"$stop:$linegroup:$dir_code:$from1"}
                        and $note_of{"$stop:$linegroup:$dir_code:$from2"}
                        and $note_of{"$stop:$linegroup:$dir_code:$from1"}{COMP}
                        eq $note_of{"$stop:$linegroup:$dir_code:$from2"}{COMP} )
                    {

                        $stopinfo{$stop}{$linegroup}{$dir_code}{$to}
                          = $stopinfo{$stop}{$linegroup}{$dir_code}{$from1};
                        $note_of{"$stop:$linegroup:$dir_code:$to"}
                          = $note_of{"$stop:$linegroup:$dir_code:$from1"};

                        delete $note_of{"$stop:$linegroup:$dir_code:$from1"};
                        delete $note_of{"$stop:$linegroup:$dir_code:$from2"};
                        delete $stopinfo{$stop}{$linegroup}{$dir_code}{$from1};
                        delete $stopinfo{$stop}{$linegroup}{$dir_code}{$from2};

                    }

                }    ## tidy end: foreach my $combo (@COMBOS_TO_PROCESS)

                # above handles all of 1R except the parts heading northbound
                # to downtown Oakland (which has mixed destinations)

                if (    $note_of{"$stop:$linegroup:$dir_code:67"}
                    and $note_of{"$stop:$linegroup:$dir_code:12345"}
                    and $note_of{"$stop:$linegroup:$dir_code:67"}{NOTE} eq '1R'
                    and $note_of{"$stop:$linegroup:$dir_code:12345"}{NOTE} eq
                    '1R' )
                {

          # we know they are different destinations because otherwise they would
          # already be merged

                    $stopinfo{$stop}{$linegroup}{$dir_code}{'1234567'}
                      = $stopinfo{$stop}{$linegroup}{$dir_code}{'12345'};
                    $note_of{"$stop:$linegroup:$dir_code:1234567"}
                      = $note_of{"$stop:$linegroup:$dir_code:12345"};

                    $note_of{"$stop:$linegroup:$dir_code:1234567"}{NOTE}
                      = '1R-MIXED';

                    delete $note_of{"$stop:$linegroup:$dir_code:12345"};
                    delete $note_of{"$stop:$linegroup:$dir_code:67"};
                    delete $stopinfo{$stop}{$linegroup}{$dir_code}{'12345'};
                    delete $stopinfo{$stop}{$linegroup}{$dir_code}{'67'};

                } ## tidy end: if ( $note_of{"$stop:$linegroup:$dir_code:67"...})

            }    ## <perltidy> end foreach my $dir_code ( keys...)

            if ( $has_non_last_stop{$linegroup} and $has_last_stop{$linegroup} )
            {

     # if there are both last-stop and non-last-stop columns for this linegroup,
     # delete the last-stop columns

                foreach
                  my $dir_code ( sort keys %{ $stopinfo{$stop}{$linegroup} } )
                {

                    foreach my $days (
                        sort keys %{ $stopinfo{$stop}{$linegroup}{$dir_code} } )
                    {

                        if (    $note_of{"$stop:$linegroup:$dir_code:$days"}
                            and
                            $note_of{"$stop:$linegroup:$dir_code:$days"}{NOTE}
                            eq "LASTSTOP" )
                        {
                            delete $stopinfo{$stop}{$linegroup}{$dir_code}
                              {$days};
                            delete $note_of{"$stop:$linegroup:$dir_code:$days"};
                        }

                    }

                }    ## tidy end: foreach my $dir_code ( sort...)

            }    ## <perltidy> end if ( $has_non_last_stop...)

        }    ## <perltidy> end foreach my $linegroup ( keys...)

    }    ## <perltidy> end foreach my $stop ( keys %stopinfo)

    print "Reassembled. Now outputting...\n";

    my $kpointdir = $signup->subfolder('kpoints');

    my $count = 0;

    foreach my $stop ( sort keys %stopinfo ) {

        $count++;
        print '.' unless $count % 100;

        my $firstdigits = substr( $stop, 0, 3 );

        my $citydir = $kpointdir->subfolder("${firstdigits}xx");

        open my $out, '>', "kpoints/${firstdigits}xx/$stop.txt" or die $!;

        foreach my $linegroup ( Actium::sortbyline keys %{ $stopinfo{$stop} } )
        {

            foreach my $dir_code (
                sort { $a <=> $b }
                keys %{ $stopinfo{$stop}{$linegroup} }
              )
            {

                foreach my $days (
                    sort keys %{ $stopinfo{$stop}{$linegroup}{$dir_code} } )
                {

                    next
                      if $days eq '1245'
                      or $days eq '1235'
                      or ( $linegroup =~ /\d\d/ and $days eq '1234' );
                    # skip school trips... this is wrong but will probably
                    # not be fixed in the version that comes from avl

                    print $out "$linegroup\t$dir_code\t$days";

                    my $note
                      = $note_of{"$stop:$linegroup:$dir_code:$days"}{NOTE};
                    if ($note) {
                        print $out "\t#$note\t";
                        print $out $note_of{"$stop:$linegroup:$dir_code:$days"}
                          {INFO};
                    }
                    else {
                        foreach my $time_r (
                            @{ $stopinfo{$stop}{$linegroup}{$dir_code}{$days} }
                          )
                        {

                            #print "$stop:$linegroup:$dir_code:$days\n";
                            print $out "\t",
                              join( ':',
                                $time_r->{TIME},        $time_r->{LINE},
                                $time_r->{DESTINATION}, $time_r->{PLACE},
                                $time_r->{DAYEXCEPTIONS} );

                        }

                    }
                    print $out "\n";

                }    ## <perltidy> end foreach my $days ( sort keys...)

            }    ## <perltidy> end foreach my $dir_code ( sort...)

        }    ## <perltidy> end foreach my $linegroup ( sort...)

        close $out or die $!;

    }    ## <perltidy> end foreach my $stop ( keys %stopinfo)

    print "\nDone.\n";

}    ## tidy end: sub START

sub makestoptimes {
    my %avldata = %{ +shift };

    my %stopinfo;

  TRIP:

    foreach my $trip_number ( sort keys %{ $avldata{TRP} } ) {
        my $trip_of_r   = $avldata{TRP}{$trip_number};
        my %tripinfo_of = %{$trip_of_r};
        next TRIP unless $tripinfo_of{IsPublic};

        my $line = $tripinfo_of{RouteForStatistics};
        next TRIP if $line eq '399';    # supervisor order

        next TRIP if $tripinfo_of{IsSpecial} and $line !~ m/^6\d\d/;
        # HORRIBLE KLUDGE to avoid school day only trips on regular lines
        # in pole schedules

        my $linegroup = linegroup($line);

        my $pattern = $tripinfo_of{Pattern};
        my $patkey = joinkey( $line, $pattern );

        my $days_input = $tripinfo_of{OperatingDays};
        $days_input =~ tr/0-9//cd;    # strip everything but digits

        my @days;

        ### the following changes 800 and 801 times that start on the
        ### following day to the current day

        if ( $line eq '800' or $line eq '801' ) {
            my $initial_time = $tripinfo_of{PTS}[0];

            if ( $initial_time =~ /\d+ x/x )
            {    # if first time is an "x" time (am next day)

                tr/x/a/ foreach @{ $tripinfo_of{PTS} };

                for ($days_input) {
                    if ( $_ eq '7' ) {
                        @days = '1';
                        next;
                    }
                    if ( $_ eq '6' ) {
                        @days = '7';
                        next;
                    }
                    if ( $_ eq '12345' ) {
                        @days = qw(234 5 6 );
                        next;
                    }
                }
            }    ## tidy end: if ( $initial_time =~ ...)
            elsif ( $initial_time =~ /\d+ p/x )
            {    # if first time is an "p" time (pm that day)
                tr/px/ba/ foreach @{ $tripinfo_of{PTS} };
                for ($days_input) {
                    if ( $_ eq '7' ) {
                        @days = '6';
                        next;
                    }
                    if ( $_ eq '6' ) {
                        @days = '5';
                        next;
                    }
                    if ( $_ eq '12345' ) {
                        @days = qw(7 1 234);
                        next;
                    }
                }
            }

            #         elsif ($days_input eq '12345') {
            #            @days = qw(1 234 5);
            #         }
            else {
                @days = ($days_input);
            }

        }    ## tidy end: if ( $line eq '800' or...)
        else {
            @days = ($days_input);
        }

        # END OF 800/801 day-changing code

        my $dir_code = $avldata{PAT}{$patkey}{DirectionValue};

        my @tps = @{ $avldata{PAT}{$patkey}{TPS} };

        #my $final_tps   = $tps[-1];
        my $final_tps   = pop @tps;
        my $final_place = remove_place_suffixes( $final_tps->{Place} );

        my $final_stop_of_pattern;

        my $prevstop = '';
      TIMEIDX:
        foreach my $timeidx ( 0 .. $#{ $tripinfo_of{PTS} } ) {
            my $stop = $avldata{PAT}{$patkey}{TPS}[$timeidx]{StopIdentifier};

            next TIMEIDX if $stop =~ /^D/i;

            $final_stop_of_pattern = $stop;

            my $place = $avldata{PAT}{$patkey}{TPS}[$timeidx]{Place};
            $place = remove_place_suffixes($place);

            my $time = $tripinfo_of{PTS}[$timeidx];
            $time =~ s/^0//;

            foreach my $days (@days) {

                if ( $stop eq $prevstop ) {
                    pop @{ $stopinfo{$stop}{$linegroup}{$dir_code}{$days} };
                }
                # remove previous stop data if this is the same stop.
                # in other words, show departure, not arrival time

                push @{ $stopinfo{$stop}{$linegroup}{$dir_code}{$days} }, {
                    TIME          => $time,
                    DESTINATION   => $final_place,
                    LINE          => $line,
                    PLACE         => $place,
                    DAYEXCEPTIONS => '',             # TODO add later
                      #                LASTSTOP      => ($timeidx == $#{ $tripinfo_of{PTS} } ),
                };

            }

            $prevstop = $stop;

        }    ## <perltidy> end foreach my $timeidx ( 0 .. ...)

        foreach my $days (@days) {
            $stopinfo{$final_stop_of_pattern}{$linegroup}{$dir_code}{$days}[-1]
              {LASTSTOP} = 1;
        }

    }    ## tidy end: TRIP: foreach my $trip_number ( sort...)

    return %stopinfo;

}    ## <perltidy> end sub makestoptimes

sub linegroup {
    return wantarray ? @_ : $_[0];

    # at the moment, simply returns its arguments.
    # At some point we will want to change this,
    # to allow for joining lines into linegroups.
    # But not today.

}

sub remove_place_suffixes {
    my $place = shift;
    $place =~ s/-[AD12]$//;
    return $place;
}

func timenum ($time) {
    return Actium::Time->from_str($time)->timenum;
}

1;

__END__

=head1 NAME

avl2points - makes list of times that buses pass each stop;

=head1 DESCRIPTION

avl2points reads the data written by readavl and turns it into  a list
of times that buses pass each stop. It is saved in the directory
"kpoints" in the directory for that signup.

=head1 AUTHOR

Aaron Priven

=cut


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

