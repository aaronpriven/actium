#!/usr/bin/perl

# slists2polestoporder - see POD documentation below

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ($Bin , "$Bin/../bin");

use Carp;
use Storable();

use Actium( qw[say sayt jn jt initialize avldata ensuredir byroutes option]);
use Actium::Constants;
use List::Util (qw<max>);

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
slists2bagorder makes the order for bags (that is, listing stops by route in order
of traversing that route) from the line.storable file.
EOF

my $intro = 'slists2bagorder -- makes order for bags';

Actium::initialize ($helptext, $intro);

# retrieve data
my %stops_of = %{ Storable::retrieve('slists/line.storable') } or die $!;

# delete bad lines like NC and LC
foreach my $linedir (keys %stops_of) {
   if (    $linedir =~ /^NC/ or $linedir =~ /^LC/ or  
           $linedir =~ /^399/ or $linedir =~ /^51S/ ) {
       delete $stops_of{$linedir};
   }
}

# load the stops that are signs

my ($infile, $outfile) = @ARGV;

die "No input file specified" unless $infile;
die "No output file specified" unless $outfile;

open my $in , '<' , $infile or die "Can't open $infile: $!";
my %stop_used;
while (<$in>) {
   my ($sign, $stop);

   chomp;
   ($sign, $stop) = split (/\t/ , $_ );
   $stop_used{$stop} = $sign;
}
close $in or die $!;

# eliminate all stops that are not signs
while (my ($linedir , $stops_r) = each %stops_of) {
   my @newstops;
   foreach my $stop (@{$stops_r}) {
      push @newstops, $stop if $stop_used{$stop};
   }
   $stops_of{$linedir} = \@newstops;
}

# Now %stops_of contains all stops in every line.

open my $baglist, '>' , $outfile or die $!;

while ( scalar keys %stops_of ) {

   my @list = keys %stops_of;

    my $max_linedir = (sort { 
       ( $a =~ /^6\d\d/ <=> $b =~ /^6\d\d/ ) or
       ( scalar @{$stops_of{$b}} <=> scalar @{$stops_of{$a}} ) or
       byroutes ($a , $b) 
       } keys %stops_of)[0];
   
   my @stops = @{$stops_of{$max_linedir}};
   
   last unless scalar @stops;

   print $baglist  join ("\t" , $max_linedir , @stops) , "\n" ;   
   
   delete $stops_of{$max_linedir};
   
   delete $stop_used{$_} foreach @stops;
   
   # we've printed the one with the most stops.
   # now delete all stops in the subsequent series that have been done so far
   
   my %seen_stop;
   $seen_stop{$_} = 1 foreach @stops;
   
   while (my ($linedir , $stops_r) = each %stops_of) {
      my @newstops;
      foreach my $stop (@{$stops_r}) {
         push @newstops, $stop unless $seen_stop{$stop};
      }
      if (@newstops) {
         $stops_of{$linedir} = \@newstops;
      }
      else {
         delete $stops_of{$linedir};
      }
   }


}      

close $baglist or die $!;

while ( my ($linedir, $sign) = each %stop_used) {
   print join ("\t" , $linedir, $sign) , "\n";
}

