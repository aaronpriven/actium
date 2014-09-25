#!/ActivePerl/bin/perl
use strict;
use warnings;
use Actium::O::Notify;

our $VERSION = 0.005;

my $n = Actium::O::Notify::->new(
    bullets  => ' * ',
    colorize     => 1,
    fh        => *STDOUT{IO},
    default_closestat => "OK"
);

my $nf = $n->note("This should have color, bullets, and go to STDOUT");
exit 0;
