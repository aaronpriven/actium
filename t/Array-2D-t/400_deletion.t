use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

my $del_row_ref
  = [ [ 'a', 1, 'w' ], [ 'b', 2, 'x' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ];

my $del_col_ref = [ [qw/a b c d/], [ 1, 2, 3, 4 ], [qw/w x y z/], ];

my %defaults = (
    del_row   => { test_procedure => 'both', returns_a_list => 1 },
    del_col   => { test_procedure => 'both', returns_a_list => 1 },
    pop_row   => { test_procedure => 'both', returns_a_list => 1 },
    pop_col   => { test_procedure => 'both', returns_a_list => 1 },
    shift_row => { test_procedure => 'both', returns_a_list => 1 },
    shift_col => { test_procedure => 'both', returns_a_list => 1 },
);

my @tests = (
    del_row => [
        {   arguments => [0],
            expected  => [ 'a', 1, 'w' ],
            altered   => [ [ 'b', 2, 'x' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ],
            description => 'delete first row',
            test_array  => $del_row_ref,
        },
        {   arguments => [1],
            expected  => [ 'b', 2, 'x' ],
            altered   => [ [ 'a', 1, 'w' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ],
            description => 'delete middle row',
            test_array  => $del_row_ref,
        },
        {   arguments => [3],
            expected  => [ 'd', 4, 'z' ],
            altered   => [ [ 'a', 1, 'w' ], [ 'b', 2, 'x' ], [ 'c', 3, 'y' ], ],
            description => 'delete last row',
            test_array  => $del_row_ref,
        },
        {   arguments => [-2],
            expected  => [ 'c', 3, 'y' ],
            altered   => [ [ 'a', 1, 'w' ], [ 'b', 2, 'x' ], [ 'd', 4, 'z' ], ],
            description => 'delete row (negative index)',
            test_array  => $del_row_ref,
        },
        {   arguments   => [5],
            expected    => [],
            altered     => Array::2D->clone_unblessed($del_row_ref),
            description => 'delete row (off end of array)',
            test_array  => Array::2D->clone_unblessed($del_row_ref),
        },
        {   arguments   => [1],
            expected    => [],
            altered     => [],
            description => 'delete row from empty array',
            test_array  => [],
        },
        {   arguments => [1],
            expected  => [ 'b', 2 ],
            altered   => [ [ 'a', 1, 'w' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ],
            description => 'delete short row',
            test_array  => [
                [ 'a', 1, 'w' ], [ 'b', 2 ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ],
            ]
        },
        {   arguments => [1],
            expected  => [ 'b', 2, 'x', 9 ],
            altered   => [ [ 'a', 1, 'w' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ],
            description => 'delete long row',
            test_array  => [
                [ 'a', 1, 'w' ],
                [ 'b', 2, 'x', 9 ],
                [ 'c', 3, 'y' ],
                [ 'd', 4, 'z' ],
            ]
        },
        {   arguments => [1],
            expected  => [ 'b', undef, 'x' ],
            altered   => [ [ 'a', 1, 'w' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ],
            description => 'delete row with undefined value',
            test_array  => [
                [ 'a', 1,     'w' ],
                [ 'b', undef, 'x' ],
                [ 'c', 3,     'y' ],
                [ 'd', 4,     'z' ],
            ]
        },
        {   arguments   => [0],
            expected    => [ 'a', 1 ],
            altered     => [],
            description => 'delete only row',
            test_array  => [ [ 'a', 1 ] ],
        },
        {   exception =>
              qr/Modification of non-creatable array value attempted/,
            arguments   => [ -5, 'New value' ],
            description => 'dies with invalid negative index',
            test_array  => $del_row_ref,
        }
    ],
    del_col => [
        {   arguments   => [0],
            expected    => [ 'a', 1, 'w' ],
            altered     => [ [qw/b c d/], [ 2, 3, 4 ], [qw/x y z/], ],
            description => 'delete first column',
            test_array  => $del_col_ref,
        },
        {   arguments   => [1],
            expected    => [ 'b', 2, 'x' ],
            altered     => [ [qw/a c d/], [ 1, 3, 4 ], [qw/w y z/], ],
            description => 'delete middle column',
            test_array  => $del_col_ref,
        },
        {   arguments   => [3],
            expected    => [ 'd', 4, 'z' ],
            altered     => [ [qw/a b c/], [ 1, 2, 3, ], [qw/w x y/], ],
            description => 'delete last column',
            test_array  => $del_col_ref,
        },
        {   arguments   => [-2],
            expected    => [ 'c', 3, 'y' ],
            altered     => [ [qw/a b d/], [ 1, 2, 4 ], [qw/w x z/], ],
            description => 'delete column (negative index)',
            test_array  => $del_col_ref,
        },
        {   arguments   => [5],
            expected    => [],
            altered     => Array::2D->clone_unblessed($del_col_ref),
            description => 'delete column (off end of array)',
            test_array  => Array::2D->clone_unblessed($del_col_ref),
        },
        {   arguments   => [1],
            expected    => [],
            altered     => [],
            description => 'delete column from empty array',
            test_array  => [],
        },
        {   arguments   => [1],
            expected    => [ 'b', 2 ],
            altered     => [ [qw/a c d/], [ 1, 3, 4 ], [qw/w y z/], ],
            description => 'delete short column',
            test_array =>
              [ [qw/a b c d/], [ 1, 2, 3, 4 ], [ 'w', undef, qw/y z/ ], ],
        },
        {   arguments   => [1],
            expected    => [ 'b', 2, 'x', 9 ],
            altered     => [ [qw/a c d/], [ 1, 3, 4 ], [qw/w y z/], ],
            description => 'delete long column',
            test_array =>
              [ [qw/a b c d/], [ 1, 2, 3, 4 ], [qw/w x y z/], [ undef, 9 ], ],

        },
        {   arguments   => [1],
            expected    => [ 'b', undef, 'x' ],
            altered     => [ [qw/a c d/], [ 1, 3, 4 ], [qw/w y z/], ],
            description => 'delete column with undefined value',
            test_array => [ [qw/a b c d/], [ 1, undef, 3, 4 ], [qw/w x y z/], ],
        },

        {   arguments   => [0],
            expected    => [ 'a', 1 ],
            altered     => [],
            description => 'delete only column',
            test_array  => [ ['a'], [1] ],
        },
        {   exception => qr/negative index off the beginning of the array/,
            description => 'dies with invalid negative index',
            arguments   => [ -5, 'New value' ],
            test_array  => $del_col_ref,
        },
    ],
    shift_row => [
        {   expected => [ 'a', 1, 'w' ],
            altered => [ [ 'b', 2, 'x' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ],
            description => 'shift first row',
            test_array  => $del_row_ref,
        },
        {   expected    => [],
            altered     => [],
            description => 'shift row from empty array',
            test_array  => [],
        },
        {   expected => [ 'a', 1 ],
            altered =>
              [ [ 'b', 2, 'x', ], [ 'c', 3, 'y', ], [ 'd', 4, 'z', ], ],
            description => 'shift short row',
            test_array  => [
                [ 'a', 1 ], [ 'b', 2, 'x' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ],
            ]
        },
        {   expected => [ 'a', 1, 'w', 9 ],
            altered => [ [ 'b', 2, 'x' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ],
            description => 'shift long row',
            test_array  => [
                [ 'a', 1, 'w', 9 ],
                [ 'b', 2, 'x' ],
                [ 'c', 3, 'y' ],
                [ 'd', 4, 'z' ],
            ]
        },
        {   expected => [ 'a', undef, 'w' ],
            altered => [ [ 'b', 2, 'x' ], [ 'c', 3, 'y' ], [ 'd', 4, 'z' ], ],
            description => 'shift row with undefined value',
            test_array  => [
                [ 'a', undef, 'w' ],
                [ 'b', 2,     'x' ],
                [ 'c', 3,     'y' ],
                [ 'd', 4,     'z' ],
            ]
        },
        {   expected    => [ 'a', 1 ],
            altered     => [],
            description => 'shift only row',
            test_array => [ [ 'a', 1 ] ],
        },
    ],
    shift_col => [
        {   expected => [ 'a', 1, 'w' ],
            altered => [ [qw/b c d/], [ 2, 3, 4 ], [qw/x y z/], ],
            description => 'shift first column',
            test_array  => $del_col_ref,
        },
        {   expected    => [],
            altered     => [],
            description => 'shift column from empty array',
            test_array  => [],
        },
        {   expected => [ 'a', 1 ],
            altered => [ [qw/b c d/], [ 2, 3, 4 ], [qw/x y z/], ],
            description => 'shift short column',
            test_array =>
              [ [qw/a b c d/], [ 1, 2, 3, 4 ], [ undef, qw/x y z/ ], ],
        },
        {   expected => [ 'a', 1, 'w', 9 ],
            altered => [ [qw/b c d/], [ 2, 3, 4 ], [qw/x y z/], ],
            description => 'shift long column',
            test_array =>
              [ [qw/a b c d/], [ 1, 2, 3, 4 ], [qw/w x y z/], [9], ],

        },
        {   expected => [ 'a', undef, 'w' ],
            altered => [ [qw/b c d/], [ 2, 3, 4 ], [qw/x y z/], ],
            description => 'shift column with undefined value',
            test_array => [ [qw/a b c d/], [ undef, 2, 3, 4 ], [qw/w x y z/], ],
        },
        {   expected    => [ 'a', 1 ],
            altered     => [],
            description => 'shift only column',
            test_array => [ ['a'], [1] ],
        },
    ],
    pop_row => [
        {   expected => [ 'd', 4, 'z' ],
            altered => [ [ 'a', 1, 'w' ], [ 'b', 2, 'x' ], [ 'c', 3, 'y' ], ],
            description => 'pop last row',
            test_array  => $del_row_ref,
        },
        {   expected    => [],
            altered     => [],
            description => 'pop row from empty array',
            test_array  => [],
        },
        {   expected => [ 'd', 4 ],
            altered => [ [ 'a', 1, 'w' ], [ 'b', 2, 'x', ], [ 'c', 3, 'y', ], ],
            description => 'pop short row',
            test_array  => [
                [ 'a', 1, 'w' ],
                [ 'b', 2, 'x' ],
                [ 'c', 3, 'y' ],
                [ 'd', 4, ],
            ]
        },
        {   description => 'pop long row',
            expected    => [ 'd', 4, 'z', 9 ],
            altered => [ [ 'a', 1, 'w' ], [ 'b', 2, 'x', ], [ 'c', 3, 'y', ], ],
            test_array => [
                [ 'a', 1, 'w' ],
                [ 'b', 2, 'x' ],
                [ 'c', 3, 'y' ],
                [ 'd', 4, 'z', 9 ],
              ]

        },
        {   description => 'pop row with undefined value',
            expected    => [ 'd', undef, 'z', ],
            altered => [ [ 'a', 1, 'w' ], [ 'b', 2, 'x', ], [ 'c', 3, 'y', ], ],
            test_array => [
                [ 'a', 1,     'w' ],
                [ 'b', 2,     'x' ],
                [ 'c', 3,     'y' ],
                [ 'd', undef, 'z' ],
            ]
        },
        {   expected    => [ 'a', 1 ],
            altered     => [],
            description => 'pop only row',
            test_array => [ [ 'a', 1 ] ],
        },
    ],
    pop_col => [
        {   expected => [ 'd', 4, 'z' ],
            altered => [ [qw/a b c/], [ 1, 2, 3, ], [qw/w x y/], ],
            description => 'pop last column',
            test_array  => $del_col_ref,
        },
        {   expected    => [],
            altered     => [],
            description => 'pop column from empty array',
            test_array  => [],
        },
        {   expected => [ 'd', 4 ],
            altered => [ [qw/a b c/], [ 1, 2, 3 ], [qw/w x y/], ],
            description => 'pop short column',
            test_array  => [ [qw/a b c d/], [ 1, 2, 3, 4 ], [qw/w x y/], ],
        },
        {   expected => [ 'd', 4, 'z', 9 ],
            altered => [ [qw/a b c/], [ 1, 2, 3 ], [qw/w x y/], ],
            description => 'pop long column',
            test_array  => [
                [qw/a b c d/], [ 1,     2,     3,     4 ],
                [qw/w x y z/], [ undef, undef, undef, 9 ],
            ],

        },
        {   expected => [ 'd', undef, 'z' ],
            altered => [ [qw/a b c/], [ 1, 2, 3 ], [qw/w x y/], ],
            description => 'pop column with undefined value',
            test_array  => [ [qw/a b c d/], [ 1, 2, 3 ], [qw/w x y z/], ],
        },
        {   expected    => [ 'a', 1 ],
            altered     => [],
            description => 'pop only column',
            test_array => [ ['a'], [1] ],
        },
    ],
);

plan_and_run_generic_tests( \@tests, \%defaults );

__END__

my %exception_tests = (
    del_row => qr/Modification of non-creatable array value attempted/,
    del_col => qr/negative index off the beginning of the array/,
);

foreach my $method (qw/del_row del_col pop_row pop_col shift_row shift_col/) {
    a2dcan($method);

    for my $test_r ( @{ $tests{$method} } ) {
        test_deletion( $method, $test_r );
    }

    next if ( $method !~ /del/ );

    my $del_die_obj = Array::2D->clone($del_row_ref);
    my $del_die_ref = Array::2D->clone_unblessed($del_row_ref);

    test_exception { $del_die_obj->$method(-5) }
    '$obj->' . "$method dies with invalid negative indices",
      $exception_tests{$method};

    test_exception { Array::2D->$method( $del_die_ref, -5 ) }
    $method . '($ref) dies with invalid negative indices',
      $exception_tests{$method};

} ## tidy end: foreach my $method (...)

# both low
foreach my $method (qw/del_rows del_cols/) {
    a2dcan($method);

}
done_testing;

sub test_deletion {

    my $method = shift;
    my $test_r = shift;

    my @indices;
    @indices = @{ $test_r->{indices} } if exists $test_r->{indices};
    my $expected    = $test_r->{expected};
    my $description = $test_r->{description};
    my $test_array  = $test_r->{test_array} || $del_row_ref;
    my $remain      = $test_r->{remain};

    my $obj_to_test = Array::2D->clone($test_array);
    my $ref_to_test = Array::2D->clone_unblessed($test_array);

    my @obj_returned = $obj_to_test->$method(@indices);

    #if ( $description =~ /delete long column/ ) {
    #    note "index: @indices";
    #    note "returned:";
    #    note explain \@obj_returned;
    #    note "remaining:";
    #    note explain $obj_to_test;
    #}

    is_deeply( \@obj_returned, $expected, "$method: $description: object" );
    is_deeply( $obj_to_test, $remain,
        "... and remaining values are as expected" );
    is_blessed($obj_to_test);

    my @ref_returned = Array::2D->$method( $ref_to_test, @indices );
    is_deeply( \@ref_returned, $expected, "$method: $description: ref" );
    is_deeply( $ref_to_test, $remain,
        "... and remaining values are as expected" );
    isnt_blessed($ref_to_test);
} ## tidy end: sub test_deletion
