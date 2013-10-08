# Actium/Preamble.pm

# The preamble to non-Moose Actium perl modules.
# Imports things that are common to (many) modules.
# inspired by http://www.perladvent.org/2012/2012-12-16.html

# Subversion: $Id$

# legacy status: 4

use 5.016;

package Actium::Preamble 0.003;

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

use import::into;

sub import {
    my $c = caller;

    Actium::Constants->import::into($c);
    Actium::Util->import::into( $c,
        qw[j jt jk jn doe in isblank isnotblank flatten all_eq] );
    Carp->import::into($c);
    Const::Fast->import::into($c);
    Data::Dumper->import::into($c);
    English->import::into( $c, '-no-match-vars' );
    List::MoreUtils->import::into( $c, qw[any all none notall natatime uniq] );
    List::Util->import::into( $c, qw[first max min maxstr minstr sum] );
    POSIX->import::into( $c, qw[ceil floor] );
    Params::Validate->import::into( $c, ':all' );
    Scalar::Util->import::into( $c, qw[blessed reftype looks_like_number] );
    autodie->import::into($c);
    feature->import::into( $c, ':5.16' );
    indirect->unimport::out_of($c);
    strict->import::into($c);
    utf8->import::into($c);
    warnings->import::into($c);
} ## tidy end: sub import

1;
