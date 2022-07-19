use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
   require 'construction.pl';
}

note("Use Ref::Util functions for checking array references");

if ( eval { require Ref::Util; 1 } ) {
    test_construction();
}
else {
    plan skip_all => 'Ref::Util not available';
    done_testing;
}

