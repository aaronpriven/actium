use strict;
use warnings;
use Test::More 0.98;
use Array::2D;

my $builder = Test::More->builder;
binmode $builder->output,         ":encoding(utf8)";
binmode $builder->failure_output, ":encoding(utf8)";
binmode $builder->todo_output,    ":encoding(utf8)";

use Scalar::Util(qw/blessed reftype/);
use List::MoreUtils ('uniq');

sub is_blessed {
    my $obj         = shift;
    my $description = shift;
    if ( defined $description ) {
        $description = "blessed correctly: $description";
    }
    else {
        $description = '... and result is blessed correctly';
    }
    is( blessed($obj), 'Array::2D', $description );
}

sub isnt_blessed {
    my $obj         = shift;
    my $description = shift;
    if ( defined $description ) {
        $description = "not blessed: $description";
    }
    else {
        $description = '... and result is not blessed';
    }
    is( blessed($obj), undef, $description );
}

sub a2dcan {
    my @methods = @_;

    if ( @_ == 1 ) {
        note "Testing $_[0]()";
    }
    else {
        note "Testing methods: @_";
    }

    can_ok( 'Array::2D', @_ );
}

my $has_test_fatal;

sub test_exception (&;@) {
    my $code        = shift;
    my $description = shift;
    my $regex       = shift;

    if ( not defined $has_test_fatal ) {
        if ( eval { require Test::Fatal; 1 } ) {
            $has_test_fatal = 1;
        }
        else {
            $has_test_fatal = 0;
        }
    }

  SKIP: {
        skip( 'Test::Fatal not available', 2 ) unless $has_test_fatal;

        my $exception_obj = &Test::Fatal::exception($code);
        #  bypass prototype
        isnt( $exception_obj, undef, $description );
        like( $exception_obj, $regex, "... and it's the expected exception" );

    }

} ## tidy end: sub test_exception (&;@)

# @all_tests is a list rather than a hash (even though it consists of pairs)
# because I want to test the methods in order

sub plan_and_run_generic_tests {
    my @all_tests  = @{ +shift };
    my $defaults_r = shift;

    my $test_count = generic_test_count( \@all_tests, $defaults_r );

    note "result of generic test count: $test_count";

    plan( tests => $test_count );

    run_generic_tests( \@all_tests, $defaults_r );

    done_testing;

}

sub run_generic_tests {

    my @all_tests  = @{ +shift };
    my $defaults_r = shift;

    while (@all_tests) {
        my $method  = shift @all_tests;
        my $tests_r = shift @all_tests;

        a2dcan($method);

        foreach my $test_r ( @{$tests_r} ) {
            generic_test( $method, $test_r, $defaults_r, );
        }

    }

}

my %proper_blessing = ( object => 'Array::2D', ref => undef );

sub generic_test_count {
    my @all_tests  = @{ +shift };
    my $defaults_r = shift;

    my $test_count = 0;

    while (@all_tests) {
        my $method = shift @all_tests;
        my @tests  = @{ shift @all_tests };
        $test_count += 1;
        # one test per method (a2dcan)

        # two tests (obj and ref) per test in %tests
        # That's why each of the below adds two per test and not just one

        foreach my $test_r (@tests) {

            my %t = _get_test_factors( $method, $test_r, $defaults_r );

            if ( exists $t{exception} ) {
                $test_count += 4;
                next;
            }
            # if there's an exception, add two, and skip the rest because
            # they're not used if there's an exception test.

            # all other counts are just placeholders for now
            for ( $t{test_procedure} ) {
                if ( $_ eq 'results' ) {
                    $test_count += 3 * 2;
                    # result is right,
                    # array hasn't changed,
                    # blessing of array hasn't changed
                }
                elsif ( $_ eq 'altered' ) {
                    $test_count += 2 * 2;
                    # array has changed correctly,
                    # blessing of array hasn't changed
                }
                elsif ( $_ eq 'both' ) {
                    $test_count += 3 * 2;
                    # result is right,
                    # array has changed correctly,
                    # blessing of array hasn't changed
                }
                else {    # ($_ eq 'contextual')
                    $test_count += 5 * 2;
                    # result is right,
                    # array hasn't changed,
                    # blessing of array hasn't changed
                    # in-place result is right,
                    # blessing of array after in-place hasn't changed
                }
            } ## tidy end: for ( $t{test_procedure...})

            if (   exists $test_r->{warning}
                or exists $defaults_r->{$method}{warning} )
            {
                $test_count += 2;
                $test_count += 2 if $t{test_procedure} eq 'contextual';
            }
            if ( $t{check_blessing} and $t{test_procedure} ne 'altered' ) {
                $test_count += 2;
            }

        } ## tidy end: foreach my $test_r (@tests)

    } ## tidy end: while (@all_tests)

    return $test_count;

} ## tidy end: sub generic_test_count

my $has_test_warnings;

sub _run_code_and_warn_maybe (&@) {
    my ( $code, $regex, $description ) = @_;

    if ( not defined $regex ) {
        $code->();
        return;
    }

    if ( not defined $has_test_warnings ) {
        if ( eval { require Test::Warnings; 1 } ) {
            Test::Warnings->import(':no_end_test');
            $has_test_warnings = 1;
        }
        else {
            $has_test_warnings = 0;
        }
    }

    if ($has_test_warnings) {
        my $warning = Test::Warnings::warning( $code );
        like( $warning, $regex, "$description: correct warning" )
          or diag "$description: got unexpected warning(s): ",
          explain($warning);
    }
    else {
        $code->();
      SKIP: {
            skip( "$description: skipped: Test::Warnings not available", 1 );
        }

    }
    return;
} ## tidy end: sub _run_code_and_warn_maybe (&@)

sub generic_test {

    my $method = shift;
    my %t = _get_test_factors( $method, @_ );

    # test => results - test results, ensure array doesn't change.
    # test => altered - test array change, ignore results
    # test => both - test results, also test array change
    # test => contextual -- in non-void context, just like 'results' --
    #    array doesn't change, test results.
    #    in void context, array changes to what results
    #    would have been in non-void context.

    # in all cases, array should stay blessed as before.
    # results should be blessed if $t{check_blessing} is true

    my $description = $t{description};    # easier to interpolate

    my @arguments = _get_arguments( \%t );

    my %to_test = (
        object => Array::2D->clone( $t{test_array} ),
        ref    => Array::2D->clone_unblessed( $t{test_array} )
    );

    my %process = (
        object => sub { $to_test{object}->$method(@arguments) },
        ref    => sub { Array::2D->$method( $to_test{ref}, @arguments ) }
    );

    if ( $t{exception} ) {
        test_exception { $process{object}->() } $t{description}, $t{exception};
        test_exception { $process{ref}->() } $t{description},    $t{exception};
        return;
    }

    foreach my $array_type (qw/object ref/) {
        my $returned;
        _run_code_and_warn_maybe(
            sub {
                $returned
                  = $t{returns_a_list}
                  ? [ $process{$array_type}->() ]
                  : $process{$array_type}->();
            },
            $t{warning},
            $description
        );

        if ( $t{test_procedure} ne 'altered' ) {
            is_deeply( $returned, $t{expected},
                "$method: $description: $array_type: correct result" );

            if ( $t{check_blessing} ) {
                if ($t{check_blessing} eq 'always'
                    or (    $t{check_blessing} eq 'as_orignal'
                        and $array_type eq 'object' )
                  )
                {
                    is_blessed($returned);
                }
                elsif ( $t{check_blessing} eq 'as_original' ) {
                    isnt_blessed($returned);
                }
                else {
                    BAIL_OUT 'Unknown blessing check type: '
                      . $t{check_blessing};
                }
            }

        } ## tidy end: if ( $t{test_procedure...})

        if ( $t{test_procedure} eq 'altered' or $t{test_procedure} eq 'both' ) {
            BAIL_OUT 'Bad "altered" test factor'
              unless reftype( $t{altered} ) eq 'ARRAY';
            is_deeply( $to_test{$array_type}, $t{altered},
                "$method: $description: altered $array_type correctly" );
        }
        else {
            is_deeply( $to_test{$array_type}, $t{test_array},
                "... and it did not alter the $array_type" );
        }

        is( blessed( $to_test{$array_type} ),
            $proper_blessing{$array_type},
            "... and blessing of $array_type did not change"
        );

    } ## tidy end: foreach my $array_type (qw/object ref/)

    if ( $t{test_procedure} eq 'contextual' ) {

        %to_test = (
            object => Array::2D->clone( $t{test_array} ),
            ref    => Array::2D->clone_unblessed( $t{test_array} )
        );

        %process = (
            object => sub { $to_test{object}->$method(@arguments) },
            ref    => sub { Array::2D->$method( $to_test{ref}, @arguments ) }
        );

        foreach my $array_type (qw/object ref/) {
            _run_code_and_warn_maybe { $process{$array_type}->() }
            $t{warning}, $description;
            is_deeply( $to_test{$array_type}, $t{expected},
                "$method in place: $description: $array_type: altered correctly"
            );

            is( blessed( $to_test{$array_type} ),
                $proper_blessing{$array_type},
                "... and blessing of $array_type did not change"
            );
        }

    } ## tidy end: if ( $t{test_procedure...})

    return;

} ## tidy end: sub generic_test

my %is_valid_test_factor = map { $_ => 1 } qw[
  altered  arguments      check_blessing description exception
  expected returns_a_list test_procedure test_array  warning
];

# altered - expected value of new altered array
# arguments - arguments to be passed to method
# check_blessing - check to see if results are blessed
# description - text to be displayed in output
# exception - if present, overrides 'test'.  Method should generate exception.
#    Value is a regex to be tested against that exception to make sure it's
#    the right one.
# expected - expected value of results
# returns_a_list - whether results is a list (as row(), col() ) and needs to
# have an arrayref thrown around it before comparing it.
# test - test procedure, below
# test_array - array values to be tested against. This will be cloned into
#   new object and new reference
# warning - Method should generate warning. Value is a regex to be tested
#   against that warning to make sure it's the right one.
#

my %is_valid_test_procedure
  = map { $_ => 1 } qw/results altered both contextual/;
# test => results - test results, ensure array doesn't change
# test => altered - test array change, ignore results
# test => both - test results, also test array change
# test => contextual -- in non-void context, array doesn't change,
#    test results. in void context, array changes to what results
#       would have been in non-void context.

sub _get_test_factors {

    my $method = shift;
    my %t;
    my $test_r = shift;
    my $defaults_r = shift // {};

    my @keys = uniq sort ( keys %$test_r, keys %{ $defaults_r->{$method} } );

    foreach my $test_factor (@keys) {

        BAIL_OUT("Unknown test factor $test_factor")
          if not $is_valid_test_factor{$test_factor};

        if ( exists $test_r->{$test_factor} ) {
            $t{$test_factor} = $test_r->{$test_factor};
        }
        elsif ( exists $defaults_r->{$method}{$test_factor} ) {
            $t{$test_factor} = $defaults_r->{$method}{$test_factor};
        }
    }

    $t{test_procedure} //= 'results';

    BAIL_OUT 'Unknown test procedure ' . $t{test_procedure}
      unless $is_valid_test_procedure{ $t{test_procedure} };

    return %t;

} ## tidy end: sub _get_test_factors

sub _get_arguments {
    my $t_r = shift;

    my @arguments;

    if ( defined $t_r->{arguments} ) {
        if ( ref $t_r->{arguments} eq 'ARRAY' ) {
            @arguments = @{ $t_r->{arguments} };
        }
        else {
            @arguments = $t_r->{arguments};
        }
    }

    return @arguments;

}

1;
