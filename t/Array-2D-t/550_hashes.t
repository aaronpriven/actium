use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

a2dcan('hash_of_rows');
# low

a2dcan('hash_of_row_elements');
# low

done_testing;
