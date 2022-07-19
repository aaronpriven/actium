use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

a2dcan('set_rows');
# low priority

a2dcan('set_cols');
# low priority

a2dcan('set_slice');
# low priority

done_testing;
