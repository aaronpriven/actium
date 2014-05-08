#!/ActivePerl/bin/perl
use strict;
use warnings;
use Actium::O::Notify;

my $n = Actium::O::Notify::->new(colorize => 1);

sub emit { $n->note(@_) };

{   my $nf = emit "Watch the percentage climb";
    for (1..10) {
        $nf->over (" " . ($_ * 10) . "%");
        select(undef,undef,undef, 0.100);
    }
    $nf->over (""); # erase the percentage
}

{   my $nf = emit "Watch the dots move";
    for (1..40) {
        $nf->prog ($_%10?q:.::':'); # just being difficult...ha!
        select(undef,undef,undef, 0.100);
    }
}

{   my $nf = emit "Here's a spinner";
    my @spin = qw{| / - \\ | / - \\};
    for (1..64) {
        $nf->over ($spin[$_ % @spin]);
        select(undef,undef,undef, 0.125);
    }
    $nf->over;  # remove spinner
}

{   my $nf = emit "Zig zags on parade";
    for (1..200) {
        $nf->prog ($_%2? '/' : '\\');
        select(undef,undef,undef, 0.025);
    }
}


{   my $nf = emit "Making progress";
    for (1..10) {
        $nf->over( " $_/10");
        select(undef,undef,undef, 0.100);
    }
}

{   my $nf = emit "Engines on";
    for (reverse(1..5)) {
        $nf->prog( " $_ ");
        select(undef,undef,undef, 1.000);
    }
    $nf->done( "Gone!");
}

exit 0;
