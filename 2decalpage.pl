#!/usr/bin/perl

foreach (glob ("*.eps") , glob ("*.EPS")) {

   @ary = `strings \'$_\'`;
   @ary2 = grep (/\(2D-/ , @ary );

   $string = $ary2[0];

   next unless $string;

   chomp($string);

   $string =~ s/.*\(2D-//;
   $string =~ s/\) .*//;

   $basefile = $string;

   $string .= ".EPS";

   next if $string eq $_;

   $copycount = 1;
   while (-e $string) {
	$copycount++;
        $string = "$basefile-$copycount.EPS";
   }

   print "mv $_ $string \n";
   system "mv" , $_ , $string;
}

