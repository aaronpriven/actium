#!/usr/bin/perl

foreach (glob ("*.eps") , glob ("*.EPS")) {

   @ary = `strings \'$_\'`;
   @ary2 = grep (/\(Code:/ , @ary );

   $string = $ary2[0];

   next unless $string;

   chomp($string);

   $string =~ s/.*\(06B-//;
   $string =~ s/\) .*//;

   $string .= ".EPS";

   next if $string eq $_;

   print "mv $_ $string \n";
   system "mv" , $_ , $string;
}

