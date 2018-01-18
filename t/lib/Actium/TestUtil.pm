package Actium::TestUtil 0.014;
use strict;
use warnings;

use Test::More 0.98;

BEGIN {
    my $builder = Test::More->builder;
    binmode $builder->output,         ":encoding(utf8)";
    binmode $builder->failure_output, ":encoding(utf8)";
    binmode $builder->todo_output,    ":encoding(utf8)";
}

use parent 'Exporter';
our @EXPORT = qw/is_blessed isnt_blessed test_exception/;

use Scalar::Util(qw/blessed/);

sub is_blessed {
    my $obj         = shift;
    my $class       = shift;
    my $description = shift;
    if ( defined $description ) {
        $description = "blessed into $class: $description";
    }
    else {
        $description = "... and result is blessed into $class";
    }
    is( blessed($obj), $class, $description );
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

}

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
        my $warning = Test::Warnings::warning($code);
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
}

1;

__END__

=head1 COPYRIGHT & LICENSE

Copyright 2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

