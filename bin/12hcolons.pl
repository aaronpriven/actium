foreach (@ARGV) {

   push @files, glob;

}


foreach $file (@files) {

  open IN , $file;

  $file =~ s/\..*//;

  open OUT , ">$file.txt";

  while (defined($line = <IN>)) {

     chomp ($line);

     @array = split (/\t/ , $line);
     foreach (@array) {

        s/\s+$//;
        if ( /^[\d:]+(\*)?$/) {

           if (/\*$/) {
              $star = substr ($_, -1, 1, "");
           } else {
              $star = ""
           }

           $min = substr ($_, -2, 2, "");

           s/://;


           $ampm = "a";

           if ($_ == 12) {
              $ampm = "p";

           } elsif ($_ > 12) {;

              $ampm = "p";
              $_ -= 12;

           } elsif ($_ == 0) {

              $_ = "12";

           } # otherwise it's between 1 and 11 inclusive so leave it alone
              
           $_ = "$_:$min" . $ampm . $star;

        }
        
     }

     $line = join("\t" , @array);

     print OUT $line , "\n";

  }

}
