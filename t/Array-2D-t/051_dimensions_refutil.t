use strict;
use warnings;
use Test::More 0.98;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'dimensions.pl';
}

note(q[Check array dimensions]);
note(q[ (This will also test whether the invocant is checked correctly,]);
note(q[  using Ref::Util functions)]);

if ( eval { require Ref::Util; 1 } ) {
    test_dimensions();
}
else {
    plan skip_all => 'Ref::Util not available';
    done_testing;
}
