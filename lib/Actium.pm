package Actium 0.013;

# The preamble to Actium perl modules.
# Imports things that are common to (many) modules.
# inspired by http://www.perladvent.org/2012/2012-12-16.html

use 5.024;
use utf8;

BEGIN {
    # make the 'u' package an alias to this package
    no strict 'refs';
    *u:: = \*Actium::;
}

use Actium::Constants;
use Actium::Sorting::Line(qw/byline sortbyline/);
use Actium::Util(
    qw(add_before_extension define dumpstr feq file_ext filename
      flatten folded_in immut in
      joinempty joinkey joinlf joinseries joinseries_with jointab
      u_columns u_wrap)
);
use Carp;           ### DEP ###
use Const::Fast;    ### DEP ###
use HTML::Entities (qw[encode_entities]);    ### DEP ###
use Import::Into;                            ### DEP ###
use List::Util (qw(all any first max min none sum uniq));    ### DEP ###
use List::MoreUtils                                          ### DEP ###
  (qw(firstidx mesh natatime));
# List::MoreUtils::XS  ### DEP ###
use Module::Runtime  (qw(require_module));                   ### DEP ###
use POSIX            (qw/ceil floor/);                       ### DEP ###
use Params::Validate (qw(validate));                         ### DEP ###
use Ref::Util                                                ### DEP ###
  ( qw( is_arrayref is_blessed_ref is_coderef is_hashref
      is_ioref is_plain_arrayref is_plain_hashref is_ref)
  );
use Scalar::Util                                             ### DEP ###
  (qw( blessed looks_like_number refaddr reftype ));
use Text::Trim('trim');                                      ### DEP ###

{

    my $caller;

    sub do_import {
        my $module = shift;
        require_module($module);
        $module->import::into( $caller, @_ );
    }

    sub do_unimport {
        my $module = shift;
        require_module($module);
        $module->unimport::out_of( $caller, @_ );
    }

    sub import {
        my $class = shift;
        my $type = shift || q{};
        $caller = caller;

        if ($type) {
            if ( $type eq 'class' or $type eq 'class_nomod' ) {
                do_import 'Moose';
            }
            elsif ( $type eq 'role' ) {
                do_import 'Moose::Role';
            }
            else {
                croak "Unknown module type $type";
            }

            # either class or role

            do_import 'MooseX::MarkAsMethods', autoclean => 1;
            do_import 'MooseX::StrictConstructor';
            do_import 'MooseX::SemiAffordanceAccessor';
            do_import 'Moose::Util::TypeConstraints';
            do_import 'MooseX::MungeHas';
        }

        do_import 'Kavorka', kavorka_args($type);

        do_import 'Actium::Constants';
        do_import 'Actium::Crier', qw/cry last_cry/;
        do_import 'Carp';
        do_import 'Const::Fast';
        do_import 'English', '-no_match_vars';

        do_import 'autodie';
        do_import 'feature', qw/:5.24 refaliasing postderef_qq/;
        do_unimport 'indirect';
        do_import 'open', qw/:std :utf8/;
        do_import 'strict';
        do_import 'utf8';
        do_import 'warnings';
        do_unimport 'warnings', 'experimental::refaliasing',
          'experimental::postderef';

    } ## tidy end: sub import

}

sub kavorka_args {
    my $type = shift;
    my @args;
    if ( $type eq 'class' or $type eq 'role' ) {
        @args = qw/method -allmodifiers/;
    }
    elsif ( $type eq 'class_nomod' ) {
        @args = qw/method/;
    }
    return ( fun => { -as => 'func' }, @args );
}

# The reason for importing 'fun' as 'func' is twofold:
# 1) Eclipse supports Method::Signatures keywords ("func" and "method")
# 2) I think it looks weird to have the abbreviation for one word
#    be another word

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

