foreach (@ARGV) {

   push @files, glob;

}


foreach $file (@files) {

  open IN , $file;
  $outfile = $file;
  $outfile =~ s/\-colons/-bold/;

  open OUT , ">$outfile";

  while (defined($line = <IN>)) {

     chomp ($line);

     @array = split (/\t/ , $line);
     foreach (@array) {

        s/\s$//;

        next unless /^\d\d?:\d\d[ap]$/;
        
        $ampm = chop;

        $_ = "<B>$_<B>" if $ampm eq "p";

     }

     $line = join("\t" , @array);

     print OUT $line , "\n";

  }

}
