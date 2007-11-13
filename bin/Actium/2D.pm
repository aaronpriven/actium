old 2d routines

my $build_column_refs_r = sub {

   $ident = shift;

   $columns_of{$ident} = [];

   my $ident = shift;
   for my $i ( 0 .. $#{$rows_of{$ident}} ) {
      for my $j ( 0 .. $#{$rows_of{$ident}[0]} ) {
         $columns_of{$ident}[$j][$i] = $rows_of{$ident}[$i][$j];
      }
   }
};

my $build_row_refs_r = sub {

   $rows_of{$ident} = [];

   my $ident = shift;
   for my $i ( 0 .. $#{$columns_of{$ident}} ) {
      for my $j ( 0 .. $#{$columns_of{$ident}[0]} ) {
         $rows_of{$ident}[$j][$i] = $columns_of{$ident}[$i][$j];
      }
   }
};



my $transpose_and_copy_lol_r = sub {
# Makes a copy of an LOL in a new form, transposed 
# (rows to columns and vice versa)
# assumes that LOL is padded out to last entries

    my $lol_r = shift;

    # number of rows in the first column
    # Won't work if a subsequent column has more rows than first column
    my $numrows = scalar (@{$lol_r->[0]});

    # empty arrayref times the number of rows 
    my @newlol = ( ([]) x $numrows );
    
    for my $i ( 0 .. $#{$lol_r} ) {
        for my $j (0 ..  $numrows - 1) {
           $newlol[$j][$i] = $lol_r->[$i][$j];
        }
    }

    return \@newlol;

};

