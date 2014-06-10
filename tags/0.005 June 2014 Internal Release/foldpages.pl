#!/ActivePerl/bin/perl

use 5.012;
use warnings;

{
    no warnings('once');
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
    }
}
   
$/ = "\cL\cM";

my @pages;

while (<>) {
#   chomp;
   s/\r\n?/\n/g;
   my @lines = split(/\n/) ;
   
   shift @lines while $lines[0] =~ /\A \s* \z/sx;
   
   push @pages , \@lines;
   $pages[-1][-1] = "\cL\r\n";

}

my $count = 0;

until ($count >= $#pages ) { 

   $count++;
   
   next if ( $pages[$count-1][7] =~ /DIV-IN  STOP$/ );
   next if ( $pages[$count-1][7] =~ /^Notes:/ );
   
   # If the previous page has the proper final characters, it's good. 
   # Otherwise, add the current page to the previous page, and delete 
   # the current page.
   
   
   for (7..35) { # data lines only
      if ($pages[$count-1][$_] ) {
         $pages[$count-1][$_] .= " " . $pages[$count][$_];
      }
      else {
         $pages[$count-1][$_] = $pages[$count][$_];
      }

   } 
   
   splice (@pages, $count, 1);

}

for (@pages) {
   print ( join "\r\n" , @{$_} ) ;
}
