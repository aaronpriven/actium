# Actium/Preamble.pm

# The preamble to Actium perl modules.
# (Moose ones load Actium::Moose, which loads this)
# Imports things that are common to (many) modules.
# inspired by http://www.perladvent.org/2012/2012-12-16.html

# legacy status: 4

package Actium::Preamble 0.010;

use 5.016;
use Module::Runtime (qw(require_module)); ### DEP ###
use Import::Into; ### DEP ###

my ( @module_rs, @nomodule_rs );

BEGIN {
    @module_rs = (
        [qw[Actium::Constants]],
        [   qw[Actium::Util all_eq doe dumpstr flatten
              in isblank isnotblank j jt jk jn]
        ],
        [qw[Carp]],
        [qw[Const::Fast]],
# Const::Fast ### DEP ###
        [qw[Encode encode decode]],
        [qw[English -no-match-vars]],
        [qw[List::MoreUtils any all none notall natatime uniq]],
# List::MoreUtils ### DEP ###
        [qw[List::Util first max min maxstr minstr sum]],
        [qw[POSIX ceil floor]],
        [qw[Params::Validate]],
# Params::Validate ### DEP ###
        [qw[Module::Runtime require_module]],
        [qw[Unicode::Normalize NFC NFD]],
# Unicode::Normalize ### DEP ###
        [qw[Scalar::Util blessed reftype looks_like_number]],
        [qw[autodie]],
        [qw[feature :5.16]],
        #[ 'open', IO => ':encoding(utf-8)' ],
        [qw[open :std :utf8 ]],
        [qw[strict]],
        [qw[utf8]],
        [qw[warnings]],
    );
    @nomodule_rs = ( [qw[indirect]], );
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

1;

__END__

