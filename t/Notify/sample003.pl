#!perl -w
use strict;
use warnings;
use Actium::O::Notify;

my $n = Actium::O::Notify::->new( bullets => ["* ", "+ ", "- "], colorize => 1, term_width => 70);

my $nf_test = $n->note( "Testing ANSI color escapes for severity levels");

foreach (qw/EMERG ALERT CRIT FAIL FATAL ERR ERROR WARN NOTE INFO OK DEBUG NOTRY UNK YES NO/) {
    my $nf_sev = $n->note( "This  is the $_ severity");
    $nf_sev->done($_);
}

$nf_test->done;
exit 0;
