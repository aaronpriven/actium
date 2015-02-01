#!perl -w
use strict;
use warnings;
use Actium::O::Crier;

our $VERSION = 0.005;

my $crier = Actium::O::Crier::->new(
    bullets    => [ "* ", "+ ", "- " ],
    colorize   => 1,
    term_width => 70
);

my $cry_test = $crier->cry("Testing ANSI color escapes for severity levels");

foreach (
    qw/EMERG ALERT CRIT FAIL FATAL ERR ERROR
    WARN NOTE INFO OK DEBUG NOTRY UNK YES NO/
  )
{
    my $cry_sev = $crier->cry("This  is the $_ severity");
    $cry_sev->done($_);
}

$cry_test->done;
1;

__END__
