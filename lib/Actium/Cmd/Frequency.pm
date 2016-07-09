package Actium::Cmd::Frequency 0.011;

use Actium::Preamble;
use Actium::Frequency;

use Actium::O::2DArray;
use Actium::O::Time;

sub HELP {
    say 'Determines the frequency of times.';
    return;
}

sub OPTIONS {

    return (
        {   spec        => 'column=i',
            description => 'Column that contains the times (starting with 1). '
              . 'Default is the first column.',
        },
        {   spec        => 'skiplines=i',
            description =>,
            'Lines to skip from the beginning. Default is 0.', fallback => 0
        },
        { spec => 'breaks=s', 'Breaks in the frequency calculation' },
    );
}

sub START {

    my $class = shift;
    my $env   = shift;

    my @argv = $env->argv;

    my $input_file = shift @argv;
    my $column     = $env->option('column');
    my $skiplines  = $env->option('skiplines');
    my $breaks     = $env->option('breaks');

    my $aoa = Actium::O::2DArray::->new_from_file($input_file);

    my @times = $aoa->col( $column - 1 );
    if ($skiplines) {
        @times = @times[ $skiplines .. $#times ];
    }

    my @orig_timenums = grep {defined}
      ( map { Actium::O::Time->from_str($_)->timenum } @times );

    my $first = Actium::O::Time::->from_num( $orig_timenums[0] )->ap;

    my @timenums = Actium::Frequency::adjust_timenums(@orig_timenums);
    my $final    = Actium::O::Time::->from_num( $timenums[-1] )->ap;

    ( \my @sets, \my @breaktimes )
      = Actium::Frequency::break_sets( $breaks, \@timenums );

    my @freqs;

    foreach my $idx ( 0 .. $#sets ) {
        my $set       = $sets[$idx];
        my $breaktime = $breaktimes[$idx];
        $breaktime = defined($breaktime) ? " starting $breaktime" : '';
        my ( $freq_display, $freq ) = Actium::Frequency::frequency($set);
        say "$freq_display\n===";
        push @freqs, "Frequency$breaktime: $freq";
    }

    say "First: $first";
    say $_ foreach @freqs;
    say "Last: $final";

    return;

} ## tidy end: sub START

1;

__END__
