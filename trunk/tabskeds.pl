#!/ActivePerl/bin/perl
# tabskeds

# This is the program that creates the "tab files" that are used in the 
# Designtek-era web schedules

# legacy stage 1

# Makes tab-delimited but public versions of the skeds in /skeds

@ARGV = qw(-s w07) if $ENV{RUNNING_UNDER_AFFRUS};

use strict;
use warnings;
no warnings 'uninitialized';

####################################################################
#  load libraries
####################################################################

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin


use Actium::Sorting::Line ('sortbyline');
use Skedfile qw(Skedread Skedwrite GETFILES_PUBLIC
                getfiles GETFILES_PUBLIC_AND_DB trim_sked copy_sked);

use Skedvars qw(%longerdaynames %longdaynames %longdirnames
                 %dayhash        %dirhash      %daydirhash
                 %adjectivedaynames %bound %specdaynames
                );
 
my @specdaynames;
foreach (keys %specdaynames) {
    push @specdaynames, $_ . "\035" . $specdaynames{$_};
}

use Skedtps qw(tphash tpxref destination TPXREF_FULL);
use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);

use Actium::Options (qw<option add_option init_options>);
add_option ('upcoming=s' , 'Upcoming signup');
add_option ('current!' , 'Current signup');
use Actium::Term (qw<printq sayq>);
use Actium::Folders::Signup;

init_options;


my $signupdir = Actium::Folders::Signup->new();
chdir $signupdir->path();
my $signup = $signupdir->signup;

use Actium::Constants;

our %second = ( "40L" => '40' , "59A" => '59' , "72M" => '72' ,
                386  => '86' , DB3 => 'DB' , DB1 => 'DB' ,
               ); # , '51S' => '51' );


our %first = reverse %second; # create a reverse hash, with values of %second as keys and 
# keys of %second as values

our (%maplines);

$| = 1; # don't buffer terminal output

printq "tab - create a set of public tab-delimited files\n\n" ;

printq "Using signup $signup\n" ;

open DATE , "<effectivedate.txt" 
      or die "Can't open effectivedate.txt for input: $!";
our $effdate = scalar <DATE>;
close DATE;
chomp $effdate;

my $prepdate;

{
my ($mday, $mon, $year) = (localtime(time))[3..5];
$mon = qw(Jan. Feb. March April May June July Aug. Sept. Oct. Nov. Dec.)[$mon];
$year += 1900; # Y2K compliant
$prepdate = "$mon $mday, $year";
}

our (@lines , %lines, @skedadds, %skedadds, %colors, @colors);

printq "Timepoints and timepoint names... " ;
my $vals = Skedtps::initialize(TPXREF_FULL);
printq "$vals timepoints.\nLines... " ;
FPread_simple ("Lines.csv" , \@lines, \%lines, 'Line');
printq scalar(@lines) , " records. Colors...\n" ;
FPread_simple ("Colors.csv" , \@colors, \%colors, 'ColorID');
printq scalar(@lines) , " records. SkedAdds...\n" ;
FPread_simple ("SkedAdds.csv" , \@skedadds, \%skedadds, 'SkedID');
printq scalar(@lines) , " records.\n" ;

mkdir "tabxchange" or die "Can't make directory 'tabxchange': $!"
               unless -d "tabxchange";

my @files = getfiles(GETFILES_PUBLIC_AND_DB);

my %skednamesbyroute = ();
my %skeds;
my %index;

#use Data::Dumper;
#open my $dump , '>' , "/tmp/timepoints.dump";
#print $dump Data::Dumper::Dumper(\%Skedtps::timepoints);
#close $dump;

# slurp all the files into memory and build hashes
foreach my $file (@files) {
   my $sked = Skedread($file);
   my $skedname = $sked->{SKEDNAME};
   $skeds{$skedname} = $sked;

   my %routes = ();
   $routes{$_} = 1 foreach @{$sked->{ROUTES}}; # remember "ROUTES" is one for each trip
   @{$sked->{ALLROUTES}} = keys %routes;

   foreach my $route (@{$sked->{ALLROUTES}}) {
      push @{$skednamesbyroute{$route}},$skedname;
   }
}

print "\n";

# write files

foreach my $route (sortbyline keys %skednamesbyroute) {

   next if $second{$route};

   printf "%-4s", $route;

   foreach my $skedname  (sort bydaydirhash (@{$skednamesbyroute{$route}})) {

       my $skedref = $skeds{$skedname};

       open OUT , ">", "tabxchange/" . $skedname . ".tab" or die "can't open $skedname.tab for output";

       my @allroutes = sortbyline (uniq(@{$skedref->{ROUTES}}));
       my $linegroup = $allroutes[0];

       # GENERAL SCHEDULE INFORMATION

       outtab ($skedname);
       my $day = $skedref->{DAY};
       outtab( $day, $adjectivedaynames{$day}, $longdaynames{$day}, $longerdaynames{$day} );
       my $dir = $skedref->{DIR};

       my @tp = (@{$skedref->{TP}}); 

       my $destination = destination($tp[-1]) ;

       if ($dir eq 'CC') {
          $destination = "Counterclockwise to $destination,";
       }
       elsif ($dir eq 'CW') {
          $destination = "Clockwise to $destination,";
       }
       else {
          $destination = "To $destination,";
       }


       #outtab($dir, $longdirnames{$dir},$skedadds{$skedname}{"DirectionText"});
       outtab ($dir, $longdirnames{$dir} , $destination);

       # LINEGROUP FIELDS

       outtab ("U" , $linegroup , $lines{$linegroup}{LineGroupWebNote} , $lines{$linegroup}{LineGroupType} , 
               $lines{$linegroup}{UpcomingOrCurrentLineGroup});
       outtab (@allroutes);

       my @skednames;
       foreach (@allroutes) {
          push @skednames, (@{$skednamesbyroute{$linegroup}});
       }
       outtab (sort +(uniq (@skednames)));

       # LINE FIELDS

       foreach (@allroutes) {
          my $colorref = $colors{$lines{$linegroup}{Color}};
          outtab ($_ , $lines{$_}{Description}, $lines{$_}{DirectionFile}, $lines{$_}{StopListFile}, 
                  $lines{$_}{MapFileName} , '', , $lines{$_}{TimetableDate},
                  $colorref->{"Cyan"} , $colorref->{"Magenta"} , $colorref->{"Yellow"}, $colorref->{"Black"}, 
                  $colorref->{"RGB"} )

       }

       # TIMEPOINT FIELDS

       #my @tp = (@{$skedref->{TP}});  # moved earlier

       #outtab (@tp);
       my (@tp4, @tp_lookup);
       @tp_lookup = @tp;
       s/=\d+\z// foreach @tp_lookup;
       Skedtps::delete_punctuation(@tp_lookup);
       push @tp4 , $Skedtps::timepoints{$_}{Abbrev4} foreach @tp_lookup;

       outtab (@tp4);

       my $tpcol;
       for $tpcol ( 0 .. $#tp) {

          my $tp = $tp[$tpcol];
          my $tp_lookup = $tp_lookup[$tpcol];
          my $tp4 = $tp4[$tpcol];
          #my $tp = tpxref($tp[$tpcol]);
          my $faketimepointnote;
          #$faketimepointnote = "Waits six minutes for transferring BART passengers."
          #    if $tp eq "SHAY BART" and $skedname eq "91_SB_WD";


          warn "Not 4 characters: [$tp4/$tp_lookup/$tp]" if length($tp4) != 4;

          outtab (
                 $tp4,
                 tphash($tp) , 
                 $Skedtps::timepoints{$tp_lookup}{City} , 
                 $Skedtps::timepoints{$tp_lookup}{UseCity} , 
                 $Skedtps::timepoints{$tp_lookup}{Neighborhood} , 
                 $Skedtps::timepoints{$tp_lookup}{TPNote} , 
                 $faketimepointnote  ); 
                 # When you add a way to have "Notes associated with a timepoint (column) in this schedule alone",
                 # replace $faketimepointnote with that.

       }
          
       # SCHEDULE FIELDS

       #outtab (@{$skedref->{NOTEDEFS}});
       # Fake some NOTEDEFS

       my @notedefs;

       for  ($skedname) {
          if (/^43/) {
              @notedefs = ("F Serves Bulk Mail Center.", "G Serves Bulk Mail Center.")
          } elsif (/^51/) {
              @notedefs = ("B On school days, except Fridays, operates three minutes earlier between Broadway & Blanding Ave. and Atlantic Ave. & Webster St. Stops at College of Alameda administration building.")
          } elsif (/^I81/) { # never a line I81  -- serves to comment out code 
              @notedefs = 
              ("D Serves Griffith St, Burroughs Ave., and Farallon Dr." ,
               "E Serves Griffith St, Burroughs Ave., and Farallon Dr." ,
               "K Serves Griffith St, Burroughs Ave., and Farallon Dr." ,
               "L Serves Hayward Amtrak." ,
               "M Serves Hayward Amtrak." ,
               "Q Serves Griffith St, Burroughs Ave., and Farallon Dr., and also Hayward Amtrak." ,
               "R Serves Hayward Amtrak." ,
              );

          } elsif (/^I84/) {
	           @notedefs = 
                ("A Does not serve Fargo Ave.; operates via Lewelling Blvd. and Washington Ave." ,
                 "B Does not serve Fargo Ave.; operates via Washington Ave. and Lewelling Blvd." )
          } elsif (/^LA?/) {
              @notedefs = 
                ('LC This "L & LA" trip operates as Line L as far as El Portal Dr. & I-80, then continues and serves Line LA between Hilltop Park & Ride and Richmond Parkway Transit Center.');
          } elsif (/^NX2/ or /^NX3/) {
             @notedefs = ('NC This trip is an "NX2 and NX3" trip or "NX2 and NX3 and NX4" trip and serves all areas on Line NX2 before continuing on Line NX3 and Line NX4.');   
          } elsif (/^NX4/) {
             @notedefs = ('NC This trip is an "NX2 and NX3 and NX4" trip and serves all areas on ines NX2 and NX3 before continuing on Line NX4.');   
          }
       }
       
       for (@notedefs) {
          s/ /$KEY_SEPARATOR/ unless /$KEY_SEPARATOR/;
       }
       
       outtab (@notedefs);

       outtab ($skedadds{$skedname}{FullNote} , $lines{$linegroup}{LineGroupNote});

       outtab ( $skedadds{$skedname}{UpcomingOrCurrentSkedID});
       # Right now the line group fields are specified in the first line of each line group. This isn't ideal but
       # might be OK

       outtab (@specdaynames);      

       outtab (@{$skedref->{SPECDAYS}});
       outtab (@{$skedref->{NOTES}});
       outtab (@{$skedref->{ROUTES}});

       for $tpcol ( 0 .. $#tp) {
          outtab (@{$skedref->{TIMES}[$tpcol]});
       }

       close OUT;

   }

}

print "\n";

sub outtab { 
   my @fields = @_;
   foreach (@fields) {
      s/\n/ /g;
   }
   print OUT join("\t" , @fields , "\n") 
}

sub uniq {
   my %seen;
   return sortbyline grep {! $seen{$_}++}  @_;
}

sub bydaydirhash {
   (my $aa = $a) =~ s/.*?_//; # minimal: it matches first _
   (my $bb = $b) =~ s/.*?_//; # minimal: it matches first _
   $daydirhash{$aa} cmp $daydirhash{$bb};
}
