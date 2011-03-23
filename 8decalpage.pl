#!/usr/bin/perl

foreach (glob ("*.eps") , glob ("*.EPS")) {

   @ary = `strings \'$_\'`;
   @ary2 = grep (/%%Page:/ , @ary );

   $string = $ary2[0];

   next unless $string;

   chomp($string);

   $string =~ m/Page: \s+ (?:Sec\d+:)? (\w+) /msx;

   $string = $1;

   $basefile = $string;

   $string .= ".EPS";

   next if $string eq $_;

   $copycount = 1;
   while (-e $string) {
	$copycount++;
        $string = "$basefile#$copycount.EPS";
   }

   print "mv $_ $string \n";
   system "mv" , $_ , $string;
}

