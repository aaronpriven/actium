package Actium::Frequency 0.010;

use Actium::Preamble;
use Actium::O::2DArray;
use Actium::O::Time;
use Math::Round('nearest');    ### DEP ###

my $earliest = Actium::O::Time->from_str('NOON_YESTERDAY')->timenum;
my $latest   = Actium::O::Time->from_str('NOON_TOMORROW')->timenum;

sub break_sets {
    my $breaks = shift;
    \my @timenums = shift;

    if ( not defined $breaks ) {
        return ( [ \@timenums ], [undef] );
    }

    my @objs = u::uniq( Actium::O::Time->from_str( split( /,/, $breaks ) ) );

    my @objs_with_num = sort { $a->[1] <=> $b->[1] }
      map { [ $_, $_->timenum ] } @objs;

    # a partial Schwarzian transform, only I keep the list around so I can
    # store the values in @breaknums

    my @breaktimes = map { $_->[0]->ap } @objs_with_num;

    unshift @breaktimes, Actium::O::Time::->from_num( $timenums[0] )->ap;

    my @breaknums = map { $_->[1] } @objs_with_num;
    @breaknums = ( $earliest, @breaknums, $latest );

    # so there is always a first break and a last one

    my @sets;

    foreach my $timenum (@timenums) {
        if ( $timenum < $breaknums[0] ) {
            push @{ $sets[-1] }, $timenum;
            next;
        }

        push @sets, [$timenum];
        shift @breaknums;
    }

    return \@sets, \@breaktimes;

} ## tidy end: sub break_sets

sub frequency {
    
    \my @timenums = shift;

    my ( %diff_count, %diff_psychrounded );
    for my $idx ( 1 .. $#timenums ) {
        my $diff = $timenums[$idx] - $timenums[ $idx - 1 ];
        $diff_count{$diff}++;
        $diff_psychrounded{ psych_round($diff) }++;

    }

    my %diff_culled       = cull_diffs( $#timenums, \%diff_count );
    my %diff_psych_culled = cull_diffs( $#timenums, \%diff_psychrounded );

    my @alldiffs = u::uniq( keys %diff_count, keys %diff_psychrounded );

    my @diff_displays = [qw/Time Diff PsychRnd Cull CullPsych/];

    foreach my $diff ( sort { $a <=> $b } @alldiffs ) {
        push @diff_displays,
          [ $diff,                     $diff_count{$diff},
            $diff_psychrounded{$diff}, $diff_culled{$diff},
            $diff_psych_culled{$diff},
          ];
    }

    my $freq_display = u::joinlf(
        @{ Actium::O::2DArray::->new(@diff_displays)->tabulate('  ') } );

    my ( $lowest, $highest ) = u::minmax( keys %diff_psych_culled );
    my $freq = ( $lowest == $highest ) ? $lowest : "$lowest-$highest";
    return ( $freq_display, $freq );

} ## tidy end: sub frequency

sub adjust_timenums {
    my @timenums = @_;
    my @adjusted = $timenums[0];

    my $adjustment = 0;
    foreach my $idx ( 1 .. $#timenums ) {
        my $old = $timenums[ $idx - 1 ];
        my $new = $timenums[$idx];
        if ( $new < $old ) {
            $adjustment += $MINS_IN_12HRS;
        }
        push @adjusted, $new + $adjustment;
    }

    return @adjusted;

}

sub cull_diffs {
    my $total = shift;
    \my %diff_count = shift;

    # A 'diff' is the difference between a pair of times.
    # A 'count' is the number of times that difference appears in the list.

    # So for a set of times like
    # ( 9:00 , 10:00, 10:30, 10:45, 11:00, 11:30, 12:00 , 12:20, 12:40 )
    # %diff_count will be { 15 => 2, 20 => 2, 30 => 3, 60 => 1 ),
    # where the differences are 15, 20, 30,  and 60; and the number of
    # times they appear is 2, 2, 3, and 1.

    my ( %diffs_of_count, %total_of_count );

    my @diffs = sort { $diff_count{$a} <=> $diff_count{$b} || $a <=> $b }
      keys %diff_count;

    # sorting by the least common difference. This will be (60, 15, 20 , 30)

    my @counts = sort { $a <=> $b } u::uniq( values %diff_count );
    # Also, least common first: (1, 2, 3)

    foreach my $diff (@diffs) {
        my $count = $diff_count{$diff};
        push @{ $diffs_of_count{$count} }, $diff;
        $total_of_count{$count} += $count;
    }

    # $diffs_of_count now is
    # ( 1 => [ 60 ],
    #   2 => [ 15, 20 ],
    #   3 => [ 30 ] )

    # %total_of_count = ( 1 => 1, 2 => 4, 3 => 3 )
    # where the 4 represents the number of 15s plus the number of 20s

    my %results_of_cull = %diff_count;
    my $remaining       = $total;

    #say "@counts";

    while (1) {
        my $count = shift @counts;
        $remaining = $remaining - $total_of_count{$count};
        #say "[[C $count  TC $total_of_count{$count} R $remaining T $total]]";
        last if $remaining < .85 * $total;

        foreach my $diff ( @{ $diffs_of_count{$count} } ) {
            delete $results_of_cull{$diff};
        }

    }

    return %results_of_cull;

} ## tidy end: sub cull_diffs

{

    my %psych_rounded;

    $psych_rounded{$_} = $_ foreach ( 1 .. 8 );
    $psych_rounded{$_} = 10 foreach ( 9 .. 10 );
    $psych_rounded{$_} = 12 foreach ( 11 .. 13 );
    $psych_rounded{$_} = 15 foreach ( 14 .. 18 );
    $psych_rounded{$_} = 20 foreach ( 19 .. 24 );
    $psych_rounded{$_} = 30 foreach ( 25 .. 37 );
    #    $psych_rounded{$_} = 30 foreach ( 25 .. 34 );
    #    $psych_rounded{$_} = 40 foreach ( 35 .. 41 );
    #    $psych_rounded{$_} = 45 foreach ( 42 .. 49 );
    $psych_rounded{$_} = 45 foreach ( 38 .. 49 );
    $psych_rounded{$_} = 60 foreach ( 50 .. 79 );
    $psych_rounded{$_} = 90 foreach ( 80 .. 99 );

    sub psych_round {
        my $mins = shift;
        if ( $mins > 100 ) {
            return nearest 60, $mins;
        }
        return $psych_rounded{$mins};
    }

}

1;

__END__
