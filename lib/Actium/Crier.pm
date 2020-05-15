package Actium::Crier 0.010;

use 5.022;
use warnings;

# Avoiding Actium::Preamble because that module will probably load this one

use Const::Fast;
use Carp;
use Module::Runtime ('require_module');

# Actium::O::Crier is require'd at runtime to avoid a circular dependency
# in Actium::Preamble, which is used by Actium::O::Crier.

const my $CRIERCLASS => 'Actium::O::Crier';

use Sub::Exporter -setup => {
    exports => [
        'cry','last_cry',
        'cry_text',
        'default_crier' => \&_build_default_crier,
    ]
};
# Sub::Exporter ### DEP ###

my $default_crier;

sub _build_default_crier {
    my ( $class, $name, $arg ) = @_;

    require_module($CRIERCLASS);

    if ( defined $arg and scalar keys %{$arg} ) {
        if ($default_crier) {
            croak 'Arguments given in '
              . q{"use }
              . __PACKAGE__
              . q{ (default_crier => {args})"}
              . q{ but the default crier has already been initialized};
        }

        $default_crier = $CRIERCLASS->new($arg);
        return sub {
            return $default_crier;
        };
    }

    return sub {
        $default_crier = $CRIERCLASS->new()
          if not $default_crier;
        return $default_crier;
      }

} ## tidy end: sub _build_default_crier

sub _init_default_crier {
    return if $default_crier;
        require_module($CRIERCLASS);
        $default_crier = $CRIERCLASS->new();
}

sub cry {
    _init_default_crier;
    $default_crier->cry(@_);
}

sub cry_text {
    _init_default_crier;
    return $default_crier->text(@_);
}

sub last_cry {
    _init_default_crier;
    return $default_crier->last_cry();
}

1;

__END__


=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
