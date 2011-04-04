#!/usr/bin/perl

@ARGV = qw(-s sp10) if $ENV{RUNNING_UNDER_AFFRUS};

# avl2stoplists - see POD documentation below

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

use Actium::Sorting( qw<byline>);
use Actium::Constants;
use List::Util (qw<max>);

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
slists2bagorder makes the order for bags (that is, listing stops by route in order
of traversing that route) from the line.storable file.
EOF

my $intro = 'slists2bagorder -- makes order for bags';

use Actium::Options;
use Actium::Signup;
my $signup = Actium::Signup->new();
chdir $signup->get_dir();

# retrieve data
my %stops_of = %{ Storable::retrieve('compare/oldline.storable') } or die $!;

# delete bad lines like NC and LC
#foreach my $linedir (keys %stops_of) {
#   if (    $linedir =~ /^NC/ or $linedir =~ /^LC/ or  $linedir =~ /^399/ or $linedir =~ /^51S/ ) {
#       delete $stops_of{$linedir};
#   }
#}

# load the stops that are changing
open my $in , '<' , 'compare/comparestops-x.txt' or die $!;
my %stop_used;

while (<$in>) {

   my ($type, $stop);
   ($type, $stop, undef) = split (/\t/ , $_ , 3);

   next unless $type ~~ [qw(AL RL CL) ] ;
   
   $stop_used{$stop} = $type;
}
close $in or die $!;

# eliminate all stops that are not changing
while (my ($linedir , $stops_r) = each %stops_of) {
   my @newstops;
   foreach my $stop (@{$stops_r}) {
      push @newstops, $stop if $stop_used{$stop};
   }
   $stops_of{$linedir} = \@newstops;
}

# Now %stops_of contains all stops in every line.

open my $baglist, '>' , 'compare/baglist.txt' or die $!;

while ( scalar keys %stops_of ) {


   my @list = keys %stops_of;

    my $max_linedir = (sort { 
       ( $a =~ /^6\d\d/ <=> $b =~ /^6\d\d/ ) or
       ( scalar @{$stops_of{$b}} <=> scalar @{$stops_of{$a}} ) or
       byline ($a , $b) 
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

while ( my ($linedir, $type) = each %stop_used) {
   print join ("\t" , $linedir, $type) , "\n";
}

sub numify {
    my $num = shift;
    return "ZZZZ" if $num =~ /^6\d\d/;
    return $num;

}

