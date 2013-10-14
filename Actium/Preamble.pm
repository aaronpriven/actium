# Actium/Preamble.pm

# The preamble to Actium perl modules.
# (Moose ones load Actium::Moose, which loads this)
# Imports things that are common to (many) modules.
# inspired by http://www.perladvent.org/2012/2012-12-16.html

# Subversion: $Id$

# legacy status: 4

package Actium::Preamble 0.003;

use 5.016;
use Module::Runtime (qw(require_module));
use Import::Into;

my ( @module_rs, @nomodule_rs );

BEGIN {
    @module_rs = (
        [qw[Actium::Constants]],
        [qw[Actium::Util all_eq doe flatten in isblank isnotblank j jt jk jn]],
        [qw[Carp]],
        [qw[Const::Fast]],
        [qw[Data::Dumper]],
        [qw[Encode encode decode]],
        [qw[English -no-match-vars]],
        [qw[List::MoreUtils any all none notall natatime uniq]],
        [qw[List::Util first max min maxstr minstr sum]],
        [qw[POSIX ceil floor]],
        [qw[Params::Validate :all]],
        [qw[Module::Runtime require_module]],
        [qw[Unicode::Normalize NFC NFD]],
        [qw[Scalar::Util blessed reftype looks_like_number]],
        [qw[autodie]],
        [qw[feature :5.16]],
        [qw[strict]],
        [qw[utf8]],
        [qw[warnings]],
    );
    @nomodule_rs = ( [qw[indirect]], );

    foreach my $module_r ( @module_rs, @nomodule_rs ) {
        require_module( $module_r->[0] );
    }
} ## tidy end: BEGIN

sub import {
    my $caller = caller;

    foreach my $module_r (@module_rs) {
        my $module = shift @{$module_r};
        $module->import::into( $caller, @{$module_r} );
    }
    foreach my $module_r (@nomodule_rs) {
        my $module = shift @{$module_r};
        $module->unimport::out_of( $caller, @{$module_r} );
    }
}

1;

__END__

