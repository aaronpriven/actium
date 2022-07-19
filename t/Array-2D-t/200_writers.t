use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

use Test::Fatal;

my $set_ref = [ [ 'a', 1, 'x' ], [ 'b', 2, 'y' ], [ 'c', 3, 'z' ], ];


my %defaults = (
    set_element => { test_procedure => 'altered' , test_array => $set_ref },
    set_row     => { test_procedure => 'altered' , test_array => $set_ref },
    set_col     => { test_procedure => 'altered' , test_array => $set_ref },
);

my @tests = (
    set_element => [
        {   description => 'Replace a value (top left)',
            arguments   => [ 0, 0, 'New value' ],
            altered =>
              [ [ 'New value', 1, 'x' ], [ 'b', 2, 'y' ], [ 'c', 3, 'z' ] ]
        },
        {   altered =>
              [ [ 'a', 1, 'x' ], [ 'b', 2, 'y' ], [ 'c', 3, 'New value' ] ],
            description => 'Replace a value (bottom right)',
            arguments   => [ 2, 2, 'New value' ]
        },
        {   arguments   => [ 1, 1, 'New value' ],
            description => 'Replace a value (middle)',
            altered =>
              [ [ 'a', 1, 'x' ], [ 'b', 'New value', 'y' ], [ 'c', 3, 'z' ] ]
        },
        {   description  => 'Add a new value off the array to the right',
            arguments    => [ 1, 4, 'New value' ],
            altered => [
                [ 'a', 1, 'x' ],
                [ 'b', 2, 'y', undef, 'New value' ],
                [ 'c', 3, 'z' ]
            ]
        },
        {   altered => [
                [ 'a', 1, 'x' ],
                [ 'b', 2, 'y' ],
                [ 'c', 3, 'z' ],
                undef,
                [ undef, 'New value' ]
            ],
            description => 'Add a new value off the array to the bottom',
            arguments   => [ 4, 1, 'New value' ]
        },
        {   description =>
              'Add a new value off the array to the bottom and right',
            arguments    => [ 4, 4, 'New value' ],
            altered => [
                [ 'a', 1, 'x' ],
                [ 'b', 2, 'y' ],
                [ 'c', 3, 'z' ],
                undef, [ undef, undef, undef, undef, 'New value' ]
            ]
        },
        {   arguments => [ 0, -4, 'New value' ],
            description => 'dies with invalid negative indices to the left',
            exception   => qr/Modification of non-creatable array value/,
            test_array  => [],
        },
        {   arguments => [ -4, 0, 'New value' ],
            description => 'dies with invalid negative indices to the top',
            exception   => qr/Modification of non-creatable array value/,
            test_array  => [],
        },
        {   arguments => [ -4, -4, 'New value' ],
            exception => qr/Modification of non-creatable array value/,
            description =>
              'dies with invalid negative indicies to the top and left',
            test_array => [],
        },
    ],
    set_row => [
        {   description => 'Replace a row (top)',
            arguments   => [ 0,  'q', 'r', 's'  ],
            altered =>
              [ [ 'q', 'r', 's' ], [ 'b', 2, 'y' ], [ 'c', 3, 'z' ] ]
        },
        {   arguments => [ 1,  'q', 'r', 's'  ],
            description => 'Replace a row (middle)',
            altered =>
              [ [ 'a', 1, 'x' ], [ 'q', 'r', 's' ], [ 'c', 3, 'z' ] ]
        },
        {   altered =>
              [ [ 'a', 1, 'x' ], [ 'q', 'r', 's' ], [ 'c', 3, 'z' ] ],
            arguments => [ -2,  'q', 'r', 's'  ],
            description => 'Replace a row (negative index)'
        },
        {   altered =>
              [ [ 'a', 1, 'x' ], [ 'b', 2, 'y' ], [ 'q', 'r', 's' ] ],
            arguments => [ 2,  'q', 'r', 's'  ],
            description => 'Replace a row (final row)'
        },
        {   altered => [
                [ 'a', 1,   'x' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ],
                [ 'q', 'r', 's' ]
            ],
            description => 'Add a new row at the bottom',
            arguments   => [ 3,  'q', 'r', 's'  ]
        },
        {   arguments => [ 4,  'q', 'r', 's'  ],
            description  => 'Add a new value below the bottom',
            altered => [
                [ 'a', 1, 'x' ],
                [ 'b', 2, 'y' ],
                [ 'c', 3, 'z' ],
                undef,
                [ 'q', 'r', 's' ]
            ]
        },
        {   arguments => [ 1,  'q', 'r'  ],
            description  => 'Replace a row with a shorter row',
            altered => [ [ 'a', 1, 'x' ], [ 'q', 'r' ], [ 'c', 3, 'z' ] ]
        },
        {   altered =>
              [ [ 'a', 1, 'x' ], [ 'q', undef, 's' ], [ 'c', 3, 'z' ] ],
            arguments => [ 1,  'q', undef, 's'  ],
            description => 'Replace a row with one with an undefined value'
        },
        {   arguments => [ 1,  'q', 'r', 's', 't'  ],
            description => 'Replace a row with a longer row',
            altered =>
              [ [ 'a', 1, 'x' ], [ 'q', 'r', 's', 't' ], [ 'c', 3, 'z' ] ]
        },
        {   exception   => qr/Modification of non-creatable array value/,
            arguments   => [ -5, 'New value' ],
            description => 'dies with invalid negative indices',
        }
    ],
    set_col => [
        {   description => 'Replace a column (left)',
            arguments   => [ 0,  'q', 'r', 's'  ],
            altered =>
              [ [ 'q', 1, 'x' ], [ 'r', 2, 'y' ], [ 's', 3, 'z' ] ]
        },
        {   altered =>
              [ [ 'a', 'q', 'x' ], [ 'b', 'r', 'y' ], [ 'c', 's', 'z' ] ],
            description => 'Replace a column (middle)',
            arguments   => [ 1,  'q', 'r', 's'  ]
        },
        {   arguments => [ -2,  'q', 'r', 's'  ],
            description => 'Replace a column (negative index)',
            altered =>
              [ [ 'a', 'q', 'x' ], [ 'b', 'r', 'y' ], [ 'c', 's', 'z' ] ]
        },
        {   description => 'Replace a column (final column)',
            arguments   => [ 2,  'q', 'r', 's'  ],
            altered =>
              [ [ 'a', 1, 'q' ], [ 'b', 2, 'r' ], [ 'c', 3, 's' ] ]
        },
        {   altered => [
                [ 'a', 1, 'x', 'q' ],
                [ 'b', 2, 'y', 'r' ],
                [ 'c', 3, 'z', 's' ]
            ],
            description => 'Add a new column at the right',
            arguments   => [ 3,  'q', 'r', 's'  ]
        },
        {   arguments => [ 4,  'q', 'r', 's'  ],
            description  => 'Add a new value below the right',
            altered => [
                [ 'a', 1, 'x', undef, 'q' ],
                [ 'b', 2, 'y', undef, 'r' ],
                [ 'c', 3, 'z', undef, 's' ]
            ]
        },
        {   description => 'Replace a column with a shorter column',
            arguments   => [ 1,  'q', 'r'  ],
            altered =>
              [ [ 'a', 'q', 'x' ], [ 'b', 'r', 'y' ], [ 'c', undef, 'z' ] ]
        },
        {   altered =>
              [ [ 'a', 'q', 'x' ], [ 'b', undef, 'y' ], [ 'c', 's', 'z' ] ],
            description => 'Replace a column with one with an undefined value',
            arguments   => [ 1,  'q', undef, 's'  ]
        },
        {   altered => [
                [ 'a',   'q', 'x' ],
                [ 'b',   'r', 'y' ],
                [ 'c',   's', 'z' ],
                [ undef, 't' ]
            ],
            arguments => [ 1,  'q', 'r', 's', 't'  ],
            description => 'Replace a column with a longer column'
        },
        {   arguments => [ -2,  'q', 'r'  ],
            description =>
              'Replace a column with a shorter column (negative index)',
            altered =>
              [ [ 'a', 'q', 'x' ], [ 'b', 'r', 'y' ], [ 'c', undef, 'z' ] ]
        },
        {   altered =>
              [ [ 'a', 'q', 'x' ], [ 'b', undef, 'y' ], [ 'c', 's', 'z' ] ],
            description =>
              'Replace column with one with undefined value (negative index)',
            arguments => [ -2,  'q', undef, 's'  ]
        },
        {   altered => [
                [ 'a',   'q', 'x' ],
                [ 'b',   'r', 'y' ],
                [ 'c',   's', 'z' ],
                [ undef, 't' ]
            ],
            description =>
              'Replace a column with a longer column (negative index)',
            arguments => [ -2,  'q', 'r', 's', 't'  ]
        },
        {   exception => qr/negative index off the beginning of the array/,
            arguments   => [ -5, 'New value' ],
            description => 'dies with invalid negative indices',
        }
    ]
);

plan_and_run_generic_tests( \@tests, \%defaults );
