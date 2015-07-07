#!perl -w
use strict;
use warnings;
use Actium::O::Crier;

our $VERSION = 0.005;

my $crier = Actium::O::Crier::->new(
    bullets    => [ "* ", "+ ", "- " ],
    colorize   => 1,
    column_width => 70
);

my $cry_test = $crier->cry("Testing ANSI color escapes for severity levels");

foreach (
    qw/EMERG PANIC HAVOC ALERT DARN CRIT FAIL FATAL ARGH ERR ERROR
    OOPS WARN NOTE INFO OK DEBUG NOTRY UNK YES PASS NO/
  )
{
    my $cry_sev = $crier->cry("This  is the $_ severity");
    $cry_sev->done($_);
}

$cry_test->done;
1;

__END__
