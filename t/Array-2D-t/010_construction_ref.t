use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    $Array::2D::NO_REF_UTIL = 1;
    require 'construction.pl';
}

note("Use perl's ref function for checking array references");

test_construction();
