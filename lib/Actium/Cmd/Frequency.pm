# /Actium/Cmd/Labels.pm
#
# Makes spreadsheet to print decal labels

package Actium::Cmd::Frequency 0.010;

use Actium::Preamble;
use Actium::O::2DArray;
use Actium::O::Time;

sub HELP {
    say 'Determines the frequency of times.';
    return;
}

sub OPTIONS {

    return [
        'column=i',
        'Column that contains the times (starting with 1). ' . 
        'Default is the first column.', 1
      ],
      [ 'skiplines=i', 'Lines to skip from the beginning. Default is 0.', 0 ],
      ;
}

sub START {

    my $class     = shift;
    my $env       = shift;

    my @argv = $env->argv;

    my $input_file = shift @argv;
    my $column     = $env->option('column');
    my $skiplines  = $env->option('skiplines');

    my $aoa = Actium::O::2DArray::->new_from_file($input_file);

    my @times = $aoa->col($column - 1);
    if ($skiplines) {
        @times = @times[ $skiplines .. $#times ];
    }

    my @timenums = grep { defined } 
      ( map {  Actium::O::Time->instance($_)->timenum } @times);

    say $_ foreach @timenums;

    @timenums = sort { $a <=> $b } @timenums;

    my %count_of;
    for my $idx ( 1 .. $#timenums ) {
      my $diff = $timenums[$idx] - $timenums[$idx - 1];
      $count_of{$diff}++;
    }

    foreach my $diff ( sort { $a <=> $b } keys %count_of ) {
       say "$diff: $count_of{$diff}";
    }
    say $EMPTY;

    my $num_of_diffs = scalar keys %count_of;

    if ($num_of_diffs == 1 ) {
       say "Frequency: $num_of_diffs";
    } else {
       my ($lowest , $highest) = u::minmax(keys %count_of);
       say "Frequency: $lowest-$highest";
    }

    return;

} ## tidy end: sub START

1;

__END__
