sub read_index {

open INDEX , "<acsched.ndx" or die "Can't open index file.\n";

   local ($/) = "---\n";

   my @day_dirs;
   my @thisdir;
   my $day_dir;
   my @timepoints;
   my $line;
   my $tp;

   while (<INDEX>) {

      chomp;
      @day_dirs = split("\n");
      $line = shift @day_dirs;
  
      foreach (@day_dirs) {
         # this $_ is local to the loop

         @thisdir = split("\t");
         $day_dir = shift @thisdir;
         @{$index{$line}{$day_dir}{"ROUTES"}} = split(/_/, shift @thisdir);

         foreach (@thisdir) {
            # another local $_

            @timepoints = split(/_/);

            $tp = tpxref($timepoints[0], 1);
            # cross-referencing - 1 means always do it

            push @{$index{$line}{$day_dir}{"TP"}} , $tp;
            push @{$index{$line}{$day_dir}{"TIMEPOINTS"}} , $timepoints[1];
         }

      }

   }
   return %index;

}
