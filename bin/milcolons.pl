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
        if ( /^\d+[ap]$/) {

           $ampm = chop;

           $min = substr ($_, -2, 2, "");

           $_ += 12 if $ampm eq "p" and $_ != 12;
           $_ = 0 if $ampm eq "a" and $_ == 12;

           $_ = "$_:$min";

        }
        
     }

     $line = join("\t" , @array);

     print OUT $line , "\n";

  }

}
