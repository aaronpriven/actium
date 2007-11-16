#!/usr/bin/perl

package Actium::2D;

# routines for 2-dimensional arrays

use warnings;
use strict;

## add the current program directory to list of files to include
use FindBin('$Bin');
use lib $Bin , "$Bin/..";

use List::Util (qw(min max));
use Carp;
use Storable ('dclone');

use Actium::Constants;

use Data::Alias;

use Exporter;
our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
@ISA = ('Exporter');
@EXPORT_OK = 
    qw(get_row       shift_row     pop_row    splice_row   insert_row   delete_row
       get_rows                           splice_rows  insert_rows  delete_rows
       set_row       unshift_row   push_row     
       set_rows      unshift_rows  push_rows
       pad_rows      blank_rows    trim_rows  trim_columns
       last_row_idx  clone         transposed clone_transposed
       );
%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );      

# UTILITY

sub last_row_idx {
   # last_row_idx (\@aoa)
   return max (       # maximum value of
       map { $#{$_} } # the index of the last members of 
           @{$_[0]} );  # all the arrays
                      # pointed to by the first entry in @_
}

sub transposed {
   my $aoa_r = shift;
   my $last_col = $#{$aoa_r};
   my $last_row_idx = last_row_idx($aoa_r);
   
   my $transposed_r;
   for (0 .. $last_row_idx) {
      $#{$transposed_r->[$_]} = $last_col;
   }

   for my $i ( 0 .. $#{$aoa_r} ) {
      for my $j ( 0 .. $last_row_idx ) {
         alias $transposed_r->[$j][$i] = $aoa_r->[$i][$j];
      }
   }

   return $transposed_r;
   # ref to new AoA in $_[0]
}

sub trim_array { pop @_ while not defined $_[$#_] }

sub get_row {
   my $aoa = shift;
   my $index = shift;
   my $xaoa = transposed($aoa);
   return trim_array(@{$xaoa->[$index]});
}   

__END__

sub splice_row {
   my $aoa_r  = shift;
   my $offset = shift;
   my $length = shift;
   my @values = @_;
   my $new_aoa_r = [ \@values ]; # so $new_aoa_r->[0] is ref to @values
   my $return_r = splice_rows ($aoa_r, $offset, $length, $new_aoa_r);
   if (scalar @{$return_r} == 1) { # only one 
      return @{$return_r->[0]}; # return the list
   }
   return $return_r;
   
}

sub splice_rows {
   my $aoa_r              = shift;
   my $offset             = shift;
   my $length             = shift;
   my $replacement_aoa_r  = shift;

   # If both OFFSET and LENGTH are omitted, removes everything.
   # Pretty pointless if you ask me.

   if (not defined $offset and not defined $length) {
      @{$replacement_aoa_r} = @{$aoa_r};
      @{$aoa_r} = [];
      return $replacement_aoa_r;
   }
   
   if (not defined $replacement_aoa_r) {
      return get_rows ($aoa_r , $offset, $length);
   }
   
   $replacement_aoa_r  = clone($replacement_aoa_r);

   my $last_row_idx = last_row_idx ($aoa_r);

   _adjust_offset ($offset, $last_row_idx);
   _adjust_length ($offset, $length, $last_row_idx);
   
   pad_rows($aoa_r);
   pad_rows($replacement_aoa_r);
   # TODO - only pad if necessary

   my @returned_aoa = ();
   for my $column (0 .. (max $#{$replacement_aoa_r} , $#{$aoa_r}) ) {
      push @returned_aoa ,
         \( splice @{$aoa_r->[$column]} , $offset 
           , $length, @{$replacement_aoa_r->[$column]} );
   }

   return \@returned_aoa;

}


sub get_row { # tested
   # get_row (\@aoa, offset)
   my $aoa_r = shift;
   my $offset = shift;
   return map { $_->[$offset] } @{$aoa_r};
   # always returns row
}

sub get_rows {
   # get_rows (\@aoa, offset, length)
   # does what splice does with no replacement values
   my $aoa_r = shift;
   my $offset = shift;
   my $length = shift;
   
   my $last_row_idx = last_row_idx($aoa_r);
   _adjust_offset($offset,$last_row_idx);
   _adjust_length($offset,$length,$last_row_idx);

   my $return_r;
   for my $row ($offset .. $offset + $length - 1) {
      push @{$return_r} , [ get_row($aoa_r , $row) ] ;
   }
   transpose($return_r);
   return $return_r;
}   
   
# shift, pop, unshift, push

sub shift_row {
   # shift_row(\@lol)
   return splice_row($_[0] , 0, 1);
}

sub pop_row {
   return splice_row($_[0] , -1);
}



# PUT VALUES IN ROW: SET, UNSHIFT, PUSH
   
sub set_row { # tested

   # set_row (\@lol , index, @newrow)
   my $aoa_r = shift;
   my $row = shift;
   
   my @newrow = @_;
   
   my @oldrow;
   @oldrow = get_row($aoa_r, $row) if defined wantarray;
   
   for my $column (0 .. (max $#newrow , $#{$aoa_r}) ) {
      $aoa_r->[$column][$row] = shift @newrow;
   }
   
   trim_columns($aoa_r);
   
   return @oldrow if defined wantarray;
   return;
   # returns old row in list context, or num of elements in old row
   # in scalar context

}

sub set_rows {
   # set_rows (\@lol, startingrow , \@values)
   my ($aoa_r, $startingrow, $new_aoa_r) = @_;
   my $return_r;
   for my $row (0 .. $#{$new_aoa_r}) {
      if (defined wantarray) {
         push @{$return_r} , 
            [set_row ($aoa_r, $row + $startingrow, @{$new_aoa_r->[$row] } ) ];
      }
      else {
         set_row ($aoa_r, $row + $startingrow, @{$new_aoa_r->[$row] } );
      }
   }
   if (defined wantarray) {
      transpose($return_r);
      return $return_r;
   }
   return;
}   

#sub unshift_rows {
#   # unshift_row (\@lol, \@values...)
#   my $aoa_r = shift;
#   my $new_aoa_r = clone(shift);
#   
#   my $last_new_row = last_row_idx($new_aoa_r);
#   
#   for my $column (0 .. (max $#{$new_aoa_r} , $#{$aoa_r}) ) {
#      $new_aoa_r->[$column][$last_new_row] = undef
#          unless defined ($new_aoa_r->[$column][$last_new_row]); 
#          # pad out $new_aoa_r     
#      unshift @{ $aoa_r->[$column] }, @{ $new_aoa_r->[$column] };
#   }
#   
#   return last_row_idx($aoa_r)+1 if defined wantarray;
#   # returns number of rows
#   return;
#
#}

sub unshift_row {
  # unshift_row (\@lol, @values);
  my ($aoa_r, @values) = @_;
  my $new_aoa_r = [ \@values ]; # so $new_aoa_r->[0] is ref to @values
  return unshift_rows ($aoa_r, $new_aoa_r)
}

sub unshift_rows {
   # unshift_rows (\@lol, \@values...)
   my $aoa_r = shift;
   my $new_aoa_r = clone(shift);
   
   pad_rows($new_aoa_r);
   
   for my $column (0 .. (max $#{$new_aoa_r} , $#{$aoa_r}) ) {
      unshift @{ $aoa_r->[$column] }, @{ $new_aoa_r->[$column] };
   }
   
   return last_row_idx($aoa_r)+1 if defined wantarray;
   # returns number of rows
   return;

}

sub push_row {
   # push_row (\@lol, @values);
   my ($aoa_r, @values) = @_;
   my $new_aoa_r = [ \@values ]; # so $new_aoa_r->[0] is ref to @values
   return push_rows ($aoa_r, $new_aoa_r);
}

sub push_rows {
   # push_rows (\@lol, \@values);
   my $aoa_r = shift;
   my $new_aoa_r = shift;
 
   my $last_row_idx = last_row_idx ($aoa_r);

   for my $column (0 .. (max $#{$new_aoa_r} , $#{$aoa_r}) ) {
      $aoa_r->[$column][$last_row_idx] = undef
          unless defined ($aoa_r->[$column][$last_row_idx]);
      if (ref $new_aoa_r->[$column]) {
         push @{ $aoa_r->[$column] }, @{ $new_aoa_r->[$column] };
      }
   }
   
   return last_row_idx($aoa_r)+1 if defined wantarray;
   # returns number of rows
   return;

}

# MODIFICATION: pad_rows, trim_columns, transpose


sub pad_rows {
   # pad_rows(\@lol, $value) - if value omitted, will default to undef
   # makes sure all entries exist. (important for push and sometimes splice)

   my $aoa_r = shift;
   my $value = shift; # naturally defaults to undef
   my $last_row_idx = last_row_idx($aoa_r);
   
   foreach my $col_r (@{$aoa_r}) {
      for my $j (0 .. $last_row_idx) {
         $col_r->[$last_row_idx] = $value if not exists $col_r->[$last_row_idx];
      }
   }
   return; # nothing
};

sub blank_rows {
   # blank_rows(\@lol, $value) - if value omitted, will default to undef
   my $aoa_r = shift;
   my $value = shift; # naturally defaults to undef
   my $last_row_idx = last_row_idx($aoa_r);
   
   foreach my $col_r (@{$aoa_r}) {
      for my $j (0 .. $last_row_idx) {
         $col_r->[$last_row_idx] = $value if not defined $col_r->[$last_row_idx];
      }
   }
   return; # nothing
};


sub _any_defined { defined($_) && return 1 for @_; 0 }

sub trim_columns {
   my $aoa_r = shift;

   for my $column ( reverse ( 0 .. $#{$aoa_r} ) ) {
      last if _any_defined @{$aoa_r->[$column]} ;
      pop @{$aoa_r};

   }

   return scalar @{$aoa_r}; # returns num of columns

}

sub trim_rows {
  my $aoa_r = shift;
  COLUMN:
  for my $column_r ( @{$aoa_r} ) {
     for my $row ( reverse (0 .. $#{$column_r}) ) {
        last COLUMN if defined $column_r->[$row];
        delete $column_r->[$row];
     }
  }
  return;
}



# RETURNS CLONE: transpose

sub clone {
   return dclone($_[0]);
   # returns new aoa
}
   
sub clone_transposed {
   my $aoa_r = shift;
   my $last_row_idx = last_row_idx($aoa_r);
   
   my $transposed_r;
   push @{$transposed_r} , [] for 0 .. $last_row_idx;

   for my $i ( 0 .. $#{$aoa_r} ) {
      for my $j ( 0 .. $last_row_idx ) {
         $transposed_r->[$j][$i] = $aoa_r->[$i][$j];
      }
   }
   
   return $transposed_r;
   # returns new lol
}

# SPLICE-TYPE: splice_row, insert_row, delete_row

sub _adjust_offset {
   my $offset = shift;
   my $last_row_idx = shift;
   
   if ($offset > $last_row_idx) {
      carp ("offset ($offset) greater than maximum value ($last_row_idx) in "
         . caller);
      $offset = $last_row_idx;
   } elsif ($offset < 0) {
      $offset = $last_row_idx + $offset + 1
   }
   # If OFFSET is negative then it starts that far from the end of the array.
   # If OFFSET is past the end of the array, perl issues a warning, and 
   # splices at the end of the array.
}

sub _adjust_length {
   my $offset = shift;
   my $length = shift;
   my $last_row_idx = shift;

   if (not defined($length)) {
      $length = $last_row_idx - $offset + 1;
   }
   elsif ($length < 0) {
      $length = ($last_row_idx - $offset + 1) + $length;
   }
   # If LENGTH is omitted, removes everything from OFFSET onward. 
   # If LENGTH is negative, removes the elements from OFFSET onward 
   # except for -LENGTH elements at the end of the array.
}


sub insert_rows {
   return splice_rows ($_[0], $_[1], 0, $_[2]);
}   

sub insert_row {
   splice (@_ , 2, 0, 0); 
      # set third element of @_ to 0 and push following elements of @_ further
   return splice_row (@_);
}   

sub delete_row {
   return delete_rows ($_[0] , $_[1], 1 );
}

sub delete_rows {
   # deletes rows at offset
   # delete_row (\@lol, $offset, $length)
   my $aoa_r = shift;
   my $offset = shift;
   my $length = shift;
   
   my $last_row_idx = last_row_idx($aoa_r);

   _adjust_offset ($offset, $last_row_idx);
   
   _adjust_length ($offset, $length, $last_row_idx);

   my @new_aoa;
   for my $column_r (@{$aoa_r}) {
      push @new_aoa , \(splice (@{$column_r} , $offset, $length));
   }
   
   return \@new_aoa;
   # returns the deleted row

}

sub splice_row3 {
   my $aoa_r  = shift;
   my $offset = shift;
   my $length = shift;
   my @values = @_;
   my $new_aoa_r = [ \@values ]; # so $new_aoa_r->[0] is ref to @values
   return splice_rows ($aoa_r, $offset, $length, $new_aoa_r);
}   

sub splice_rows {
   my $aoa_r              = shift;
   my $offset             = shift;
   my $length             = shift;
   my $replacement_aoa_r  = shift;

   # If both OFFSET and LENGTH are omitted, removes everything.
   # Pretty pointless if you ask me.

   if (not defined $offset and not defined $length) {
      @{$replacement_aoa_r} = @{$aoa_r};
      @{$aoa_r} = [];
      return $replacement_aoa_r;
   }
   
   if (not defined $replacement_aoa_r) {
      return get_rows ($aoa_r , $offset, $length);
   }
   
   $replacement_aoa_r  = clone($replacement_aoa_r);

   my $last_row_idx = last_row_idx ($aoa_r);

   _adjust_offset ($offset, $last_row_idx);
   _adjust_length ($offset, $length, $last_row_idx);
   
   pad_rows($aoa_r);
   pad_rows($replacement_aoa_r);
   # TODO - only pad if necessary

   my @returned_aoa = ();
   for my $column (0 .. (max $#{$replacement_aoa_r} , $#{$aoa_r}) ) {
      push @returned_aoa ,
         \( splice @{$aoa_r->[$column]} , $offset 
           , $length, @{$replacement_aoa_r->[$column]} );
   }

   return \@returned_aoa;

}

1;
