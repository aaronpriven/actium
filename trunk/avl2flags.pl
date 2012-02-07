#!/ActivePerl/bin/perl

@ARGV = qw(-s sp09) if $ENV{RUNNING_UNDER_AFFRUS};

# avl2flags.pl

# legacy stage 2
#
# A variant of avl2stoplines. It is not much different from that program,
# but has a slightly different output. All these avl2stoplines programs
# should be redone to provide all the different outputs 

use warnings;
use strict;

use 5.012;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ($Bin , "$Bin/../bin");

use Carp;
use POSIX ('ceil');
#use Fatal qw(open close);
use Storable();

use Actium::Util ('jt');
use Actium::Constants;
use Actium::Union('ordered_union');
use Actium::Sorting::Line (qw(sortbyline));
use Actium::DaysDirections (':ALL');

use Actium::Options;
use Actium::Signup;
my $signup = Actium::Signup->new();
chdir $signup->get_dir();

use List::Util ('max');

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2stoplines reads the data written by readavl and turns it into a 
list of stops with the lines served by that stop.
It is saved in the file "stoplines.txt" in the directory for that signup.
EOF

my $intro = 'avl2stoplines -- make a list of stops with lines served from AVL data';

# retrieve data

my %pat;
my %stp;

{ # scoping
# the reason to do this is to release the %avldata structure, so Affrus 
# (or, presumably, another IDE)
# doesn't have to display it when it's not being used. Of course it saves memory, too

my $avldata_r = $signup->retrieve('avl.storable');

%pat = %{$avldata_r->{PAT}};

%stp = %{$avldata_r->{STP}};

}

my (%routes_of, %routecdirs_of , %routedirs_of);

PAT:
foreach my $key (keys %pat) {

   next unless $pat{$key}{IsInService};

   my $route = $pat{$key}{Route};
   next if $route eq '399';

   my $dir = dir_of_hasi( $pat{$key}{DirectionValue});

   my $routedir = "$route-$dir";

   my $routecdir;
   if ($dir eq "CW" or $dir eq 'CC') {
      $routecdir = $routedir;
   }
   else {
      $routecdir = $route;
   }  

   foreach my $tps_r ( @{$pat{$key}{TPS}}) {
       my $stopid = $tps_r->{StopIdentifier};
       next unless $stopid =~ /^\d+$/msx;
       
       $routes_of{$stopid}{$route} = 1;
       $routedirs_of{$stopid}{$routedir} = 1;
       $routecdirs_of{$stopid}{$routecdir} = 1;

   }

}

# load the stops that are changing
open my $in , '<' , 'compare/comparestops-x.txt' or die $!;
my %stop_used;
while (<$in>) {
   my ($type, $stop);
   ($type, $stop, undef) = split (/\t/ , $_ , 3);
   $stop_used{$stop} = $type;
}
close $in or die $!;


my (@with_routes, @with_routedirs, @with_routecdirs );

my $max = 0;

open my $stoplines , '>' , 'stoplines.txt' or die "$!";

say $stoplines "StopID\tLines\tRoutes\tRoutesAndDirs\tRoutesAndCDirs";

foreach my $stop (sort keys %routes_of) {
   #next unless $stop_used{$stop};
   #next if $stop_used{$stop} eq 'RL';
   print $stoplines "$stop\t";
   my @routes = sortbyline keys %{$routes_of{$stop}} ;
   my @routedirs = sortbyline keys %{$routedirs_of{$stop}} ;
   my @routecdirs = sortbyline keys %{$routecdirs_of{$stop}} ;

   my $routes = scalar @routes;
   my $routedirs = scalar @routedirs;
   my $routecdirs = scalar @routecdirs;


   print $stoplines join (" " , @routedirs);
   
   say $stoplines "\t" , join ("\t" , $routes, $routedirs, $routecdirs);
   
   no warnings 'numeric';

   $with_routes[$routes]++;
   $with_routedirs[$routedirs]++;
   $with_routecdirs[$routecdirs]++;

   $max = max ($max, $routes, $routedirs, $routecdirs);

}

say "With\tRoutes\tRDirs\tRCDirs";

my $null = ".";

for my $num (reverse 1 .. $max ) {


   my $routes = $with_routes[$num] || $null;
   my $routedirs = $with_routedirs[$num] || $null;
   my $routecdirs = $with_routecdirs[$num] || $null;

   say (jt ($num , $routes , $routedirs , $routecdirs));

}

say '';

=head1 NAME

avl2stoplines - Make a list of stops with the lines for that stop.

=head1 DESCRIPTION

avl2stoplines reads the data written by readavl and turns it into a 
list of stops with the lines served by that stop. 
It is saved in the file "stoplines.txt" in the directory for that signup.

=head1 AUTHOR

Aaron Priven

=cut



