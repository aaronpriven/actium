#!/usr/bin/env perl 
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

foreach my $method ( qw/del_cols del_rows/) {
    a2dcan($method);
}

# all low priority

done_testing;
