foreach (@ARGV) {

   push @files, glob;

}


foreach $file (@files) {

  open IN , $file;
  $outfile = $file;
  $outfile =~ s/\./\-colons./;

  open OUT , ">$outfile";

  while (defined($line = <IN>)) {

     chomp ($line);

     @array = split (/\t/ , $line);
     foreach (@array) {

        s/\s$//;
        
        ( substr($_, -3, 0) = ":" , next) if ( /^\d+[ap]$/) ;
        ( substr($_, -4, 0) = ":" , next) if ( /^\d+[ap]\*$/) ;

     }

     $line = join("\t" , @array);

     print OUT $line , "\n";

  }

}
