use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'samples.pl';
}

our ( $sample_ref,  $sample_transposed_ref );
our ( $one_row_ref, $one_row_test );
our ( $one_col_ref, $one_col_test );

my @all_tests = (
    {   arguments   => [ 2, 3 ],
        expected    => [],
        description => 'from empty array',
        test_array  => [],
    },
    {   arguments   => [0],
        expected    => [ ['x'] ],
        description => 'from one-element array',
        test_array  => [ ['x'] ],
    },
);

my @rows_cols_tests = (
    {   arguments => [ 0, 1 ],
        expected  => [
            [ 'Joshua',      29, 'San Mateo',     undef, 'Hannah' ],
            [ 'Christopher', 59, 'New York City', undef, 'Alexis' ],
        ],
        description => 'first two',
    },
    {   arguments => [ 7, 8, 9 ],
        expected  => [
            [ 'Ashley', 57, 'Ray' ],
            [ 'Alexis', 50, 'San Carlos', undef, 'Christopher' ],
            [ 'Joseph', 0,  'San Francisco' ],
        ],
        description => 'last three',
    },
    {   arguments => [ 4, 5 ],
        expected => [ [ 'Madison', 8, 'Vallejo' ], [ 'Andrew', -15, ], ],
        description => 'two middle',
    },
    {   arguments => [ -1, -2 ],
        expected  => [
            [ 'Joseph', 0, 'San Francisco' ],
            [ 'Alexis', 50, 'San Carlos', undef, 'Christopher' ],
        ],
        description => 'last two using negative subscripts',
    },

    {   arguments => [ 2, 8 ],
        expected  => [
            [ 'Emily',  25, 'Dallas',     'Aix-en-Provence', 'Michael' ],
            [ 'Alexis', 50, 'San Carlos', undef,             'Christopher' ],
        ],
        description => 'Two non-adjacent',
    },

    {   arguments => [ 5, 3 ],
        expected => [ [ 'Andrew', -15, ], [ 'Nicholas', -14, ], ],
        description => 'Two non-adjacent, in reverse order',
    },
    {   arguments   => [ 11, 12 ],
        expected    => [],
        description => 'nonexsitent',
    },
    {   arguments   => [ -20, -21 ],
        expected    => [],
        description => 'nonexsitent, with negative subscripts',
    },
    {   arguments => [ 8, 9, 10 ],
        expected  => [
            [ 'Alexis', 50, 'San Carlos', undef, 'Christopher' ],
            [ 'Joseph', 0,  'San Francisco' ],
        ],
        description => 'range, including a nonexistent one',
    },
    {   arguments => [ 5, 5 ],
        expected => [ [ 'Andrew', -15, ], [ 'Andrew', -15, ], ],
        description => 'two duplicates',
    },
    {   arguments   => [8],
        expected    => [ [ 'Alexis', 50, 'San Carlos', undef, 'Christopher' ] ],
        description => 'just one'
    },

);

my @rows_tests = (
    {   arguments   => [0],
        expected    => [$one_row_test],
        description => 'from one-row array',
        test_array  => $one_row_ref,
    },
    {   arguments => [ 1, 2 ],
        expected => [ ['Helvetica'], ['Courier'] ],
        description => 'from one-column array',
        test_array  => $one_col_ref,
    },
);

my @cols_tests = (
    {   arguments => [ 1, 2 ],
        expected => [ [31], ['Union City'] ],
        description => 'from one-row array',
        test_array  => $one_row_ref,
    },
    {   arguments   => [0],
        expected    => [$one_col_test],
        description => 'from one-column array',
        test_array  => $one_col_ref,
    },
);

my @slice_cols_tests = (
    {   arguments => [ 0, 1 ],
        expected  => [
            [ 'Joshua',      29 ],
            [ 'Christopher', 59, ],
            [ 'Emily',       25, ],
            [ 'Nicholas',    -14, ],
            [ 'Madison',     8, ],
            [ 'Andrew',      -15, ],
            [ 'Hannah',      38, ],
            [ 'Ashley',      57, ],
            [ 'Alexis',      50, ],
            [ 'Joseph',      0, ],

        ],
        description => 'first two',
    },
    {   arguments => [ 2, 3, 4 ],
        expected  => [

            [ 'San Mateo',     undef,             'Hannah' ],
            [ 'New York City', undef,             'Alexis' ],
            [ 'Dallas',        'Aix-en-Provence', 'Michael' ],
            [],
            ['Vallejo'],
            [],
            [ 'Romita', undef, 'Joshua', ],
            ['Ray'],
            [ 'San Carlos', undef, 'Christopher' ],
            ['San Francisco'],

        ],
        description => 'last three',
    },
    {   arguments => [ 1, 2 ],
        expected  => [
            [ 29, 'San Mateo' ],
            [ 59, 'New York City' ],
            [ 25, 'Dallas' ],
            [ -14, ],
            [ 8, 'Vallejo' ],
            [ -15, ],
            [ 38, 'Romita' ],
            [ 57, 'Ray' ],
            [ 50, 'San Carlos' ],
            [ 0,  'San Francisco' ],
        ],
        description => 'two middle',
    },
    {   arguments => [ -2, -1 ],
        expected  => [
            [ undef,             'Hannah' ],
            [ undef,             'Alexis' ],
            [ 'Aix-en-Provence', 'Michael' ],
            [],
            [],
            [],
            [ undef, 'Joshua', ],
            [],
            [ undef, 'Christopher' ],
        ],
        description => 'last two using negative subscripts',
    },
    {   arguments => [ 1, 4 ],
        expected  => [
            [ 29, 'Hannah' ],
            [ 59, 'Alexis' ],
            [ 25, 'Michael' ],
            [ -14, ],
            [ 8, ],
            [ -15, ],
            [ 38, 'Joshua' ],
            [ 57, ],
            [ 50, 'Christopher' ],
            [ 0, ],
        ],
        description => 'Two non-adjacent',
    },
    {   arguments => [ 4, 0 ],
        expected  => [

            [ 'Hannah',      'Joshua' ],
            [ 'Alexis',      'Christopher' ],
            [ 'Michael',     'Emily' ],
            [ undef,         'Nicholas' ],
            [ undef,         'Madison' ],
            [ undef,         'Andrew' ],
            [ 'Joshua',      'Hannah' ],
            [ undef,         'Ashley' ],
            [ 'Christopher', 'Alexis' ],
            [ undef,         'Joseph' ],
        ],
        description => 'Two non-adjacent, in reverse order',
    },
    {   arguments   => [ 11, 12 ],
        expected    => [],
        description => 'nonexsitent',
    },
    {   arguments   => [ -20, -21 ],
        expected    => [],
        description => 'nonexsitent, with negative subscripts',
    },
    {   arguments => [ 3, 4, 5 ],
        expected  => [

            [ undef,             'Hannah' ],
            [ undef,             'Alexis' ],
            [ 'Aix-en-Provence', 'Michael' ],
            [],
            [],
            [],
            [ undef, 'Joshua', ],
            [],
            [ undef, 'Christopher' ],
        ],
        description => 'range, including a nonexistent one',
    },
    {   arguments => [ 1, 1 ],
        expected  => [
            [ 29,  29, ],
            [ 59,  59, ],
            [ 25,  25, ],
            [ -14, -14 ],
            [ 8,   8 ],
            [ -15, -15 ],
            [ 38,  38 ],
            [ 57,  57 ],
            [ 50,  50 ],
            [ 0,   0 ],
        ],
        description => 'two duplicates',
    },

);

my @slice_tests = (
    {   arguments => [ 0, 1, 0, 1 ],
        expected  => [
            [ 'Joshua',      29 ],
            [ 'Christopher', 59, ],

        ],
        description => '2x2: upper left corner',
    },
    {   arguments => [ 7, 9, 2, 4 ],
        expected  => [
            ['Ray'], [ 'San Carlos', undef, 'Christopher' ],
            ['San Francisco'],
        ],
        description => '3x3: lower right corner',
    },
    {   arguments => [ 6, 9, 0, 3 ],
        expected  => [

            [ 'Hannah', 38, 'Romita', ],
            [ 'Ashley', 57, 'Ray' ],
            [ 'Alexis', 50, 'San Carlos', ],
            [ 'Joseph', 0,  'San Francisco' ],

        ],
        description => '4x4: lower left corner',
    },
    {   arguments => [ 8, 9, 3, 4 ],
        expected => [ [ undef, 'Christopher' ] ],
        description => '2x2: lower right corner, including blank row area',
    },
    {   arguments => [ 0, 1, -2, -1 ],
        expected  => [

            [ undef, 'Hannah' ],
            [ undef, 'Alexis' ],

        ],
        description => '2x2: upper right, negative column subscripts',
    },
    {   arguments => [ -1, -2, 0, 1 ],
        expected  => [
            [ 'Alexis', 50, ],
            [ 'Joseph', 0, ],

        ],
        description => '2x2: lower left, negative row subscripts',
    },
    {   arguments => [ 2, 4, 1, 3 ],
        expected =>
          [ [ 25, 'Dallas', 'Aix-en-Provence', ], [ -14, ], [ 8, 'Vallejo' ], ],
        description => '3x3: middle',
    },

    {   arguments => [ 6, 8, 3, 4 ],
        expected => [ [ undef, 'Joshua' ], [], [ undef, 'Christopher' ], ],
        description => 'with empty row',
    },
    {   arguments   => [ 3, 4, 4, 5 ],
        expected    => [],
        description => 'entirely empty',
    },
    {   arguments => [ 0, 1, 4, 5 ],
        expected => [ ['Hannah'], ['Alexis'], ],
        description => 'partially off the right edge',
    },
    {   arguments => [ 9, 10, 0, 1 ],
        expected => [ [ 'Joseph', 0 ] ],
        description => 'partially off the bottom edge',
    },
    {   arguments => [ 7, 10, 2, 5 ],
        expected  => [
            ['Ray'], [ 'San Carlos', undef, 'Christopher' ],
            ['San Francisco'],
        ],
        description => 'partially off both bottom and right edges',
    },
    {   arguments   => [ 0, 1, 10, 11 ],
        expected    => [],
        description => 'entirely off right'
    },
    {   arguments   => [ 15, 16, 0, 1 ],
        expected    => [],
        description => 'entirely off both bottom and right',
    },
    {   arguments   => [ 20, 21, 20, 21 ],
        expected    => [],
        description => 'entirely off left'
    },
    {   arguments   => [ 0, 1, -10, -11 ],
        expected    => [],
        description => 'entirely off top',
    },
    {   arguments   => [ -15, -16, 0, 1 ],
        expected    => [],
        description => 'entirely off top',
    },
    {   arguments   => [ -15, -16, -15, -16 ],
        expected    => [],
        description => 'entirely off both left and top',
    },
    {   arguments => [ 2, 1, 1, 2 ],
        expected => [ [ 59, 'New York City' ], [ 25, 'Dallas', ], ],
        description => '2x2: reverse row order specified',
    },
    {   arguments => [ 4, 7, 4, 2 ],
        expected =>
          [ ['Vallejo'], [], [ 'Romita', undef, 'Joshua', ], ['Ray'], ],
        description => '3x3: reverse column order specified',
    },
    {   arguments => [ 9, 7, 1, 0 ],
        expected => [ [ 'Ashley', 57, ], [ 'Alexis', 50, ], [ 'Joseph', 0, ], ],
        description => '3x2: reverse row and column order specified',
    },
);

my @generic_tests = (
    rows       => [ @all_tests, @rows_cols_tests, @rows_tests ],
    cols       => [ @all_tests, @rows_cols_tests, @cols_tests ],
    slice_cols => [ @all_tests, @slice_cols_tests ],
    slice      => \@slice_tests,
);

my %generic_defaults = (
    rows => {
        test_procedure => 'results',
        test_array     => $sample_ref,
        check_blessing => 'always',
    },
    cols => {
        test_procedure => 'results',
        test_array     => $sample_transposed_ref,
        check_blessing => 'always',
    },
    slice_cols => {
        test_procedure => 'results',
        test_array     => $sample_ref,
        check_blessing => 'always',
    },
    slice => {
        test_procedure => 'contextual',
        test_array     => $sample_ref,
        check_blessing => 'always',
    },
);

plan_and_run_generic_tests (\@generic_tests, \%generic_defaults );

