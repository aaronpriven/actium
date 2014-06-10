#!/usr/bin/perl

# So this is designed to grep through an ASCII EPS file, find the text
# that follows "Code:" , and rename the file to that code.
#
# It was intended to rename EPS files imported from InDesign, which are
# normally saved with the page number, but I wanted them given the 
# filename of the line number or, alternatively, some code that contains
# the line number.

# This would probably be better done as a script, telling InDesign to save 
# each page with the code from that page.

foreach (glob ("*.eps") , glob ("*.EPS")) {

   @ary = `strings \'$_\'`;
   @ary2 = grep (/\(code->/ , @ary );

   $string = $ary2[0];

   next unless $string;

   chomp($string);

   $string =~ s/.*\(code->//;
   $string =~ s/\).*//;

   $string .= ".EPS";

   next if $string eq $_;

   print "mv $_ $string \n";
   system "mv" , $_ , $string;
}

