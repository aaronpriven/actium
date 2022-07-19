use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

a2dcan('new_from_tsv');
#high

a2dcan('new_from_xlsx');

a2dcan('new_from_xlsx_sheet');
#high

a2dcan('new_from_file');
#high

done_testing;
