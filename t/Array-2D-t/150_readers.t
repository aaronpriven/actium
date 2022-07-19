use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'samples.pl';
}

our $sample_ref;
our ( $one_row_ref, $one_row_test );
our ( $one_col_ref, $one_col_test );

my %defaults = (
    element => {
        test_procedure => 'results',
        test_array => $sample_ref,
        expected   => undef,
    },
    row => {
        test_procedure => 'results',
        test_array     => $sample_ref,
        expected       => undef,
        returns_a_list => 1,
    },
    col => {
        test_procedure => 'results',
        test_array     => $sample_ref,
        expected       => undef,
        returns_a_list => 1,
    },
);

my @tests = (
    element => [
        {   arguments   => [ 0, 0, ],
            description => 'Fetched top left element',
            expected    => 'Joshua'
        },
        {   arguments   => [ 9, 2, ],
            description => 'Fetched element from last row',
            expected    => 'San Francisco'
        },
        {   arguments   => [ 2, 4, ],
            description => 'Fetched element from last column',
            expected    => 'Michael'
        },
        {   arguments   => [ 2, 2, ],
            description => 'Fetched an element from middle',
            expected    => 'Dallas'
        },
        {   arguments   => [ -1, 0, ],
            description => 'Fetched an element with negative row',
            expected    => 'Joseph'
        },
        {   arguments   => [ 2, -2, ],
            description => 'Fetched an element with negative column',
            expected    => 'Aix-en-Provence'
        },
        {   arguments   => [ 1, 3, ],
            description => 'Fetched an element set to undef'
        },
        { arguments => [ 3, 4, ], description => 'Fetched an empty element' },
        {   arguments   => [ 12, 2, ],
            description => 'Fetched element from nonexistent row'
        },
        {   arguments   => [ 2, 6, ],
            description => 'Fetched element from nonexistent column'
        },
        {   arguments   => [ -20, 0, ],
            description => 'Fetched element from nonexistent negative row',
        },
        {   arguments => [ 0, -9, ],
            description => 'Fetched element from nonexistent negative column',
        },
        {   arguments   => [ 0, 0, ],
            description => 'Fetched element from one-element array',
            expected    => 'x',
            test_array => [ ['x'] ],
        },
        {   arguments   => [ 0, 1, ],
            description => 'Fetched element from one-row array',
            expected    => 'x',
            test_array => [ [ 1, 'x' ] ],
        },
        {   arguments   => [ 1, 0, ],
            description => 'Fetched element from one-column array',
            expected    => 'x',
            test_array => [ [1], ['x'] ],
        },
        {   arguments   => [ 1, 1, ],
            description => 'Fetched nonexistent element from empty object',
            expected    => undef,
            test_array  => [],
        },
    ],
    row => [
        {   arguments => 0,
            expected  => [ 'Joshua', 29, 'San Mateo', undef, 'Hannah' ]
            ,
            description => 'Fetched full row from beginning',
        },
        {   arguments => 2,
            expected => [ 'Emily', 25, 'Dallas', 'Aix-en-Provence', 'Michael' ],
            description => 'Fetched full row from middle',
        },
        {   arguments   => 7,
            expected    => [ 'Ashley', 57, 'Ray' ],
            description => 'Fetched partial row from middle'
        },
        {   arguments   => 9,
            expected    => [ 'Joseph', 0, 'San Francisco' ],
            description => 'Fetched partial row from end'
        },
        {   arguments   => -2,
            expected    => [ 'Alexis', 50, 'San Carlos', undef, 'Christopher' ],
            description => 'Fetched row with negative index'
        },
        { arguments => 10, expected => [], description => 'nonexistent row' },
        {   arguments   => -20,
            expected    => [],
            description => 'Fetched nonexistent negative row'
        },
        {   arguments   => 0,
            expected    => [],
            description => 'Fetched row from empty array',
            test_array  => [],
        },
        {   arguments   => 0,
            expected    => $one_row_test,
            description => 'Fetched row from one-row array',
            test_array  => $one_row_ref,
        },
        {   arguments   => 1,
            expected    => ['Helvetica'],
            description => 'Fetched row from one-column array',
            test_array  => $one_col_ref,
        },
    ],
    col => [
        {   arguments => 0,
            expected  => [
                'Joshua',  'Christopher', 'Emily',  'Nicholas',
                'Madison', 'Andrew',      'Hannah', 'Ashley',
                'Alexis',  'Joseph',
            ],
            description => 'full column from beginning',
        },
        {   arguments   => 1,
            expected    => [ 29, 59, 25, -14, 8, -15, 38, 57, 50, 0, ],
            description => 'full column from middle',
        },
        {   arguments   => 3,
            expected    => [ undef, undef, 'Aix-en-Provence' ],
            description => 'partial column from middle',
        },
        {   arguments => 4,
            expected  => [
                'Hannah', 'Alexis', 'Michael', undef,
                undef,    undef,    'Joshua',  undef,
                'Christopher'
            ],
            description => 'partial column from end',
        },
        {   arguments => -3,
            expected  => [
                'San Mateo',  'New York City', 'Dallas', undef,
                'Vallejo',    undef,           'Romita', 'Ray',
                'San Carlos', 'San Francisco',
            ],
            description => 'column with negative index',
        },
        { arguments => 6, expected => [], description => 'nonexistent column' },
        {   arguments   => -9,
            expected    => [],
            description => 'nonexistent negative column'
        },
        {   arguments   => 0,
            expected    => [],
            description => 'column from empty array',
            test_array  => [],
        },
        {   arguments   => 0,
            expected    => $one_col_test,
            description => 'column from one-column array',
            test_array  => $one_col_ref,
        },
        {   arguments   => 2,
            expected    => ['Union City'],
            description => 'column from one-row array',
            test_array  => $one_row_ref,
        },
    ],
);

plan_and_run_generic_tests( \@tests, \%defaults );

