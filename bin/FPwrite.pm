__END__

I haven't made FPWrite work with the current data structure. It uses the 
now-obsolete $data{$field}[0..n] structure. It could be fixed.

sub FPwrite ($$) {

# call FPwrite as FPMerge::FPwrite($filename, \%data)

   my $file = shift;
   my %data = %{shift()};
   # perl thinks %{shift} is the variable %shift.
   # vim thinks %{shift} is a function call. Interesting.

   my $csv = MyCSV->new;

   my @fields = keys %data;

   # the only real reason to do this is to ensure that the order is
   # always the same. At some point I may write this so it specifies an
   # order.
   
   open CSVFILE, ">$file" or die "Can't open $file for writing";

   print CSVFILE join("," , @fields)  , "\n";

   # This uses the system default newline. I hope, anyway, that FileMaker
   # will recognize it.

   my $max = 0;

   foreach (@fields) {
      my $thislength = @{$data{$_}};
      next if $thislength >= $max;
      $max = $thislength;
   }

   my @values;
   foreach my $count (0 .. $max) { # the big .. array is optimized away, yay
      @values = ();
      foreach my $field (@fields) {
          my $value = $data{$field}[$count];
          if (ref ($value)) {
             $value = join("\013" , @$value);
          }
          push @values, $value;
      }

      $csv->combine(@values) 
        or die "Combine failed with values: ", $csv->error_input;

      print CSVFILE $csv->string();

   }

close CSVFILE;
   
}

1;
