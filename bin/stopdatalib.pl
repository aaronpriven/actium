#!perl

=pod

stopdatalib.pl
Routines for dealing with stop data

stopdata is in the hash %stopdata. Format is:

%stopdata{$stopid}[0..x]{LINE} = the line
                        {DAY_DIR} = the day and direction
                        {TPNUM} = the number of the appropriate timepoint
                        {ROUTES}[0..x] = each route used here

=cut

use constant NL => "\n";
use constant TAB => "\t";

use strict;


sub readstopdata ($) {

   my $filename = shift;
   my ($stopid, @pickedtps, %stopdata, @items, $count);

   open STOPDATA, $filename or die "Can't open stop data file for reading";

   local ($/) = "\n---\n";

   while (<STOPDATA>) {

      chomp;
      ($stopid, @pickedtps) = split (/\n/);


      $count = 0;
      foreach (@pickedtps) {
         
         @items = split (/\t/);
         $stopdata{$stopid}[$count]{"LINE"} = shift @items;
         $stopdata{$stopid}[$count]{"DAY_DIR"} = shift @items;
         $stopdata{$stopid}[$count]{"TPNUM"} = shift @items;
         $stopdata{$stopid}[$count]{"ROUTES"} = [ @items ];

         $count++;
      }

   }

   close STOPDATA;

   return %stopdata;

}

sub writestopdata ($\%) {

   my $filename = shift;
   my %stopdata = %{ + shift };

   # the plus makes sure it's not read as %shift

   unless (rename $filename , "$filename.bak") {
      $filename = 'TEMPFILE.$$$';
      warn qq(Can't rename old stop data file; saving as "$filename");
   }
 
   open STOPDATA , ">$filename" or die "Can't open stop data file for writing";

   while (my $stopid = each %stopdata) {

      print $stopid , NL;

      foreach (@{$stopdata{$stopid}}) {

         print STOPDATA $_->{"LINE"} , TAB;
         print STOPDATA $_->{"DAY_DIR"} , TAB;
         print STOPDATA $_->{"TPNUM"} , TAB;
         print STOPDATA join ( TAB , @{$_->{"ROUTES"}}) , NL;
 
      }

      print "---\n";

   }

   close STOPDATA;

}

1;
