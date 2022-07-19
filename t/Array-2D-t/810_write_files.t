use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

a2dcan('tsv_lines');
# high
# tsv_lines uses Ref::Util

a2dcan('tsv');
# high

a2dcan('file');
# high

a2dcan('xlsx');
# high

done_testing;
