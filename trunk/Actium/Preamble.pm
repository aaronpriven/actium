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
        [qw[Actium::Util j jt jk jn doe in isblank isnotblank flatten all_eq]],
        [qw[Carp]],
        [qw[Const::Fast]],
        [qw[Data::Dumper]],
        [qw[English -no-match-vars]],
        [qw[List::MoreUtils any all none notall natatime uniq]],
        [qw[List::Util first max min maxstr minstr sum]],
        [qw[POSIX ceil floor]],
        [qw[Params::Validate :all]],
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

use Actium::Constants();
use Actium::Util();
use Const::Fast();
use Carp();
use Data::Dumper();
use English();
use List::MoreUtils();
use List::Util();
use POSIX();
use Params::Validate();
use Scalar::Util();
use autodie();
use indirect();
use strict();
use utf8();
use warnings();

use Import::Into;

sub import {
    my $caller = caller;

    Actium::Constants->import::into($caller);
    Actium::Util->import::into( $caller,
        qw[j jt jk jn doe in isblank isnotblank flatten all_eq] );
    Carp->import::into($caller);
    Const::Fast->import::into($caller);
    Data::Dumper->import::into($caller);
    English->import::into( $caller, '-no-match-vars' );
    List::MoreUtils->import::into( $caller,
        qw[any all none notall natatime uniq] );
    List::Util->import::into( $caller, qw[first max min maxstr minstr sum] );
    POSIX->import::into( $caller, qw[ceil floor] );
    Params::Validate->import::into( $caller, ':all' );
    Scalar::Util->import::into( $caller,
        qw[blessed reftype looks_like_number] );
    autodie->import::into($caller);
    feature->import::into( $caller, ':5.16' );
    indirect->unimport::out_of($caller);
    strict->import::into($caller);
    utf8->import::into($caller);
    warnings->import::into($caller);
} ## tidy end: sub import

1;
