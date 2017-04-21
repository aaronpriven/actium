package Actium::Preamble 0.011;

# The preamble to Actium perl modules.
# (Moose ones load Actium::Moose, which loads this)
# Imports things that are common to (many) modules.
# inspired by http://www.perladvent.org/2012/2012-12-16.html

use 5.022;
use Module::Runtime (qw(require_module));    ### DEP ###
use Import::Into;                            ### DEP ###

my ( @module_rs, @nomodule_rs );

# pragmata, or other modules that import directly into the caller's packages

BEGIN {
    @module_rs = (
        [qw[Actium::Constants]],
        [qw[Actium::Crier cry last_cry]],
        [qw[Carp]],
        # Carp ### DEP ###
        [qw[Const::Fast]],
        # Const::Fast ### DEP ###
        [qw[English -no-match-vars]],
        # English ### DEP ###
        [qw[autodie]],
        # autodie ### DEP ###
        [qw[feature :5.16 refaliasing postderef postderef_qq ]],
        # feature ### DEP ###
        #[ 'open', IO => ':encoding(utf-8)' ],
        [qw[open :std :utf8 ]],
        # open ### DEP ###
        [qw[strict]],
        # strict ### DEP ###
        [qw[utf8]],
        # utf8 ### DEP ###
        [qw[warnings]],
        # warnings ### DEP ###
    );
    @nomodule_rs = (
        [qw[indirect]],
        [qw[warnings experimental::refaliasing experimental::postderef]]
    );
    # indirect ### DEP ###

    foreach my $module_r ( @module_rs, @nomodule_rs ) {
        require_module( $module_r->[0] );
    }
} ## tidy end: BEGIN

sub import {
    my $caller = caller;

    foreach my $module_r (@module_rs) {
        my @args   = @{$module_r};
        my $module = shift @args;
        $module->import::into( $caller, @args );
    }
    foreach my $module_r (@nomodule_rs) {
        my @args   = @{$module_r};
        my $module = shift @args;
        $module->unimport::out_of( $caller, @args );
    }
}

# Modules that import into u::

BEGIN {
    # make the 'u' package an alias to this package
    no strict 'refs';
    *u:: = \*Actium::Preamble::;
}

use Actium::Constants;
#use Actium::Crier(':all');
use Actium::Sorting::Line(qw/byline sortbyline/);
use Actium::Util(':all');
use Carp qw(cluck longmess shortmess);    ### DEP ###
use Const::Fast;                          ### DEP ###
use HTML::Entities (qw[encode_entities decode_entities]);    ### DEP ###
use List::AllUtils(':all');                                  ### DEP ###
use Params::Validate;                                        ### DEP ###
use POSIX (qw/ceil floor/);                                  ### DEP ###
use Text::Trim;                                              ### DEP ###
use Ref::Util (':all');                                      ### DEP ###

BEGIN {
    # modules with no 'all' tag
    require Scalar::Util;
    Scalar::Util::->import(@Scalar::Util::EXPORT_OK);
    require Hash::Util;
    Hash::Util::->import(@Hash::Util::EXPORT_OK);
}

# The following work around a bug in Hash::Util.
# I submitted the patch that fixed it in perl 5.23.3

no warnings 'redefine'; # otherwise it complains. 

sub lock_hashref_recurse  {
    goto &Hash::Util::lock_hashref_recurse ;
}

sub unlock_hashref_recurse  {
    goto &Hash::Util::unlock_hashref_recurse ;
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
