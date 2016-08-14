package Actium::Cmd::Scratch 0.011;

use Actium::Preamble;
use Actium::Union('ordered_union_columns');

# a place to test out small programs, in the Actium environment

my $stop_tiebreaker = sub {

    # tiebreaks by using the average rank of the timepoints involved.
    
    say "tiebreak";

    my @lists = @_;
    my @avg_ranks;

    foreach my $i ( 0, 1 ) {

        my @ranks;
        foreach my $stop ( @{ $lists[$i] } ) {
            my ( $stopid, $placeid, $placerank ) = split( /\./s, $stop );
            if ( defined $placerank ) {
                push @ranks, $placerank;
            }
        }
        return 0 unless @ranks;
        # if either list has no timepoint ranks,
        # return 0 indicating we can't break the tie

        $avg_ranks[$i] = u::sum(@ranks) / @ranks;
        
        say "@ranks : $avg_ranks[$i]";

    }

    return $avg_ranks[0] <=> $avg_ranks[1];

};

sub START {
    my ( $class, $env ) = @_;

    my %stop_set_of = (
        11.106 => [
            "59988|HIWY|0", 50860, 51541,          56114,
            53131,          51335, 51238,          59550,
            59556,          55250, "55350|HAMA|1", 54600,
            58821,          53477, 51688,          56781,
            55485,          51570, "57556|KCCN|3", 55240,
            54700,          50958, "50212|12BD|4", 51536,
            59999,          55571, 58894,          "55833|MRBA|5"
        ],
        11.111 => [
            "59988|HIWY|0", 50860, 51541,          56114,
            53131,          51335, 51238,          59550,
            59556,          55250, "55350|HAMA|1", 54600,
            58821,          53477, 51688,          56781,
            55485,          51570, "57556|KCCN|3", 55240,
            54700,          50958, "50212|12BD|4", 51536,
            59999,          55571, 58894,          "54999|MRBA|5",
            54483,          55781, 57671,          53447,
            56061,          54845, 57554,          "55261|14FT|6",
            51140,          57233, 55263,          54150,
            54250,          55102, 52567,          55202,
            51268,          53349, 50405,          59916,
            51267,          "55997|FTMO|7"
        ],
        11.116 => [
            "55350|HAMA|1", 54600,          58821, 53477,
            51688,          56781,          55485, 51570,
            "57556|KCCN|3", 55240,          54700, 50958,
            "50212|12BD|4", 51536,          59999, 55571,
            58894,          "54999|MRBA|5", 54483, 55781,
            57671,          53447,          56061, 54845,
            57554,          "55261|14FT|6", 51140, 57233,
            55263,          54150,          54250, 55102,
            52567,          55202,          51268, 53349,
            50405,          59916,          51267, "55997|FTMO|7"
        ]
    );
    
    my %returned = ordered_union_columns(
        sethash    => \%stop_set_of,
        tiebreaker => $stop_tiebreaker,
    );
    
    use DDP;
    p %returned;

} ## tidy end: sub START

