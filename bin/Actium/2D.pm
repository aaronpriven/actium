#!/usr/bin/perl

package Actium::2D;

use warnings;
use strict;

## add the current program directory to list of files to include
use FindBin('$Bin');
use lib $Bin , "$Bin/..";

use Storable;
use Scalar::Util;
use Class::Std;
use Data::Alias;
use List::Moreutils;
use Carp;

use Actium::Constants;

# implements a 2D array structure.
# $rows_of{$ident}[$row][$column] is a typical list of lists
# $columns_of{$ident}[$column][$row] is aliased to 
#    $rows_of{$ident}[$row][$column]

my %rows_of        : ATTR;
my %columns_of     : ATTR;

## CODEREFS pointed to by lexical scalars ##
## not methods, so don't want to invoke them that way.
## They operate on list of lists, not 2D objects

my $build_transposed_list_r = sub {

   my $lol_r = shift;
   my $transposed_r = []; # empty list ref

   for my $i ( 0 .. $#{$lol_r} ) {
      for my $j ( 0 .. $#{ $lol_r->[0] } ) {
         alias $transposed_r->[$j][$i] = $lol_r->[$i][$j];
      }
   }
   
   return $transposed_r;

};

my $pad_out_lol_r = sub {

   my $lol_r = shift;
   my $last = 0;
   foreach my $ary_r (@{$lol_r}) {
      my $end = $#{$ary_r};
      $last = $end if $end > $last;
   }
   
   foreach my $ary_r (@{$lol_r}) {
      for my $j (0 .. $last) {
         $ary_r->[$j] = $EMPTY_STR if not defined $ary_r->[$j];
      }
   }

   return $lol_r;

};


### METHODS 


sub BUILD {
   my ($self, $ident, $arg_r) = @_;

   my $lol_r = $arg_r->{LISTOFLISTS};

   # if there is no list of lists, make an empty object and return
   if ( (ref($lol_r) ne 'ARRAY') or not scalar @{$lol_r}) {
      $rows_of{$ident} = [[]]; # reference to reference to empty array
      $columns_of{$ident} = [[]]; # reference to reference to empty array
      return $self;
   }

   # otherwise set array to LOL value
   $self->set_lol($arg_r);

   return $self;

}

sub set_lol {

   my $lol_r = $arg_r->{LISTOFLISTS};
   $lol_r = dclone($lol_r);
   $pad_out_lol_r->($lol_r);
   my $transposed_r = $build_transposed_list_r->($lol_r);
   
   ($lol_r, $transposed_r) = ($transposed_r , $lol_r)
      if $arg_r->{BYCOLUMNS};

   $rows_of{$ident} = $lol_r;
   $columns_of{$ident} = $transposed_r;

}

sub get_lol {
   my $ident = ident(+shift);
   my $lol_r = dclone($rows_of{$ident});
   return $lol_r;
}

sub get_lol_bycolumns {
   my $ident = ident(+shift);
   my $lol_r = dclone($columns_of{$ident});
   return $lol_r;
}

sub get_num_rows {
   my $self = shift;
   return scalar @{$rows_of{ident($self)}};
}

sub get_num_columns {
   my $self = shift;
   return scalar @{$columns_of{ident($self)}};
}

sub set_element {
   my $self = shift;
   my %args = %{+shift};
   my $ident = ident $self;
   
   # uses names: ROW, COL, VALUE instead of positional args
   # because positions are errorprone
   
   $rows_of{$ident}[$args{ROW}][$args{COL}] = $args{VALUE};
   
}

sub get_element {
   my $self = shift;
   my %args = %{+shift};
   my $ident = ident $self;
   
   # uses names: ROW, COL, VALUE instead of positional args
   # because positions are errorprone
   
   $rows_of{$ident}[$args{ROW}][$args{COL}] = $args{VALUE};
   
}

sub transpose {
   my $ident = ident(+shift);
   ($rows_of{$ident} , $columns_of{$ident}) =
      ($columns_of{$ident} , $rows_of{$ident} )
   return;
}

sub get_row {
   my $ident = ident(+shift);
   my $idx = shift;
   return @{$rows_of{$ident}{$idx}};
}

sub get_column {
   my $ident = ident(+shift);
   my $idx = shift;
   return @{$columns_of{$ident}{$idx}};
}

sub set_row {
   my $ident = ident(+shift);
   my $idx = shift;
   # remaining members of @_ are the new $rows_of;
   @{$rows_of{$ident}{$idx}} = @_;
   return;
}

sub set_column {
   my $ident = ident(+shift);
   my $idx = shift;
   # remaining members of @_ are the new $rows_of;
   @{$columns_of{$ident}{$idx}} = @_;
   return;
}

sub first_nonblank_column {

   my $ident = ident(+shift);
   my $first_nonblank_column = undef;

   COLUMN:
   foreach my $column_idx (0 .. $#{$columns_of{$ident}}) {
      my $hasblank =  
         any {$_ eq $EMPTY_STR}  @{$columns_of{$ident}[$column_idx]};
      if (not $hasblank) {
         $first_nonblank_column = $column_idx;
         last COLUMN;
      }
   }
   
   croak 'No nonblank column in when looking for first nonblank'
      if not defined $first_nonblank_column;

   return $first_nonblank_column;

}

sub sort_rows_bynum {

   my $self = shift;
   my $ident = ident($self);
   
   my $first_nonblank_column = $self->first_nonblank_column;
   
   @{$rows_of{$ident}} = 
      sort {$a->[$first_nonblank_column] <=> $b->[$first_nonblank_column]}
      @{$rows_of{$ident}};
      
   $columns_of{$ident} = $build_transposed_list_r->($rows_of{$ident});

}



1;
