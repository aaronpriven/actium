#!/usr/bin/env perl 
use strict;
use warnings;
use Actium::Env::CLI::Crier;

our $VERSION = 0.005;

my $crier = Actium::Env::CLI::Crier::->new(
    bullets  => ' * ',
    colorize     => 1,
    fh        => *STDOUT{IO},
    default_status => 1,
);

my $cry = $crier->cry("This should have color, bullets, and go to STDOUT");
