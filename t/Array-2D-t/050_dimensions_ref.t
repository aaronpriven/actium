use strict;
use warnings;
use Test::More 0.98;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    $Array::2D::NO_REF_UTIL = 1;
    require 'dimensions.pl';
}

note(q[Check array dimensions]);
note(q[ (This will also test whether the invocant is checked correctly,]);
note(q[  using perl's "ref" function)]);

test_dimensions();
