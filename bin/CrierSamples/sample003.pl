#!/usr/bin/env perl 
use strict;
use warnings;
use Actium::Env::CLI::Crier;

our $VERSION = 0.005;

my $crier = Actium::Env::CLI::Crier::->new(
    bullets      => [ "* ", "+ ", "- " ],
    colorize     => 1,
    column_width => 70
);

my $cry_test = $crier->cry("Testing ANSI color escapes for severity levels");

foreach (
    qw/BLISS CALM PASS VALID DONE INFO YES OK
    NO WARN ABORT ERROR FAIL ALERT PANIC rando/
  )
{
    my $cry_sev = $crier->cry("This is the $_ severity");
    $cry_sev->c($_);
}

$cry_test->done;
