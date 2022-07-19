use strict;
use warnings;

use Test::More 0.98;
use lib './lib';
use Array::2D;

BEGIN {
    require 'testutil.pl';
}

# $sample_test is the reference to which things are compared

our $sample_ref = [
    [ 'Joshua',      29, 'San Mateo',     undef,             'Hannah' ],
    [ 'Christopher', 59, 'New York City', undef,             'Alexis' ],
    [ 'Emily',       25, 'Dallas',        'Aix-en-Provence', 'Michael' ],
    [ 'Nicholas',    -14, ],
    [ 'Madison', 8, 'Vallejo' ],
    [ 'Andrew',  -15, ],
    [ 'Hannah', 38, 'Romita',     undef, 'Joshua', ],
    [ 'Ashley', 57, 'Ray' ],
    [ 'Alexis', 50, 'San Carlos', undef, 'Christopher' ],
    [ 'Joseph', 0,  'San Francisco' ],
];

# $sample_ref is used when testing class method invocation

our $sample_obj = Array::2D->new(
    [ 'Joshua',      29, 'San Mateo',     undef,             'Hannah' ],
    [ 'Christopher', 59, 'New York City', undef,             'Alexis' ],
    [ 'Emily',       25, 'Dallas',        'Aix-en-Provence', 'Michael' ],
    [ 'Nicholas',    -14, ],
    [ 'Madison', 8, 'Vallejo' ],
    [ 'Andrew',  -15, ],
    [ 'Hannah', 38, 'Romita',     undef, 'Joshua', ],
    [ 'Ashley', 57, 'Ray' ],
    [ 'Alexis', 50, 'San Carlos', undef, 'Christopher' ],
    [ 'Joseph', 0,  'San Francisco' ],
);
# $sample_obj is used when testing object invocation

our $sample_transposed_ref = [
    [   'Joshua',  'Christopher', 'Emily',  'Nicholas',
        'Madison', 'Andrew',      'Hannah', 'Ashley',
        'Alexis',  'Joseph',
    ],
    [ 29, 59, 25, -14, 8, -15, 38, 57, 50, 0, ],
    [   'San Mateo',  'New York City', 'Dallas', undef,
        'Vallejo',    undef,           'Romita', 'Ray',
        'San Carlos', 'San Francisco',
    ],
    [ undef, undef, 'Aix-en-Provence' ],
    [   'Hannah', 'Alexis', 'Michael', undef,
        undef,    undef,    'Joshua',  undef,
        'Christopher'
    ],
];

our $one_row_obj
  = Array::2D->new( [ 'Michael', 31, 'Union City', 'Vancouver', 'Emily' ], );

our $one_row_ref = [ [ 'Michael', 31, 'Union City', 'Vancouver', 'Emily' ], ];

our $one_col_ref = [
    ['Times'],  ['Helvetica'], ['Courier'], ['Lucida'],
    ['Myriad'], ['Minion'],    ['Syntax'],  ['Johnston'],
    ['Univers'], ['Frutiger'],
];

our $one_col_obj = Array::2D->new(
    ['Times'],  ['Helvetica'], ['Courier'], ['Lucida'],
    ['Myriad'], ['Minion'],    ['Syntax'],  ['Johnston'],
    ['Univers'], ['Frutiger'],
);

# note that one_row_test and one_col_test are not 2D arrays, but
# a single row or column
our $one_row_test = [ 'Michael', 31, 'Union City', 'Vancouver', 'Emily' ];
our $one_col_test = [
    'Times',  'Helvetica', 'Courier', 'Lucida', 'Myriad', 'Minion',
    'Syntax', 'Johnston',  'Univers', 'Frutiger',
];

1;