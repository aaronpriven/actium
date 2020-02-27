#!/usr/bin/env perl
#
# It's been a little bit -- I think this was created to fake up
# trip patterns for the Dumbarton service

use 5.024;
use autodie;
use feature 'refaliasing';
no warnings 'experimental::refaliasing';

my @tpat_fields = qw/
  tpat_assign     tpat_direction          tpat_distance        tpat_driv_inst
  tpat_first_tp   tpat_id tpat_in_serv    tpat_last_tp         tpat_route
  tpat_sysrecno   tpat_trips_match        tpat_veh_display     tpat_via
  /;

open my $trip, '<', 'trip.txt';

my $headerline = <$trip>;
chomp $headerline;
my @headers = split( /\t/, $headerline );

my %tpat;

while (<$trip>) {
    chomp;
    my %trip;
    my @values = split( /\t/, $_ );
    @trip{@headers} = @values;

    my $pat_id = $trip{trp_pattern};

    $tpat{$pat_id}{tpat_assign}      = "01/01/01";
    $tpat{$pat_id}{tpat_direction}   = $trip{tpat_direction};
    $tpat{$pat_id}{tpat_distance}    = 1;
    $tpat{$pat_id}{tpat_driv_inst}   = "Instructions";
    $tpat{$pat_id}{tpat_first_tp}    = "N/A";
    $tpat{$pat_id}{tpat_id}          = $pat_id;
    $tpat{$pat_id}{tpat_in_serv}     = $trip{tpat_direction} ? 1 : 0;
    $tpat{$pat_id}{tpat_last_tp}     = "N/A";
    $tpat{$pat_id}{tpat_route}       = $trip{tpat_route};
    $tpat{$pat_id}{tpat_sysrecno}    = $pat_id;
    $tpat{$pat_id}{tpat_veh_display} = 1;
    $tpat{$pat_id}{tpat_via}         = 1;
    $tpat{$pat_id}{tpat_trips_match}++;

} ## tidy end: while (<$trip>)

close $trip;

open my $tpat,  '>', 'trip_pattern.txt';
open my $xtpat, '>', '../TripPatterns.xml';

say $xtpat '<?xml version="1.0" encoding="utf-8"?>';
say $xtpat
  '<TripPatterns xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">';

say $tpat join( "\t", @tpat_fields );

foreach my $pat_id ( sort { $a <=> $b } keys %tpat ) {
    \my %thispat = $tpat{$pat_id};
    say $tpat join( "\t", @thispat{@tpat_fields} );

    say $xtpat "<trip_pattern>";
    foreach my $field (@tpat_fields) {
        say $xtpat "  <$field>", $thispat{$field}, "</$field>";
    }
    say $xtpat "</trip_pattern>";

}

say $xtpat "</TripPatterns>";

close $tpat;
close $xtpat;

