use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    $Array::2D::NO_GCSTRING = 1;
    require 'tabulation.pl';
}

note("Use perl's length function for determining text column widths");

run_tabulation_tests();
