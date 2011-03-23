#!/usr/bin/perl 

push @files, glob ($_) foreach @ARGV;

foreach my $file (@files) {

   $line = $file;
   $line =~ s/_.*//;

   rename $file , "$file.bak";
   open IN , "$file.bak"; 
   open OUT , ">$file";

   print OUT $line, "_" , scalar (<IN>);

   # print OUT "Note Definitions:\n" ;
   
   $_ = <IN>;
   chomp;
   @tps = split (/\t/);

   %seen = ();
   foreach (@tps) {
      $_ .= "=" . $seen{$_} if $seen{$_}++;
   }

   print OUT join("\t" , @tps) , "\n";

   {
   local ($/) = undef;
   print OUT scalar(<IN>);

   }
}
