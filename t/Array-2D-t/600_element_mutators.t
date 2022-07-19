use strict;
use warnings;

BEGIN {
    do './t/lib/testutil.pl' // do './lib/testutil.pl'
      // die "Can't load testutil.pl";
}

my $apply_ref = [
    [ 'a', 'q ' ],
    [ ' b ', ' r',  "\rx", undef ],
    [ undef, "s\n", 'y ' ],
    [ 'd ',  ' t ', undef, 'z' ],
];

my $apply_onerow_ref = [ [ 'd ', ' t ', undef, 'z' ], ];
my $apply_onecol_ref = [ ['a'], [' b '], [undef], ['d '] ];

my $apply_coderef = sub { tr/arty/ARTY/ if defined($_) };

my %defaults = (
    apply => {
        test_procedure  => 'contextual',
        arguments     => $apply_coderef,
        test_array    => $apply_ref,
        check_blessing => 'always',
    },
    trim => {
        test_procedure  => 'contextual',
        test_array    => $apply_ref,
        check_blessing => 'always',
    },
    trim_right => {
        test_procedure  => 'contextual',
        test_array    => $apply_ref,
        check_blessing => 'always',
    },
    define => {
        test_procedure  => 'contextual',
        test_array    => $apply_ref,
        check_blessing => 'always',
    },
);

my @tests = (
    apply => [
        {   description => 'an array',
            expected    => [
                [ 'A', 'q ' ],
                [ ' b ', ' R',  "\rx", undef ],
                [ undef, "s\n", 'Y ' ],
                [ 'd ',  ' T ', undef, 'z' ],
            ],
        },
        {   description => 'a one-row array',
            expected    => [ [ 'd ', ' T ', undef, 'z' ], ],
            test_array  => $apply_onerow_ref,
        },
        {   description => 'a one-column array',
            expected    => [ ['A'], [' b '], [undef], ['d '], ],
            test_array  => $apply_onecol_ref,
        },
        {   description => 'an empty array',
            expected    => [],
            test_array  => [],
        }
    ],
    trim => [
        {   description => 'an array',
            expected    => [
                [ 'a', 'q' ],
                [ 'b',   'r', 'x',   undef ],
                [ undef, 's', 'y' ],
                [ 'd',   't', undef, 'z' ],
            ],
        },
        {   description => 'a one-row array',
            expected    => [ [ 'd', 't', undef, 'z' ], ],
            test_array  => $apply_onerow_ref,
        },
        {   description => 'a one-column array',
            expected    => [ ['a'], ['b'], [undef], ['d'], ],
            test_array  => $apply_onecol_ref,
        },
        {   description => 'an empty array',
            expected    => [],
            test_array  => [],
        }
    ],
    trim_right => [
        {   description => 'an array',
            expected    => [
                [ 'a', 'q' ],
                [ ' b',  ' r', "\rx", undef ],
                [ undef, 's',  'y' ],
                [ 'd',   ' t', undef, 'z' ],
            ],
        },
        {   description => 'a one-row array',
            expected    => [ [ 'd', ' t', undef, 'z' ], ],
            test_array  => $apply_onerow_ref,
        },
        {   description => 'a one-column array',
            expected    => [ ['a'], [' b'], [undef], ['d'], ],
            test_array  => $apply_onecol_ref,
        },
        {   description => 'an empty array',
            expected    => [],
            test_array  => [],
        }
    ],
    define => [
        {   description => 'an array',
            expected    => [
                [ 'a', 'q ' ],
                [ ' b ', ' r',  "\rx", '' ],
                [ '',    "s\n", 'y ' ],
                [ 'd ',  ' t ', '',    'z' ],
            ],
        },
        {   description => 'a one-row array',
            expected    => [ [ 'd ', ' t ', '', 'z' ], ],
            test_array  => $apply_onerow_ref,
        },
        {   description => 'a one-column array',
            expected    => [ ['a'], [' b '], [''], ['d '], ],
            test_array  => $apply_onecol_ref,
        },
        {   description => 'an empty array',
            expected    => [],
            test_array  => [],
        }
    ],
);

plan_and_run_generic_tests(\@tests, \%defaults);

__END__

sub test_application {

    my $method = shift;
    my $test_r = shift;

    my $expected    = $test_r->{expected};
    my $description = $test_r->{description};
    my $test_array  = $test_r->{test_array} // $apply_ref;

    my @coderef;
    @coderef = ( $test_r->{coderef} // $apply_coderef )
      if $method eq 'apply';

    my $obj_to_test = Array::2D->clone($test_array);
    my $ref_to_test = Array::2D->clone_unblessed($test_array);

    my $obj_returned = $obj_to_test->$method(@coderef);

    #note "returned:";
    #note explain $obj_returned;
    #note "expected:";
    #note explain $expected;

    is_deeply( $obj_returned, $expected, "$method: $description: object" );
    is_blessed($obj_to_test);

    my $ref_returned = Array::2D->$method( $ref_to_test, @coderef );
    is_deeply( $ref_returned, $expected, "$method : $description: ref" );
    isnt_blessed($ref_to_test);

    $obj_to_test->$method(@coderef);

    is_deeply( $obj_to_test, $expected,
        "$method in place: $description: object" );
    is_blessed( $obj_to_test, "... and it's still blessed" );
    Array::2D->$method( $ref_to_test, @coderef );
    is_deeply( $ref_returned, $expected,
        "$method in place: $description: ref" );
    isnt_blessed( $ref_to_test, "... and it's still not blessed" );

    return;

} ## tidy end: sub test_application

my $test_count = 0;
foreach my $method ( keys %tests ) {
    $test_count += scalar @{ $tests{$method} };
}

plan( tests => ( 4 + ( 8 * $test_count ) ) );

foreach my $method (qw/apply trim trim_right define/) {
    a2dcan($method);

    for my $test_r ( @{ $tests{$method} } ) {
        test_application( $method, $test_r );
    }
}

done_testing;
