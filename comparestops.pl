#!/usr/bin/perl

@ARGV = qw(-s w08 -o f08) if $ENV{RUNNING_UNDER_AFFRUS};

# comparestops - see POD documentation below

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ($Bin , "$Bin/../bin");

use Carp;
#use Fatal qw(open close);
use Storable();

use Actium( qw[add_option initialize avldata sayq chdir_signup option]);
use Actium::Constants;
use Actium::Union('ordered_union');
use List::MoreUtils('uniq');
use Actium::HastusASI::Util (':ALL');

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2stoplists reads the data written by readavl.
It then assembles a list of stops and the routes that stop at each one.
Finally, it displays a list of new, deleted, and changed stops.
See "perldoc comparestops" for more information.
EOF

my $intro = 'comparestops -- compare old and new stops from AVL data';

add_option('oldsignup=s'
   , 'The older signup. The program compares data from the this signup to the one'
   . 'specified by the "signup" option.'
   );

Actium::initialize ($helptext, $intro);

my %newstoplists = assemble_stoplists();

open my $out, '>' ,  'comparestops.txt';
# done here so as to make sure the file is saved in the *new*
# signup directory

print $out "StopID\tStop Description\tAdded\tRemoved\tUnchanged\n";

chdir_signup ('oldsignup', 'ACTIUM_OLDSIGNUP' , 'old signup');

my %oldstoplists = assemble_stoplists();

my @stopids = uniq ( sort (keys %newstoplists, keys %oldstoplists) );

my %changes;

STOPID:
foreach my $stopid (@stopids) {

   if (not exists $oldstoplists{$stopid} ) {
      push @{$changes{ADDEDSTOPS}}, $stopid;
      next STOPID;
   }
   
   if (not exists $newstoplists{$stopid} ) {
      push @{$changes{DELETEDSTOPS}}, $stopid;
      next STOPID;
   }
   
   my @oldroutes = sort keys %{ $oldstoplists{$stopid}{Routes} };
   my @newroutes = sort keys %{ $newstoplists{$stopid}{Routes} };
   
   next STOPID if (join ('', @oldroutes)) eq (join('', @newroutes ));
   # no changes

   COMPONENT:
   foreach my $component ( Algorithm::Diff::sdiff (\@oldroutes, \@newroutes) ) {
   
      my ($action, $a_elem, $b_elem) = @$component;
      
      if ($action eq 'u') {
         push @{$changes{CHANGEDSTOPS}{$stopid}{UNCHANGED}} , $a_elem;
      } 
      
      if ($action eq 'c' or $action eq '-') {
         push @{$changes{CHANGEDSTOPS}{$stopid}{REMOVED}} , $a_elem; 
      }
      
      if ($action eq 'c' or $action eq '+') {
         push @{$changes{CHANGEDSTOPS}{$stopid}{ADDED}}   , $b_elem; 
      }
      
   }# COMPONENT

}# STOPID

print $out "Added stops:\n";

foreach my $added_stopid  ( @{$changes{ADDEDSTOPS}}) {
   print $out $added_stopid , "\t" , $newstoplists{$added_stopid}{Description} , "\t"
         , join (',' , sort keys %{$newstoplists{$added_stopid}{Routes}}) , "\n";
}

print $out "\nRemoved stops:\n";

foreach my $deleted_stopid  ( @{$changes{DELETEDSTOPS}}) {
   print $out $deleted_stopid , "\t\t" , $oldstoplists{$deleted_stopid}{Description} , "\t"
         , join (',' , sort keys %{$oldstoplists{$deleted_stopid}{Routes}}) , "\n";
}

print $out "\nChanged stops:\n";

foreach my $changed_stopid  ( keys %{$changes{CHANGEDSTOPS}}) {

   print $out $changed_stopid , "\t" , $oldstoplists{$changed_stopid}{Description};
   
   if (exists $changes{CHANGEDSTOPS}{$changed_stopid}{ADDED} ) {
      my @added = sort @{$changes{CHANGEDSTOPS}{$changed_stopid}{ADDED}};
      print $out "\t", join (',' , @added);
   } 
   else {
   print $out "\t";
   }

   if (exists $changes{CHANGEDSTOPS}{$changed_stopid}{REMOVED}) {
      my @removed = sort @{$changes{CHANGEDSTOPS}{$changed_stopid}{REMOVED}};
      print $out "\t" , join (',' , @removed);
   }
   else {
   print $out "\t";
   }
   
   if (exists $changes{CHANGEDSTOPS}{$changed_stopid}{UNCHANGED} ) {
      my @unchanged = sort @{$changes{CHANGEDSTOPS}{$changed_stopid}{UNCHANGED}};
      print $out "\t" , join (',' , @unchanged);
   }
   else {
   print $out "\t";
   }

   print $out "\n";   
}


sayq "Completed comparison.";


sub assemble_stoplists {

   my %stoplist = ();
   
	my (%pat, %stp);

	{ # scoping
	# the reason to do this is to release the %avldata structure, so Affrus 
	# (or, presumably, another IDE)
	# doesn't have to display it when it's not being used. Of course it saves memory, too

	my $avldata_r = avldata();

	%pat = %{$avldata_r->{PAT}};

	%stp = %{$avldata_r->{STP}};

	}

	PAT:
	foreach my $key (keys %pat) {

	   my $dir = $pat{$key}{DirectionValue};
	   next unless dir_of_hasi($dir); 
	   $dir = dir_of_hasi($dir); 

	   my $route = $pat{$key}{Route};

	   foreach my $tps_r ( @{$pat{$key}{TPS}}) {
	       my $stopid = $tps_r->{StopIdentifier};
	       
	       $stoplist{$stopid}{Routes}{"$route-$dir"} = 1;
	       $stoplist{$stopid}{Description} = $stp{$stopid}{Description};
	       
	   }

	}
	
	return %stoplist;

}


=head1 NAME

comparestops - Compares the stops from two sets of AVL files.

=head1 DESCRIPTION

comparestops reads the data written by readavl.
It then assembles a list of stops and the routes that stop at each one.
Finally, it displays a list of new, deleted, and changed stops.

=head1 AUTHOR

Aaron Priven

=cut
