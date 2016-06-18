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
        [qw[Actium::Util in jt ]],
        [qw[Carp]],
        # Carp ### DEP ###
        [qw[Const::Fast]],
        # Const::Fast ### DEP ###
        [qw[English -no-match-vars]],
        # English ### DEP ###
        [qw[Module::Runtime require_module]],
        # Module::Runtime ### DEP ###
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

BEGIN {
    # modules with no 'all' tag
    require Scalar::Util;
    Scalar::Util::->import(@Scalar::Util::EXPORT_OK);
    require Hash::Util;
    Hash::Util::->import(@Hash::Util::EXPORT_OK);
}

# The following work around a bug in Hash::Util.
# I submitted the patch that fixed it in perl 5.23.3

sub lock_hashref_recurse  {
    goto &Hash::Util::lock_hashref_recurse ;
}

sub unlock_hashref_recurse  {
    goto &Hash::Util::unlock_hashref_recurse ;
}

1;

__END__
