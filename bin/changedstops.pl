#!perl

# changedstops.pl

#use Win32::GUI;
#use Win32;

use strict;
no strict 'subs';

require 'pubinflib.pl';

use constant ProgramTitle => "AC Transit Stop Signage Database - Changed Stops";

my (@found,@refs, @keys, @routes, %routes, %stopdata , $found);

our (%stops);

chdir get_directory() or die "Can't change to specified directory.\n";

open OUT, ">changedstops.txt" or die "Can't open outfile";

select OUT;

shift @ARGV;

init_vars();

my $stopsfile = ("stops.txt");

@refs = readstops ($stopsfile);
@keys = @{shift @refs};
%stops = %{shift @refs};

my $stopdatafile = ("stopdata.txt");

open CHANGED, 'changedroutes.txt' or die "can't open changed routes file";

my @changedroutes = <CHANGED>;

chomp @changedroutes;

close CHANGED;

select OUT;

print "Changed routes:\n";
print join ("," , @changedroutes) , "\n\n";


# my $stopdatafile = ( $ARGV[2] or "stopdata.txt");
%stopdata = readstopdata ($stopdatafile);

foreach my $stopid (sort keys %stopdata) {

   @routes = ();
   %routes = ();
   $found = 0;
 
   foreach (@{$stopdata{$stopid}}) {
      push @routes , @{$_->{ROUTES}};
   }

   #print join ("," , @routes) , "\t";
 
   # now all routes are in @routes

   foreach (@routes) {
      $routes{$_}=1;
   }

   # now all routes are in keys %routes, removing duplicates

   ROUTE:
   foreach (@changedroutes) {
      if ($routes{$_}) {
         $found = 1;
         last;
      }
   }

   #print $found , "\n";
    
   next unless $found;

   push @found, $stopid;

}

#print join ("," , @found) , "\n";


@found = sort {$a <=> $b} @found;

#print join ("," , @found) , "\n";


foreach (@found) {
   print stopdescription($_, $stops{$_}, 
                   1 ) , "\n" if $stopdata{$_} ;
}
