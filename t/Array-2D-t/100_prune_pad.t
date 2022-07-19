use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

plan tests => 65;

# Prune_* is tested before the readers because rows() and cols() depend on
# prune()

# similarly, prune_callback is tested before the other prunes because
# those use prune_callback to do their work

my $prune_test = [ [ 1, 2 ], [3], [ 4, 5, 6 ] ];

a2dcan('prune_callback');

my $obj_to_prunecallback = Array::2D->new(
    [ 1, 2, ' ', '' ],
    [ 3, undef, 'z' ],
    [ 4, 5,     6 ],
    [], ["\n"]
);

my $ref_to_prunecallback
  = [ [ 1, 2, ' ', '' ], [ 3, undef, 'z' ], [ 4, 5, 6 ], [], ["\n"] ];

my $prunecallback_unchanged
  = [ [ 1, 2, ' ', '' ], [ 3, undef, 'z' ], [ 4, 5, 6 ], [], ["\n"] ];

my $callback = sub { not defined $_ or $_ =~ /\A\s*\z/ or $_ eq 'z' };

my $prunecallback_obj_results
  = $obj_to_prunecallback->prune_callback($callback);
is_deeply( $prunecallback_obj_results, $prune_test,
    'Got prune-callbackd from object' );
is_blessed($prunecallback_obj_results);
is_deeply( $obj_to_prunecallback, $prunecallback_unchanged,
    '... and the object is not changed' );

my $prunecallback_ref_results
  = Array::2D->prune_callback( $ref_to_prunecallback, $callback );
is_deeply( $prunecallback_ref_results, $prune_test,
    'Got prune-callbackd from reference' );
is_blessed($prunecallback_ref_results);
is_deeply( $ref_to_prunecallback, $prunecallback_unchanged,
    '... and the reference is not changed' );

$obj_to_prunecallback->prune_callback($callback);
is_deeply( $obj_to_prunecallback, $prune_test,
    'Prune-callbackd object in place' );
is_blessed($obj_to_prunecallback);

Array::2D->prune_callback( $ref_to_prunecallback, $callback );
is_deeply( $ref_to_prunecallback, $prune_test,
    'Prune-callbackd reference in place' );
isnt_blessed($ref_to_prunecallback);

a2dcan('prune');

my $obj_to_prune
  = Array::2D->new( [ 1, 2, undef ], [ 3, undef ], [ 4, 5, 6 ], [] );

my $ref_to_prune = [ [ 1, 2, undef ], [ 3, undef ], [ 4, 5, 6 ], [] ];

my $prune_unchanged = [ [ 1, 2, undef ], [ 3, undef ], [ 4, 5, 6 ], [] ];

my $prune_obj_results = $obj_to_prune->prune();
is_deeply( $prune_obj_results, $prune_test, 'Got pruned from object' );
is_blessed($prune_obj_results);
is_deeply( $obj_to_prune, $prune_unchanged,
    '... and the object is not changed' );

my $prune_ref_results = Array::2D->prune($ref_to_prune);
is_deeply( $prune_ref_results, $prune_test, 'Got pruned from reference' );
is_blessed($prune_ref_results);
is_deeply( $ref_to_prune, $prune_unchanged,
    '... and the reference is not changed' );

$obj_to_prune->prune();
is_deeply( $obj_to_prune, $prune_test, 'Pruned object in place' );
is_blessed($obj_to_prune);

Array::2D->prune($ref_to_prune);
is_deeply( $ref_to_prune, $prune_test, 'Pruned reference in place' );
isnt_blessed($ref_to_prune);

a2dcan('prune_empty');

my $obj_to_pruneempty
  = Array::2D->new( [ 1, 2, '' ], [ 3, undef ], [ 4, 5, 6 ], [], [''] );

my $ref_to_pruneempty
  = [ [ 1, 2, '' ], [ 3, undef ], [ 4, 5, 6 ], [], [''] ];

my $pruneempty_unchanged
  = [ [ 1, 2, '' ], [ 3, undef ], [ 4, 5, 6 ], [], [''] ];

my $pruneempty_obj_results = $obj_to_pruneempty->prune_empty();
is_deeply( $pruneempty_obj_results, $prune_test,
    'Got prune-emptied from object' );
is_blessed($pruneempty_obj_results);
is_deeply( $obj_to_pruneempty, $pruneempty_unchanged,
    '... and the object is not changed' );

my $pruneempty_ref_results = Array::2D->prune_empty($ref_to_pruneempty);
is_deeply( $pruneempty_ref_results, $prune_test,
    'Got prune-emptied from reference' );
is_blessed($pruneempty_ref_results);
is_deeply( $ref_to_pruneempty, $pruneempty_unchanged,
    '... and the reference is not changed' );

$obj_to_pruneempty->prune_empty();
is_deeply( $obj_to_pruneempty, $prune_test, 'Prune-emptied object in place' );
is_blessed($obj_to_pruneempty);

Array::2D->prune_empty($ref_to_pruneempty);
is_deeply( $ref_to_pruneempty, $prune_test,
    'Prune-emptied reference in place' );
isnt_blessed($ref_to_pruneempty);

a2dcan('prune_space');

my $obj_to_prunespace
  = Array::2D->new( [ 1, 2, ' ', '' ], [ 3, undef ], [ 4, 5, 6 ], [], ["\n"] );

my $ref_to_prunespace
  = [ [ 1, 2, ' ', '' ], [ 3, undef ], [ 4, 5, 6 ], [], ["\n"] ];

my $prunespace_unchanged
  = [ [ 1, 2, ' ', '' ], [ 3, undef ], [ 4, 5, 6 ], [], ["\n"] ];

my $prunespace_obj_results = $obj_to_prunespace->prune_space();
is_deeply( $prunespace_obj_results, $prune_test,
    'Got prune-spaced from object' );
is_blessed($prunespace_obj_results);
is_deeply( $obj_to_prunespace, $prunespace_unchanged,
    '... and the object is not changed' );

my $prunespace_ref_results = Array::2D->prune_space($ref_to_prunespace);
is_deeply( $prunespace_ref_results, $prune_test,
    'Got prune-spaced from reference' );
is_blessed($prunespace_ref_results);
is_deeply( $ref_to_prunespace, $prunespace_unchanged,
    '... and the reference is not changed' );

$obj_to_prunespace->prune_space();
is_deeply( $obj_to_prunespace, $prune_test, 'Prune-spaced object in place' );
is_blessed($obj_to_prunespace);

Array::2D->prune_space($ref_to_prunespace);
is_deeply( $ref_to_prunespace, $prune_test, 'Prune-spaced reference in place' );
isnt_blessed($ref_to_prunespace);

a2dcan('pad');

my $obj_to_pad_undef = Array::2D->new( [ [ 1, 2 ], [3], [ 4, 5, 6 ] ] );
my $ref_to_pad_space = [ [ 1, 2 ], [3], [ 4, 5, 6 ] ];
my $pad_unchanged    = [ [ 1, 2 ], [3], [ 4, 5, 6 ] ];
my $obj_to_pad_space = Array::2D->new( [ [ 1, 2 ], [3], [ 4, 5, 6 ] ] );
my $ref_to_pad_undef = [ [ 1, 2 ], [3], [ 4, 5, 6 ] ];
my $pad_test_space = [ [ 1, 2, ' ' ],   [ 3, ' ',   ' ' ],   [ 4, 5, 6 ] ];
my $pad_test_undef = [ [ 1, 2, undef ], [ 3, undef, undef ], [ 4, 5, 6 ] ];

my $pad_obj_undef_results = $obj_to_pad_undef->pad();
is_deeply( $pad_obj_undef_results, $pad_test_undef,
    'Got padded with undef from object' );
is_blessed($pad_obj_undef_results);
is_deeply( $obj_to_pad_undef, $pad_unchanged,
    '... and the object is not changed' );

my $pad_ref_undef_results = Array::2D->pad($ref_to_pad_undef);
is_deeply( $pad_ref_undef_results, $pad_test_undef,
    'Got padded with undef from reference' );
is_blessed($pad_ref_undef_results);
is_deeply( $ref_to_pad_undef, $pad_unchanged,
    '... and the reference is not changed' );

$obj_to_pad_undef->pad();
is_deeply( $obj_to_pad_undef, $pad_test_undef,
    'Padded with undef object in place' );
is_blessed($obj_to_pad_undef);

Array::2D->pad($ref_to_pad_undef);
is_deeply( $ref_to_pad_undef, $pad_test_undef,
    'Padded with undef reference in place' );
isnt_blessed($ref_to_pad_undef);

my $pad_obj_space_results = $obj_to_pad_space->pad(' ');
is_deeply( $pad_obj_space_results, $pad_test_space,
    'Got padded with space from object' );
is_blessed($pad_obj_space_results);
is_deeply( $obj_to_pad_space, $pad_unchanged,
    '... and the object is not changed' );

my $pad_ref_space_results = Array::2D->pad( $ref_to_pad_space, ' ' );
is_deeply( $pad_ref_space_results, $pad_test_space,
    'Got padded with space from reference' );
is_blessed($pad_ref_space_results);
is_deeply( $ref_to_pad_space, $pad_unchanged,
    '... and the reference is not changed' );

$obj_to_pad_space->pad(' ');
is_deeply( $obj_to_pad_space, $pad_test_space,
    'Padded with space object in place' );
is_blessed($obj_to_pad_space);
Array::2D->pad( $ref_to_pad_space, ' ' );
is_deeply( $ref_to_pad_space, $pad_test_space,
    'Padded with space reference in place' );
isnt_blessed($ref_to_pad_space);
