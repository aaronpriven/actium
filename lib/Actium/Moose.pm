package Actium::Moose 0.012;

use 5.016;

# Actium::Moose

# The preamble to Moose Actium perl modules
# Imports things that are common to (many) modules.
# inspired by
# http://blogs.perl.org/users/ovid/2013/09/building-your-own-moose.html

use Moose();                             ### DEP ###
use MooseX::StrictConstructor();         ### DEP ###
use MooseX::SemiAffordanceAccessor();    ### DEP ###
use MooseX::MarkAsMethods();             ### DEP ###
use Moose::Util::TypeConstraints();      ### DEP ###
use MooseX::MungeHas();                  ### DEP ###
use Actium::Preamble();
use Import::Into;                        ### DEP ###

use Moose::Exporter;                     ### DEP ###
Moose::Exporter->setup_import_methods( also => ['Moose'] );

# The C< import ( into => ... ) > syntax is provided by those modules,
# (via Moose::Exporter which uses Sub::Exporter, or Exporter::Tiny). 
# Other modules using other export functions must use Import::Into

sub init_meta {
    my $class     = shift;
    my %params    = @_;
    my $for_class = $params{for_class};
    Moose->init_meta(@_);
    MooseX::MarkAsMethods->import( { into => $for_class }, autoclean => 1 );
    MooseX::StrictConstructor->import( { into => $for_class } );
    MooseX::SemiAffordanceAccessor->import( { into => $for_class } );
    Moose::Util::TypeConstraints->import( { into => $for_class } );
    MooseX::MungeHas->import::into($for_class);
    Kavorka->import::into( $for_class, qw/method -allmodifiers/ );
    Actium::Preamble->import::into($for_class);
    # Actium::Preamble must be at the end so "no warnings experimental" in
    # preamble overrides warnings turned on by Moose, etc.
}

# here because, why bother putting it in util?

sub u::immut {
    my $package = caller;
    $package->meta->make_immutable;
}

1;

__END__


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

=item B<< immut() >>

A function that makes a Moose class immutable. It is recommended that Moose
classes be made immutable once they are defined because because 
they are much faster that way. Normally one does this by putting

 __PACKAGE__->meta->make_immutable

at the end of the class. This function allows replacement of that unwieldy 
code with something that's easier to type.
    
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

