package Actum::MooseX::IsCodeRef 0.013;

use strict;
use warnings;

use Moose 1.99 ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use Ref::Util('is_coderef');
# use Actium::MooseX::IsCodeRef::Role::Attribute;

my %metaroles = (
    class_metaroles =>
      { attribute => ['Actium::MooseX::IsCodeRef::Role::Attribute'], },
    role_metaroles =>
      { applied_attribute => ['Actium::MooseX::IsCodeRef::Role::Attribute'], },
);

Moose::Exporter->setup_import_methods(%metaroles);

package Actium::MooseX::IsCodeRef::Role::Attribute 0.013;

use Moose::Role;

before '_process_options' => sub {
    my $class   = shift;
    my $name    = shift;
    my $options = shift;

    my ( $builderref, $buildername );

    if ( $name =~ /\A_/ ) {
        $buildername = '_build$name';
    }
    else {
        $buildername = '_build_$name';
    }

    if ( exists $options->{lazy} and is_coderef( $options->{lazy} ) ) {
        $builderref = $options->{lazy};
        $options->{lazy} = 1;
    }

    if ( exists $options->{builder} ) {
        if ( is_coderef( $options->{builder} ) ) {
            $builderref = $options->{builder};
        }
        else {
            $buildername = $options->{builder};
        }
    }

    if ($builderref) {
        $class->meta->add_method( $buildername => $builderref );
        $options->{builder} //= $buildername;
    }

};

no Moose::Role;

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
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 ACKNOWLEDGEMENTS

This module is an adaptaion of Dave Rolsky's
MooseX::SemiAffordanceAccessor.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

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

