use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;

use Test::More 0.98;

my $testcount = 1;

BEGIN {
    note "These are tests of Actium::DateTime.";
    use_ok 'Actium::DateTime';
}

done_testing;
# tests to come, later, I hope

