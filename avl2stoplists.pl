#!/ActivePerl/bin/perl

@ARGV = qw(-s sp09) if $ENV{RUNNING_UNDER_AFFRUS};

# avl2stoplists - see POD documentation below

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ($Bin , "$Bin/../bin");

use 5.012;

use Carp;
#use Fatal qw(open close);
use Storable();

use Actium::Util (qw<jn jt>);
use Actium::Constants;
use Actium::Union('ordered_union');
use Actium::DaysDirections ('dir_of_hasi');

use Actium::Files::FileMaker_ODBC (qw[load_tables]);

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2stoplists reads the data written by readavl and turns it into lists
of stops in order for each pattern and each route. These routes are stored in
the "slists" directory in the signup directory.
See "perldoc avl2stoplists" for more information.
EOF

my $intro = 'avl2stoplists -- make stop lists by pattern and route from AVL data';

use Actium::Options (qw<add_option option init_options>);
add_option ('random' , 'Give stops in random order instead of sorted');

use Actium::O::Folders::Signup;

init_options;

my $signup = Actium::O::Folders::Signup->new();
chdir $signup->path();

# retrieve data

my $slistsfolder = $signup->subfolder('slists');
my $patfolder = $slistsfolder->subfolder('pat');
my $linefolder = $slistsfolder->subfolder('line');
my $linewinfolder = $slistsfolder->subfolder('line-win');

my %pat;
my %tps;

my %stops;

load_tables(
    requests => {
        Stops_Neue => {
            hash        => \%stops,
            index_field => 'h_stp_511_id',
            fields => [qw[h_stp_511_id c_description_full ]],
        },
    }
);

{ # scoping
# the reason to do this is to release the %avldata structure, so Affrus 
# (or, presumably, another IDE)
# doesn't have to display it when it's not being used. Of course it saves memory, too

my $avldata_r = $signup->retrieve('avl.storable');

%pat = %{$avldata_r->{PAT}};

}

my $count = 0;

my %liststomerge;

PAT:
foreach my $key (keys %pat) {

   my $dir = $pat{$key}{DirectionValue};
   next unless dir_of_hasi($dir); 
   $dir = dir_of_hasi($dir);

   my $route = $pat{$key}{Route};

   my $filekey;
   ($filekey = $key) =~ s/$KEY_SEPARATOR/-$dir-/g;

   open my $fh , '>:utf8' , "slists/pat/$filekey.txt" or die "Cannot open slists/pat/$filekey.txt for output";

   unless (option(qw(quiet))) {
	   printf "%13s" , $filekey;
	   $count++;
	   print "\n" unless $count % 6;
   }

   print $fh join ("\t" , $route , $dir , $pat{$key}{Identifier} , $pat{$key}{Via} , $pat{$key}{ViaDescription}) ;
   print $fh "\n";
   
   my @thesestops;
   
   foreach my $tps_r ( @{$pat{$key}{TPS}}) {
       my $stopid = $tps_r->{StopIdentifier};
       
       push @thesestops , $stopid;
       
       print $fh $stopid , "\t" , $stops{$stopid}{c_description_full} , "\n";
   }

   push @{$liststomerge{$route}{$dir}} , \@thesestops;
   
   close $fh;

}

print "\n\n";

$count = 0;

my %stops_of_line;

foreach my $route (keys %liststomerge) {
   foreach my $dir (keys %{$liststomerge{$route}}) {
   
      unless (option qw{quiet}) {
		   printf "%13s" , "$route-$dir";
		   $count++;
		   print "\n" unless $count % 6;
	   }

      my @union = @{ ordered_union(@{$liststomerge{$route}{$dir}}) };
      $stops_of_line{"$route-$dir"} = \@union;
      
      {
      open my $fh , '>:utf8' , "slists/line/$route-$dir.txt" or die "Cannot open slists/line/$route-$dir.txt for output";
      print $fh jt( $route , $dir ) , "\n" ;
      foreach (@union) {
         print $fh jt($_, $stops{$_}{c_description_full}) , "\n";
      }
      close $fh;
      }
      
            {
      open my $fh , '>:utf8' , "slists/line-win/$route-$dir.txt" or die "Cannot open slists/line-win/$route-$dir.txt for output";
      print $fh jt( $route , $dir ) , "\r\n" ;
      foreach (@union) {
         print $fh jt($_, $stops{$_}{c_description_full}) , "\r\n";
      }
      close $fh;
      }
      
   
   }
}

print "\n\n";

Storable::nstore (\%stops_of_line , "slists/line.storable");


=head1 NAME

avl2stoplists - Make stop lists by pattern and route from AVL files.

=head1 DESCRIPTION

avl2stoplists reads the data written by readavl and turns it into lists of stops by pattern and by route.  First it produces a list for each pattern 
(files in the form <route>-<direction>-<patternnum>.txt) and then one for each route (in the form <route>-<direction>.txt. Lists for each pattern are
merged using the Algorithm::Diff routine. 

=head1 AUTHOR

Aaron Priven

=cut



