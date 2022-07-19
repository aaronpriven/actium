use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

my $ins_ref = [ [ 'a', 1, 'x' ], [ 'b', 2, 'y' ], [ 'c', 3, 'z' ], ];

my %defaults = (
    ins_row     => { test_procedure => 'both', test_array => $ins_ref },
    ins_col     => { test_procedure => 'both', test_array => $ins_ref },
    push_row    => { test_procedure => 'both', test_array => $ins_ref },
    push_col    => { test_procedure => 'both', test_array => $ins_ref },
    unshift_row => { test_procedure => 'both', test_array => $ins_ref },
    unshift_col => { test_procedure => 'both', test_array => $ins_ref },
);

my @tests = (
    ins_row => [
        {   altered => [
                [ 'q', 'r', 's' ],
                [ 'a', 1,   'x' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ]
            ],
            expected => 4,
            description => 'Insert a row (top)',
            arguments   => [ 0,  'q', 'r', 's'  ]
        },
        {   arguments => [ 1,  'q', 'r', 's'  ],
            expected => 4,
            altered => [
                [ 'a', 1,   'x' ],
                [ 'q', 'r', 's' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ]
            ],
            description => 'Insert a row (middle)'
        },
        {   altered => [
                [ 'a', 1,   'x' ],
                [ 'q', 'r', 's' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ]
            ],
            expected => 4,
            description => 'Insert a row (negative index)',
            arguments   => [ -2,  'q', 'r', 's'  ]
        },
        {   description => 'Insert a row after the last one',
            altered    => [
                [ 'a', 1,   'x' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ],
                [ 'q', 'r', 's' ]
            ],
            expected => 4,
            arguments => [ 3,  'q', 'r', 's' ] ,
        },
        {   arguments => [ 4,  'q', 'r', 's'  ],
            description => 'Add a new row off the bottom',
            expected => 5,
            altered    => [
                [ 'a', 1, 'x' ],
                [ 'b', 2, 'y' ],
                [ 'c', 3, 'z' ],
                undef,
                [ 'q', 'r', 's' ]
            ]
        },
        {   altered => [
                [ 'a', 1, 'x' ],
                [ 'q', 'r' ],
                [ 'b', 2, 'y' ],
                [ 'c', 3, 'z' ]
            ],
            expected => 4,
            description => 'Insert a shorter row',
            arguments   => [ 1,  'q', 'r'  ]
        },
        {   arguments => [ 1,  'q', undef, 's'  ],
            expected => 4,
            altered => [
                [ 'a', 1,     'x' ],
                [ 'q', undef, 's' ],
                [ 'b', 2,     'y' ],
                [ 'c', 3,     'z' ]
            ],
            description => 'Insert a row with an undefined value'
        },
        {   arguments => [ 1,  'q', 'r', 's', 't'  ],
            description => 'Insert a longer row',
            expected => 4,
            altered    => [
                [ 'a', 1, 'x' ],
                [ 'q', 'r', 's', 't' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ]
            ]
        },
        {   test_array  => [],
            description => 'Insert row into an empty array',
            altered    => [ undef, [ 'q', 'r' ] ],
            arguments   => [ 1,  'q', 'r' ] ,
            expected => 2,
        },
        {   exception =>
              qr/Modification of non-creatable array value attempted/,
            arguments   => [ -5, 'New value' ],
            description => 'dies with invalid negative indices',
        },
    ],
    ins_col => [
        {   altered => [
                [ 'q', 'a', 1, 'x' ],
                [ 'r', 'b', 2, 'y' ],
                [ 's', 'c', 3, 'z' ]
            ],
            expected => 4,
            description => 'Insert a column (left)',
            arguments   => [ 0,  'q', 'r', 's'  ]
        },
        {   description => 'Insert a column (middle)',
            expected => 4,
            altered    => [
                [ 'a', 'q', 1, 'x' ],
                [ 'b', 'r', 2, 'y' ],
                [ 'c', 's', 3, 'z' ]
            ],
            arguments => [ 1,  'q', 'r', 's'  ]
        },
        {   arguments => [ -2,  'q', 'r', 's'  ],
            description => 'Insert a column (negative index)',
            expected => 4,
            altered    => [
                [ 'a', 'q', 1, 'x' ],
                [ 'b', 'r', 2, 'y' ],
                [ 'c', 's', 3, 'z' ]
            ]
        },
        {   altered => [
                [ 'a', 1, 'x', 'q' ],
                [ 'b', 2, 'y', 'r' ],
                [ 'c', 3, 'z', 's' ]
            ],
            expected => 4,
            description => 'Insert a column after the last one',
            arguments   => [ 3,  'q', 'r', 's'  ]
        },
        {   altered => [
                [ 'a', 1, 'x', undef, 'q' ],
                [ 'b', 2, 'y', undef, 'r' ],
                [ 'c', 3, 'z', undef, 's' ]
            ],
            expected => 5,
            description => 'Add a new column off the edge',
            arguments   => [ 4,  'q', 'r', 's'  ]
        },
        {   description => 'Insert a shorter column',
            altered    => [
                [ 'a', 'q',   1, 'x' ],
                [ 'b', 'r',   2, 'y' ],
                [ 'c', undef, 3, 'z' ]
            ],
            expected => 4,
            arguments => [ 1,  'q', 'r'  ]
        },
        {   arguments => [ 1,  'q', undef, 's'  ],
            expected => 4,
            altered => [
                [ 'a', 'q',   1, 'x' ],
                [ 'b', undef, 2, 'y' ],
                [ 'c', 's',   3, 'z' ]
            ],
            description => 'Insert a column with an undefined value'
        },
        {   description => 'Insert a longer column',
            expected => 4,
            altered    => [
                [ 'a',   'q', 1, 'x' ],
                [ 'b',   'r', 2, 'y' ],
                [ 'c',   's', 3, 'z' ],
                [ undef, 't' ]
            ],
            arguments => [ 1,  'q', 'r', 's', 't'  ]
        },
        {   arguments => [ 1,  'q', 'r' ] ,
            description => 'Insert column into an empty array',
            altered    => [ [ undef, 'q' ], [ undef, 'r' ] ],
            expected => 2,
            test_array  => []
        },
        {   exception =>
              qr/negative index off the beginning of the array/i,
            arguments   => [ -5, 'New value' ],
            description => 'dies with invalid negative indices',
        },
    ],
    push_row => [
        {   arguments => [  'q', 'r', 's' ] ,
            expected => 4,
            altered => [
                [ 'a', 1,   'x' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ],
                [ 'q', 'r', 's' ]
            ],
            description => 'Push a row'
        },
        {   altered => [
                [ 'a', 1, 'x' ],
                [ 'b', 2, 'y' ],
                [ 'c', 3, 'z' ],
                [ 'q', 'r' ]
            ],
            expected => 4,
            description => 'Push a shorter row',
            arguments   => [  'q', 'r' ] 
        },
        {   description => 'Push a row with an undefined value',
            altered    => [
                [ 'a', 1,     'x' ],
                [ 'b', 2,     'y' ],
                [ 'c', 3,     'z' ],
                [ 'q', undef, 's' ]
            ],
            expected => 4,
            arguments => [  'q', undef, 's' ] 
        },
        {   arguments => [  'q', 'r', 's', 't' ] ,
            altered => [
                [ 'a', 1, 'x' ],
                [ 'b', 2, 'y' ],
                [ 'c', 3, 'z' ],
                [ 'q', 'r', 's', 't' ]
            ],
            expected => 4,
            description => 'Push a longer row'
        },
        {   arguments =>  [ 'q', 'r' ] ,
            description => 'Push row into an empty array',
            altered    => [ [ 'q', 'r' ] ],
            expected => 1,
            test_array  => []
        }
    ],
    push_col => [
        {   arguments =>  [ 'q', 'r', 's' ] ,
            description => 'Push a column',
            expected => 4,
            altered    => [
                [ 'a', 1, 'x', 'q' ],
                [ 'b', 2, 'y', 'r' ],
                [ 'c', 3, 'z', 's' ]
            ]
        },
        {   description => 'Push a shorter column',
            expected => 4,
            altered    => [
                [ 'a', 1, 'x', 'q' ],
                [ 'b', 2, 'y', 'r' ],
                [ 'c', 3, 'z', undef ]
            ],
            arguments =>  [ 'q', 'r' ] 
        },
        {   description => 'Push a column with an undefined value',
            altered    => [
                [ 'a', 1, 'x', 'q' ],
                [ 'b', 2, 'y', undef ],
                [ 'c', 3, 'z', 's' ]
            ],
            expected => 4,
            arguments =>  [ 'q', undef, 's' ] 
        },
        {   arguments =>  [ 'q', 'r', 's', 't' ] ,
            description => 'Push a longer column',
            expected => 4,
            altered    => [
                [ 'a',   1,     'x',   'q' ],
                [ 'b',   2,     'y',   'r' ],
                [ 'c',   3,     'z',   's' ],
                [ undef, undef, undef, 't' ]
            ]
        },
        {   test_array  => [],
            expected => 1,
            arguments   =>  [ 'q', 'r' ] ,
            altered    => [ ['q'], ['r'] ],
            description => 'Push column into an empty array'
        }
    ],
    unshift_col => [
        {   arguments =>  [ 'q', 'r', 's' ] ,
            description => 'Unshift a column',
            expected => 4,
            altered    => [
                [ 'q', 'a', 1, 'x' ],
                [ 'r', 'b', 2, 'y' ],
                [ 's', 'c', 3, 'z' ]
            ]
        },
        {   altered => [
                [ 'q',   'a', 1, 'x' ],
                [ 'r',   'b', 2, 'y' ],
                [ undef, 'c', 3, 'z' ]
            ],
            expected => 4,
            description => 'Unshift a shorter column',
            arguments   =>  [ 'q', 'r' ] 
        },
        {   arguments =>  [ 'q', undef, 's' ] ,
            expected => 4,
            altered => [
                [ 'q',   'a', 1, 'x' ],
                [ undef, 'b', 2, 'y' ],
                [ 's',   'c', 3, 'z' ]
            ],
            description => 'Unshift a column with an undefined value'
        },
        {   altered => [
                [ 'q', 'a', 1, 'x' ],
                [ 'r', 'b', 2, 'y' ],
                [ 's', 'c', 3, 'z' ],
                ['t']
            ],
            expected => 4,
            description => 'Unshift a longer column',
            arguments   =>  [ 'q', 'r', 's', 't' ] 
        },
        {   description => 'Unshift column into an empty array',
            expected => 1,
            altered    => [ ['q'], ['r'] ],
            arguments   =>  [ 'q', 'r' ] ,
            test_array  => []
        }
    ],
    unshift_row => [
        {   description => 'Unshift a row',
            expected => 4,
            altered    => [
                [ 'q', 'r', 's' ],
                [ 'a', 1,   'x' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ]
            ],
            arguments =>  [ 'q', 'r', 's' ] 
        },
        {   description => 'Unshift a shorter row',
            expected => 4,
            altered    => [
                [ 'q', 'r' ],
                [ 'a', 1, 'x' ],
                [ 'b', 2, 'y' ],
                [ 'c', 3, 'z' ]
            ],
            arguments =>  [ 'q', 'r' ] 
        },
        {   description => 'Unshift a row with an undefined value',
            expected => 4,
            altered    => [
                [ 'q', undef, 's' ],
                [ 'a', 1,     'x' ],
                [ 'b', 2,     'y' ],
                [ 'c', 3,     'z' ]
            ],
            arguments =>  [ 'q', undef, 's' ] 
        },
        {   altered => [
                [ 'q', 'r', 's', 't' ],
                [ 'a', 1,   'x' ],
                [ 'b', 2,   'y' ],
                [ 'c', 3,   'z' ]
            ],
            expected => 4,
            description => 'Unshift a longer row',
            arguments   =>  [ 'q', 'r', 's', 't' ] 
        },
        {   arguments =>  [ 'q', 'r' ] ,
            description => 'Unshift column into an empty array',
            expected => 1,
            altered    => [ [ 'q', 'r' ] ],
            test_array  => [],
        }
    ]
);

plan_and_run_generic_tests(\@tests, \%defaults);

