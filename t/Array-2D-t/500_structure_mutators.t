use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'samples.pl';
}

our ( $one_row_ref, $one_col_ref, $one_col_test );
our ( $sample_transposed_ref, $sample_ref );

my @tests = (
    transpose => [
        {   test_array  => $sample_ref,
            expected    => $sample_transposed_ref,
            description => 'array'
        },
        {   test_array  => $sample_transposed_ref,
            expected    => $sample_ref,
            description => 'array (reverse of previous test)'
        },
        {   test_array => $one_row_ref,
            expected =>
              [ ['Michael'], [31], ['Union City'], ['Vancouver'], ['Emily'], ],
            description => 'one-row array'
        },
        {   test_array  => $one_col_ref,
            expected    => [$one_col_test],
            description => 'one-col array'
        },
        {   test_array => [ ['element'] ],
            expected   => [ ['element'] ],
            description => 'one-element array'
        },
        {   test_array  => [],
            expected    => [],
            description => 'empty array'
        },
    ],
    flattened => [
        {   test_array => [ [qw/a b c/], [ 1, 2, 3, ], [qw/x y z/] ],
            expected    => [ qw/a b c/, 1, 2, 3, qw/x y z/ ],
            description => 'rectangular array',
        },
        {   test_array =>
              [ [ undef, qw/b c/ ], [ 1, 2, 3, 4, ], [qw/x y z/], ['q'], ],
            expected    => [ qw/b c/, 1, 2, 3, 4,, qw/x y z/, 'q', ],
            description => 'ragged array',
        },
        {   test_array => $one_row_ref,
            expected   => [ 'Michael', 31, 'Union City', 'Vancouver', 'Emily' ],
            description => 'one-row array',
        },
        {   test_array => $one_col_ref,
            expected   => [
                qw/Times Helvetica Courier Lucida Myriad
                  Minion Syntax Johnston Univers Frutiger/
            ],
            description => 'flatten one-col array',
        },
        {   test_array  => [],
            expected    => [],
            description => 'empty array'
        },
    ],
);

my %defaults = (
    transpose => { test_procedure => 'contextual', check_blessing => 'always' },
    flattened => { test_procedure => 'results',    returns_a_list => 1 }
);

plan_and_run_generic_tests( \@tests, \%defaults );
