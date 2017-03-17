package Actium::Cmd::Scratch 0.012;

use Actium::Preamble;

use Actium::Clusterize('clusterize');

sub START {

    my %count_of = (

        101 => 5,
        102 => 4,
        112 => 0,
        113 => 1,
        221 => 5,
        222 => 43,
        233 => 135,
        237 => 45,
        234 => 5,
        235 => 43,
        251 => 67,
        305 => 2,
        441 => 5,
        442 => 8,
        501 => 5,
        502 => 4,
        510 => 73,
        607 => 8,
        701 => 21,
        702 => 21,
        703 => 21,
        704 => 41,
        705 => 21,
    );

    \my %unfolded_of
      = clusterize( count_of => \%count_of, root_digits => 1 );

    print STDERR "%unfolded_of = ";

    use DDP;
    p %unfolded_of;

} ## tidy end: sub START

1;

__END__
