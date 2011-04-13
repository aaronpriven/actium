#!/usr/bin/perl

# htmlskeds

# Makes html versions of the skeds in /skeds

# by the way, this is a really, really ugly hack of a program, with
# horrible style and completely insufficient modularity.
# I put this here just so anybody reading this knows that at least
# I know it too, and won't be struck too aghast at my terrible style.

use strict;

####################################################################
#  load libraries
####################################################################

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::Options (qw<option add_option>);

add_option ('upcoming:s' , 'Upcoming signup');
add_option ('current:s' , 'Current signup');

use Actium::Term (qw<printq sayq>);
use Actium::Signup;
my $signupdir = Actium::Signup->new();
chdir $signupdir->get_dir();

my $signup = $signupdir->get_signup;


use Skedfile qw(Skedread Skedwrite GETFILES_PUBLIC
                getfiles GETFILES_PUBLIC_AND_DB trim_sked copy_sked);
use Skedvars qw(%daydirhash %adjectivedaynames %bound %specdaynames);
use Actium::Sorting (qw(sortbyline));
use Skedtps qw(tphash TPXREF_FULL);
use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);

our %second = ( "72M" => '72' , 386  => '86' , DB1 => 'DB' , );

our %first = reverse %second;
# create a reverse hash, with values of %second as keys and 
# keys of %second as values

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

my $emailerlinktext = <<'EOF';

   <p><a href="http://www.actransit.org/acnews/">
   Have schedule and route changes delivered to your computer &#8211; subscribe to AC Transit e-News.
   </a></p>
   <!-- Yeah, I know. 
        1994 called, they want their Web style back. -->
EOF

my $genericemailerlinktext = <<'EOF';
   <p><a href="http://www.actransit.org/acnews/">
   Have schedule and route changes delivered to your computer &#8211; subscribe to AC Transit e-News.
   </a></p>
   <!-- Yeah, I know. 
        1994 called, they want their Web style back. -->
EOF

our (%maplines);

# command line options in %options;

$| = 1; # don't buffer terminal output

printq "htmlskeds - create a set of html files\n\n" ;

printq "Using signup $signup\n";
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "actium/db/xxxx" base directory.

#if ($signup eq 'sp05') {
#  $second{'82L'} = '82';
#   $first{'82'} = '82L';
#} # ugly hack because sp05 needs 82/82L joined while sum05 (and later, 
#  # presumably) does not

our $linemapfile;

if ($signup eq 'f05i' or $signup eq 'f05') {
   $linemapfile = 'line-map-legend-jun04.pdf';
} else {
   $linemapfile = 'line-map-legend-feb06.pdf';
}

my $legendtext = qq[ <font size=-1>(see also <a href="/pdf/schedulemaps/$linemapfile">the legend for line maps)</a></font>];

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

#$prepdate = localtime(time); # override for debugging only

our (@lines , %lines);

printq "Timepoints and timepoint names... ";
my $vals = Skedtps::initialize(TPXREF_FULL);
printq "$vals timepoints.\nLines... " ;
FPread_simple ("Lines.csv" , \@lines, \%lines, 'Line');
printq scalar(@lines) , " records.\n";

mkdir "html" or die 'Can\'t make directory "html": $!'  
               unless -d "html";

my @files = getfiles(GETFILES_PUBLIC_AND_DB);

my %skednamesbyroute = ();
my %skeds;
my %index;

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

   my %skedtext = ();

   my @theseroutes;
   my $linename;
   if ($first{$route}) {
      @theseroutes = ( $route , $first{$route} );
      if ( $lines{$route}{Name} eq $lines{$first{$route}}{Name} ) {

         $linename = "$route  & $first{$route} $lines{$route}{Name}";

      } else {

         $linename = "$route $lines{$route}{Name} & $first{$route} " .
                     $lines{$first{$route}}{Name};
      }

   } else {
      @theseroutes = ($route);
      $linename = "$route $lines{$route}{Name}";
   }

   $linename =~ s/�/\'/;

   $index{$route} = qq(<LI><a href="$route.html">$linename</a></LI>\n);

   my $lineword = "Line" ;
   $lineword .= "s" if $first{$route};

   open ROUTEF , ">html/$route.html" or die "Can't open $route.html: $!";
   open COMPLETE , ">html/$route-A.html" or die "Can't open $route-A.html: $!";
   
   print ROUTEF <<"EOF";
<HTML><HEAD><TITLE>AC Transit $lineword $linename</TITLE></HEAD>
<BODY><p><a href="http://www.actransit.org">AC Transit</a> : 
<a href="http://www.actransit.org/riderinfo/mapsandschedules.wu">Maps and Schedules</a> : 
<a href="index.html">Schedules</a> : $linename</p><hr>
<p><H2>AC Transit $lineword $linename</H2>
<p>Effective $effdate
EOF

   print ROUTEF upcoming();

   print ROUTEF "</p><p><UL>";
  


   my $linemaptext = "";

   if ($first{$route}) { # two routes
      if ($lines{$route}{MapFileName} eq $lines{$first{$route}}{MapFileName}) {
         if ($lines{$route}{MapFileName}) {
            $linemaptext = qq(<LI><a href="/pdf/schedulemaps/) . 
               $lines{$route}{MapFileName} . 
               qq(">Map for $lineword $linename</a>\n);
            $maplines{$route} = $linemaptext;
         }

         # if they're the same, print the line -- but only if it's not blank
      } else { # they're different

         for ($route , $first{$route}) {
            next unless $lines{$_}{MapFileName};
            $maplines{$route} = mapline($_);
            $linemaptext .= $maplines{$route};
         }
      }

   } elsif ($lines{$route}{MapFileName}) { # only one route, and it's got a map entry
      $linemaptext = mapline($route);
      $maplines{$route} = $linemaptext;
   }

   if ($linemaptext) {
      $linemaptext =~ s/�/\'/;
      print ROUTEF $linemaptext , $legendtext , "</ul>\n<ul>";
   }

   my @skednames = sort bydaydirhash (@{$skednamesbyroute{$route}}) ;

   foreach my $skedname ( @skednames ) {
      my ($linegroup, $dir, $day) = split(/_/ , $skedname);
      print ROUTEF qq(<LI><a href="$route-$dir-$day.html">);
      print ROUTEF "$bound{$dir} $adjectivedaynames{$day} Schedule</a>\n";
   }
   print ROUTEF qq(</ul><ul><LI><a href="$route-A.html">);
   print ROUTEF "Complete Schedule</a>\n";

   print ROUTEF "</UL><hr>\n";

   if ($lines{$route}{FullWebNote}) {
      $lines{$route}{FullWebNote} =~ s/�/\"/g;
      print ROUTEF "<p>" , $lines{$route}{FullWebNote} , "</p>";
   }

   print ROUTEF <<"EOF";
$emailerlinktext
Prepared by AC Transit Marketing and Communications<br>$prepdate
</BODY></HTML>
EOF

   close ROUTEF;

   print COMPLETE <<"EOF";
<HTML><HEAD><TITLE>$lineword $linename: Complete Schedule</TITLE>
<BODY><p>
<a href="http://www.actransit.org/">AC Transit</a> :
<a href="http://www.actransit.org/riderinfo/mapsandschedules.wu">Maps and Schedules</a> : 
<a href="index.html">Schedules</a> : 
<a href="$route.html">$linename</a> :
Complete Schedule</p><hr>
<h2>$lineword $linename</h2>
<h3>Complete Schedule</h3>
<p>Effective $effdate
EOF

   print COMPLETE upcoming();

   print COMPLETE "</p><hr>";

   print COMPLETE "<ul>$linemaptext $legendtext</ul><hr>\n" if $linemaptext;

   # loop around each schedule - output the HTML file

   foreach my $skedname (@skednames) {

      my $dir = $skeds{$skedname}{DIR};
      my $day = $skeds{$skedname}{DAY};

      my $title = 
        "$lineword $linename, $bound{$dir} $adjectivedaynames{$day} Schedule";

      open HTML, ">html/$route-$dir-$day.html";

      print HTML <<"EOF";
<HTML><HEAD><TITLE>$title</TITLE>
<BODY><p>
<a href="http://www.actransit.org/">AC Transit</a> :
<a href="http://www.actransit.org/riderinfo/mapsandschedules.wu">Maps and Schedules</a> : 
<a href="index.html">Schedules</a> : 
<a href="$route.html">$linename</a> :
$bound{$dir} $adjectivedaynames{$day}</p><hr>
<h2>$lineword $linename</h2>
<h3>$bound{$dir} $adjectivedaynames{$day} Schedule</h3>
<p>Effective $effdate
EOF

   print HTML upcoming()  , "</p><p><font size=-1>";


      # TODO - insert "westbound", "Eastbound Weekend", etc. links here

      foreach my $linkskedname (@skednames) {
         my $linkdir = $skeds{$linkskedname}{DIR};
         my $linkday = $skeds{$linkskedname}{DAY};

         print HTML qq(<a href="$route-$linkdir-$linkday.html">)
              unless $linkskedname eq $skedname;
         print HTML "[$bound{$linkdir} $adjectivedaynames{$linkday}]";
         print HTML "</a>" unless $linkskedname eq $skedname;
         print HTML " " ;

      }

      print HTML qq(<a href="$route-A.html">);
      print HTML "[Complete Schedule]</a></font><hr>\n";

      ### all the "$skedtext{$skedname}"s used to be "print HTML"s

      $skedtext{$skedname} =
          qq(<p><a href="#key$dir$day">) . 
         "<font size=-1>[Key to abbreviations follows the schedule]</font></a></p><pre>";

      my $trimsked = copy_sked($skeds{$skedname});

      #print join ("-" , @theseroutes) , "\n";
      trim_sked ($trimsked , \@theseroutes );

      my @tp = ();

      my @timepointsnoeq = (@{$trimsked->{TP}}) ;
      s/=.*// foreach @timepointsnoeq;

      foreach my $tp (@timepointsnoeq) {

         # TODO - fix this split-the-TP9 routine. 
         my @temp;

         if (length($tp) != 9) {
            @temp = split (/ / , $tp);
            if ($#temp > 1 ) {
               my $tempy = pop @temp;
               $temp[0] .= " " . $temp[1];
               $temp[1] = $tempy;
            }
         } else {
            $temp[0] = substr($tp , 0, 4 );
            $temp[1] = substr($tp , 5, 4 );
         }
         $tp[$_] .= sprintf " %-5s" , scalar$temp[$_] foreach (0 , 1);
      }

      my %specdays = ();
      foreach my $specday ( @{$trimsked->{SPECDAYS}}) {
         $specdays{$specday} = 1;
      }

      delete $specdays{""} if $specdays{""};

      my $tps = "   RTE  $tp[0]\n   NUM  $tp[1]\n";

      my $count = 0;

      ROW:
      for my $row (0 .. $#{$trimsked->{ROUTES}}) {
         my $thisroute = $trimsked->{ROUTES}[$row];

         next ROW if $thisroute ne $route and
            $thisroute ne $first{$route};

         $skedtext{$skedname} .= '</pre><hr><pre>' unless $count == 0 or $count % 25 ;
         $skedtext{$skedname} .= $tps unless $count % 25;
         $skedtext{$skedname} .= "\n" unless $count % 5;
         $count++;

         $skedtext{$skedname} .= sprintf "%2s " , $trimsked->{SPECDAYS}[$row];
         $skedtext{$skedname} .= sprintf "%3s " , $trimsked->{ROUTES}[$row];

         for my $col (0 .. $#{$skeds{$skedname}{TP}}) {
             $skedtext{$skedname} .= sprintf " %5s" , $trimsked->{TIMES}[$col][$row];
         }
         $skedtext{$skedname} .= "\n";

      }

      $skedtext{$skedname} .= 
        qq(\n</pre><hr><p><b><a name="key$dir$day">Key to Abbreviations</a></b></p><pre>);

      if (scalar keys %specdays) {
         $skedtext{$skedname} .= $_ . "   " . $specdaynames{$_} . "\n"
              for (sort keys %specdays) ;
         $skedtext{$skedname} .= "\n";
      }
 

      my @desc = ();
      foreach (0 .. $#timepointsnoeq) {
         $desc[$_] = tphash($timepointsnoeq[$_]) . "\n";
         if ( $_ and $timepointsnoeq[$_] eq $timepointsnoeq[$_-1]) {
            $desc[$_] = "Depart " . $desc[$_];
            $desc[$_-1] = "Arrive " . $desc[$_-1];
         }
      }

      foreach (0 .. $#timepointsnoeq) {
         $skedtext{$skedname} .= sprintf ("%-9s  " , $timepointsnoeq[$_] ) . $desc[$_] ;
      }

      #foreach my $tp (@timepointsnoeq) {
      #   $skedtext{$skedname} .= sprintf "%-9s  " , $tp;
      #   $skedtext{$skedname} .= tphash($tp) . "\n";
      #}

      $skedtext{$skedname} .= "</pre><hr>";

      print HTML $skedtext{$skedname};
      if ($lines{$route}{FullWebNote}) {
         $lines{$route}{FullWebNote} =~ s/[��]/\"/g;
         print ROUTEF "<p>" , $lines{$route}{FullWebNote} , "</p>";
      }

   if ($lines{$route}{FullWebNote}) {
      $lines{$route}{FullWebNote} =~ s/�/\"/g;
      print HTML "<p>" , $lines{$route}{FullWebNote} , "</p>";
   }

      print HTML "<p>";
      print HTML $emailerlinktext , 
         "<p>Prepared by AC Transit Marketing and Communications<br>$prepdate";
      print HTML "</p>\n</body></html>";

      close HTML;

      print COMPLETE  
            "<h4>$bound{$dir} $adjectivedaynames{$day} Schedule</h4>\n" ,
            $skedtext{$skedname};

    } # skedname

   if ($lines{$route}{FullWebNote}) {
      $lines{$route}{FullWebNote} =~ s/�/\"/g;
      print COMPLETE "<p>" , $lines{$route}{FullWebNote} , "</p>";
   }

   print COMPLETE "<p>";
   print COMPLETE $emailerlinktext , 
      "<p>Prepared by AC Transit Marketing and Communications<br>$prepdate";
   print COMPLETE "</p>\n</body></html>";

   close COMPLETE;
  

} # route

print "\n";

open INDEX , ">html/index.html" or die "Can't open html/index.html: $!";
print INDEX  "<HTML><HEAD><TITLE>AC Transit Schedules</TITLE></HEAD>\n<BODY><p>";
print INDEX  qq(<a href="http://www.actransit.org">AC Transit</a> : );
print INDEX qq(<a href="http://www.actransit.org/riderinfo/mapsandschedules.wu">Maps and Schedules</a> : );
print INDEX  "Schedules</p><hr><p>";
print INDEX "<H2>AC Transit Schedules</H2>\n<p>Effective $effdate" , upcoming() , "</p>\n";

print INDEX <<EOF;
<UL><LI><A HREF="#Local">Local Service</A></LI>
<LI><A HREF="#Transbay">Transbay Service</A></LI>
<LI><A HREF="#AllNighter">All Nighter Service</A></LI>
<LI><A HREF="#School">School Service</A></LI>
</UL><HR>
EOF

my (@local, @transbay, @school,@allnighter);

foreach (keys %index ) {
   if (/^[\d]/) {
      if ($_ < 600) {
          push @local, $_;
      } elsif ($_ < 800) {
          push @school, $_;
      } else {
          push @allnighter, $_;
      }
   } else {
      #push @transbay, $_ unless $_ eq "DB";
      push @transbay, $_;
   }
}

print INDEX qq(<h3><a name="Local">Local Service</a></h3><UL>);
print INDEX $index{$_} foreach sortbyline @local;
print INDEX "</UL>\n";

print INDEX qq(<h3><a name="Transbay">Transbay Service</a></h3><UL>);
print INDEX $index{$_} foreach sortbyline @transbay;
print INDEX "</UL>\n";

print INDEX qq(<h3><a name="AllNighter">All Nighter Service</a></h3><UL>);
print INDEX $index{$_} foreach sortbyline @allnighter;
print INDEX "</UL>\n";

print INDEX qq(<h3><a name="School">School Service</a></h3><UL>);
print INDEX $index{$_} foreach sortbyline @school;
print INDEX "</UL>\n";

# print index bits

print INDEX  "<hr>\n";
print INDEX  $genericemailerlinktext , "Prepared by AC Transit Marketing and Communications<br>$prepdate";
print INDEX "</BODY></HTML>";

close INDEX;

open LMAPS , ">html/linemaps.html" or die "Can't open html/linemaps.html: $!";
print LMAPS  "<HTML><HEAD><TITLE>AC Transit Line Maps</TITLE></HEAD>\n<BODY>";
print LMAPS  qq(<a href="http://www.actransit.org">AC Transit</a> : );
print LMAPS qq(<a href="http://www.actransit.org/riderinfo/mapsandschedules.wu">Maps and Schedules</a> : );
print LMAPS  qq(Line Maps</p><hr>);

print LMAPS "<H2>AC Transit Line Maps</H2>\n";

print LMAPS <<"EOF";
<UL><LI><A HREF="#Local">Local Service</A></LI>
<LI><A HREF="#Transbay">Transbay Service</A></LI>
<LI><A HREF="#School">School Service</A></LI>
</UL>

<p>
See also <a href="/pdf/schedulemaps/$linemapfile">the legend for line maps.</a></p>
<hr>
EOF

@local = ();
@school = ();
@transbay = ();
@allnighter=();

foreach (keys %maplines ) {
   $maplines{$_} =~ s/Map for Lines? //;
   if (/^[\d]/) {
      if ($_ < 600) {
          push @local, $_;
      } elsif ($_ < 800) {
          push @school, $_;
      } else {
          push @allnighter, $_;
      }
   } else {
      #push @transbay, $_ unless $_ eq "DB" or $_ eq 'NC' or $_ eq 'LC';
      push @transbay, $_;
   }
}

print LMAPS qq(<h3><a name="Local">Local Service</h3><UL>);
print LMAPS $maplines{$_} foreach sortbyline @local;
print LMAPS "</UL>\n";

print LMAPS qq(<h3><a name="Transbay">Transbay Service</h3><UL>);
print LMAPS $maplines{$_} foreach sortbyline @transbay;
print LMAPS "</UL>\n";

print LMAPS qq(<h3><a name="AllNighter">All Nighter Service</h3><UL>);
print LMAPS $maplines{$_} foreach sortbyline @allnighter;
print LMAPS "</UL>\n";

print LMAPS qq(<h3><a name="School">School Service</h3><UL>);
print LMAPS $maplines{$_} foreach sortbyline @school;
print LMAPS "</UL>\n";

# print index bits

print LMAPS  "<hr>\n";
print LMAPS  $genericemailerlinktext , "Prepared by AC Transit Marketing and Communications<br>$prepdate";
print LMAPS "</BODY></HTML>";

close LMAPS;


sub bydaydirhash {
   (my $aa = $a) =~ s/.*?_//; # minimal: it matches first _
   (my $bb = $b) =~ s/.*?_//; # minimal: it matches first _
   $daydirhash{$aa} cmp $daydirhash{$bb};
}

sub mapline {

  my ($route) = shift;

  return qq(<LI><a href="/pdf/schedulemaps/) . 
         $lines{$route}{MapFileName} . 
         qq(">Map for Line $route ) . $lines{$route}{Name} . qq(</a>\n);
}

sub upcoming {

   return 
   qq[&nbsp;&nbsp;<font size=-1>(<a href="upcoming/">Upcoming schedules effective ] . options('upcoming') . " are also available</a>)</font>"
          if option('upcoming');

   return qq[&nbsp;&nbsp;<font size=-1>(<a href="../">Current schedules are also available</a>)</font>]
          if option('current');

}
