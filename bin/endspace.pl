foreach (@ARGV) {

   push @files, glob;

}


foreach $file (@files) {

  open IN , $file;
  $outfile = $file;
  $outfile =~ s/\./-ns./;

  open OUT , ">$outfile";

  while (defined($line = <IN>)) {

     chomp ($line);

     $line =~ s/\s+$//;

     print OUT $line , "\n";

  }

}
