use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More 0.98 tests => 1;

BEGIN {
    note "These are tests of Actium::Env::CLI.";
    use_ok 'Actium::Env::CLI';
}

note "OK, so there's just the one test to see if it loads. Sorry.";

done_testing;

__END__

