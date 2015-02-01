#!/ActivePerl/bin/perl
use strict;
use warnings;
use Actium::O::Crier;

our $VERSION = 0.005;

my $crier = Actium::O::Crier::->new(
    bullets  => ' * ',
    colorize     => 1,
    fh        => *STDOUT{IO},
    default_closestat => "OK"
);

my $cry = $crier->cry("This should have color, bullets, and go to STDOUT");
exit 0;
