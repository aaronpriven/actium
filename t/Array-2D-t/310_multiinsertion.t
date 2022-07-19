#!/usr/bin/env perl 
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

foreach my $method (
    qw/ins_rows ins_cols push_rows push_cols unshift_rows unshift_cols/)
{
    a2dcan($method);
}

# all low priority

done_testing;
