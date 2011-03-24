#!/usr/bin/perl
# vimcolor: #200020 

# makefulls
#
# This program generates full schedules suitable for pouring into
# a desktop publishing program.

use strict;
use warnings;

use constant NL => "\r";

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Skedfile qw(Skedread remove_blank_columns getfiles trim_sked copy_sked);
use Skeddir;
use Skedvars;
use Actium::Sorting (qw(sortbyline));
use FPMerge qw(FPread FPread_simple);
use Skedtps qw(tphash TPXREF_FULL); 
use Myopts;

use Storable qw(dclone);

my %options;
Myopts::options (\%options, Skeddir::options(), 'quiet!' , 'quark');
# command line options in %options;

my $outdir;
if ( $options{'quark'} ) {
   TaggedText::preparequark() if $options{'quark'};
   $outdir = 'fulls-qk';
} else {
   $outdir = 'fulls';
}
   
# defaults to indesign

$| = 1; # make stdout "hot"

print <<"EOF" unless $options{quiet};
makefulls - This is the makefulls program. It creates printable full
schedules for each schedule in the system.

EOF

my $signup;
$signup = (Skeddir::change (\%options))[2];
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.

mkdir $outdir or die "Can't create $outdir directory" unless -d $outdir;

# open and load files

print "Using signup $signup\n\n" unless $options{quiet};

print <<"EOF" unless $options{quiet};
Now loading data...
EOF

# read in FileMaker Pro data into variables in package main

print "Timepoints and timepoint names... " unless $options{quiet};
my $vals = Skedtps::initialize (TPXREF_FULL);
print "$vals timepoints.\n" unless $options{quiet};

our (%lines , @lines);
FPread_simple("Lines.csv" , \@lines, \%lines , 'Line');

our (%skedadds , @skedadds);
FPread("Skedadds.csv" , \@skedadds, \%skedadds , 'SkedID');

open DATE , "<effectivedate.txt" 
      or die "Can't open effectivedate.txt for input";

our $effdate = scalar <DATE>;
close DATE;
chomp $effdate;

# define tags

our (%quark , %indesign , %tags);
         
%quark = (
BIGSPACE => '<\q><\q>' ,
BOXBREAK => '<\\b>' ,
ST => '<f"Zapf Dingbats">H<f$>',
SD => '<f"Carta">V<f$>',
SH => '<f"Festive"><\#105><f$>',
'*' => '<f"Transportation"><\#121><f$>',
PARASTYSTART => '<@' ,
PARASTYEND => ':' ,
CHARSTYSTART => '<@' ,
CHARSTYEND => ':' ,
NOBREAKSPC => '<\!s>' ,
BOLDFONT => '<f"HelveticaNeue BoldCond">',
NOBOLDFONT => '<f$>' ,
START => '' ,
);

%indesign = (
BIGSPACE => '<0x2002>' ,
BOXBREAK => "<cNextXChars:Box>\r<cNextXChars:>" ,
ST => '<cFont:Zapf Dingbats>H<cfont:>',
SD => '<cFont:Carta>V<cFont:>',
SH => '<cFont:Festive">i<cFont:>',
'*' => '<cFont:Transportation>y<cFont:>',
PARASTYSTART => '<ParaStyle:' ,
PARASTYEND => '>',
CHARSTYSTART => '<CharStyle:' ,
CHARSTYEND => '>',
NOBREAKSPC =>  '<0x00A0>' ,
BOLDFONT => '<CharStyle:pmtimes>' ,
NOBOLDFONT => '<CharStyle:>' ,
START => "<ASCII-MAC>\r" ,
);

$indesign{START} .= "<DefineParaStyle:$_=>" foreach 
    ( qw(headnum headname headdest headdays tpnum tpname times timesblank legend) );

$indesign{START} .= "<DefineCharStyle:$_=>" foreach 
    ( qw(pmtimes) );

%tags = %indesign;

# main loop

unless ($options{quiet} ) {
   print "Now processing full schedules " unless $options{quiet};
   if ($options{quark}) {
      print "(Quark Tags)";
   } else {
      print "(Indesign Tags)";
   }
   print ".\n";
}

my @files = getfiles();

foreach my $file (@files) {

    my %usedroutes = ();
   
    my $sked = Skedread ($file); 

    print STDOUT "\nProcessing " , $sked->{SKEDNAME} 
            unless $options{quiet};

    output_fullsched ($sked);

    $usedroutes{$_}++ foreach @{$sked->{ROUTES}};

    my @routes = sortbyline keys %usedroutes;

    foreach my $i ( 1 .. ( 2**(scalar @routes)) - 2 ) {
        # this skips the all-bits-off subset (0)
        # and all-bits-on subset ( 2**(scalar @routes) - 1)
        my @subset = () ; # ref to empty list
        foreach my $j ( 0 .. $#routes) {
           push @subset, $routes[$j] 
              if $i & (2**$j);
                 # add the $j'th entry to the subset,
                 # if bit $j is on in $i
        }

        print " [" , join("+" , @subset) , "]";
        output_fullsched ($sked, \@subset);
    }

}

print "\n";

sub output_fullsched {

   my $givensked = shift;
   my $subset = shift; # optional

   my $sked = copy_sked($givensked); 
   # copy $givensked to $sked. We don't want to trim the times away
   # from the given sked, because we may make a next pass...

   my %routes = trim_sked($sked, $subset);
   # trim away unused rows, duplicate rows, and unused columns.
   # returns a hash, where the keys are the rows used in this subset
   # (could be all of them), and the values are true. This allows
   # $routes{"some_route"} to act as an is-an-element lookup.

   my $bottomnotes = whole_sked_notes ($sked, \%routes);
   # note definitions at the bottom of the page. These are the ones
   # associated with the schedule.

   # The following puts the note definitions in %notedefs.
   # I am currently ignoring the NOTES field, since the only thing in there
   # is the misleading bicycle information. Add code here to deal with it
   # if there are more notes later. This is still here because NOTEDEFS
   # includes definitions for SPECDAYS as well as for NOTES. (Although these
   # are not currently added to the file...)
   my %notedefs = (SD => "School Days Only" , SH => "School Holidays Only");
   foreach (sort @{$sked->{NOTEDEFS}}) {
      my ($note, $def) = split (/:/);
      $notedefs{$note} = $def;
   }
   

   ### establish information about the days of service
   # $specdays is true if there is a special day note for any 
   # row (but not for ALL rows, just for one or a few rows).
   # The default days will be in $day (whether they are the
   # regular WE, WD, etc., or whether they are SD or SH or a 
   # pair of days like TT). $headday will be the longer text associated with
   # this code ("Monday through Friday", "Daily", etc.)

   my $specdays = 0;
   my $day = $sked->{DAY};
   my %specdays;

   if ( (exists $sked->{SPECDAYS}) and
        ( length(join ("" , @{$sked->{SPECDAYS}})) > 0 ) ) {
      # if there are any special days in the schedule
 
      $specdays{$_ or "BLANK"} = 1 foreach ( @{$sked->{SPECDAYS}} ) ;

      if ((scalar keys %specdays) == 1 ) { 
         # if there's only one special day
         $day = (keys %specdays)[0];
      } else {
         $specdays = 1;
         delete $specdays{BLANK};
      }
      # now %specdays includes all the special days
   }

   # establish the days used in the head
   my $headday;
   if ($notedefs{$day}) {
      $headday = $notedefs{$day};
      $headday =~ s/ only//i;
   } else {
      $headday = $Skedvars::longerdaynames{$day} || $day;
   }
  $headday .= $tags{BIGSPACE} . $tags{ST} if $bottomnotes;
  # add the "star" icon to the headday if it's relevant
  
   # put special days in the notes

   if ($specdays) {
      foreach my $thisday (sort keys %specdays) {
         next if $thisday eq $day;
         $bottomnotes .= NL if $bottomnotes;
         $bottomnotes .= $tags{$thisday} . $tags{BIGSPACE} . $notedefs{$thisday};
      }
   }

   my @routes = sortbyline keys %routes;

   ### Create rest of head, besides headday

   # head numbers and names
   my $headnum = join (" / " , @routes);
   my @names = ();
   foreach (@routes) {
      push @names, $lines{$_}{Name} if $lines{$_}{Name};
   }
   my $headname = join (" / " , @names);

   # the following is to get the head destination,
   # which will be the last used timepoint
   my $headdest = tphash($sked->{TP}[-1]) || $sked->{TP}[-1];
   $headdest = "To $headdest";

   ### set up some flags and convenience variables

   my $notescol =  $specdays;
   # if we ever have other kinds of notes, this allows us to add them
   # by changing this statement

   my $routescol = (scalar (keys %routes) > 1);

   my $tpcolumns = (scalar @{$sked->{TP}} );
   my $rows = (scalar @{$sked->{ROUTES}} );

   my $extracolumns = ($notescol ? 1 : 0) + ($routescol ? 1 : 0) ;
   # number of columns beyond the ones needed for the timepoint

   ### open output file
   my $fullsdir = "$outdir/" . $sked->{LINEGROUP};
   mkdir $fullsdir or die "Can't create directory $fullsdir"
       unless -d $fullsdir;
   my $outfile = $sked->{DAY} . "_" . $sked->{DIR};
   $outfile = join("_", @$subset) . "_$outfile" if $subset;
   $outfile .= "-$tpcolumns-f.txt";
   open OUT , ">$fullsdir/$outfile" or die "Can't open $outfile for writing";

   ### print head

   print OUT $tags{START};

   print OUT parastyle ('headnum')  , $headnum , $tags{BOXBREAK};
   print OUT parastyle ('headname') , $headname , NL ;
   print OUT parastyle ('headdest') , $headdest , NL ;
   print OUT parastyle ('headdays') , $headday , $tags{BOXBREAK};

   ### print timepoint numbers in boxes
   # TODO - arrange to match the boxes to the line maps (probably
   # by having the user enter map info in the SkedAdds table)
   # also, figure out if you should add blank entries to the boxes.
   # at this point, I don't know how many different timetable templates
   # there will be.

#   print OUT join($tags{BOXBREAK}, (1 .. $tpcolumns) ) , $tags{BOXBREAK};

   print OUT parastyle ('tpnum') , join($tags{BOXBREAK}, (1 .. $tpcolumns) ) ;
   print OUT $tags{BOXBREAK} x (17 - $tpcolumns );
   
   print OUT parastyle ('tpname') ; # if ($notescol or $routescol);
   print OUT 'Route' if $routescol; 
   print OUT ' and ' if ($notescol and $routescol);
   print OUT 'Notes' if $notescol;
  
   # print the long timepoints
   
   for my $col ( 0 .. $tpcolumns - 1) {
      print OUT $tags{BOXBREAK} , parastyle ('tpname');
      unless ($col == 0)  {
         print OUT "Dep. " if 
         ($sked->{TP}[$col-1] eq $sked->{TP}[$col]);
      }
      unless ($col == $tpcolumns - 1)  {
      # unless this is the last column, check to see if the next one
      # is the same as this one
         print OUT "Arr. " if 
           ($sked->{TP}[$col+1] eq $sked->{TP}[$col]);
      }
      my $thistp = tphash($sked->{TP}[$col]) || $sked->{TP}[$col];

      {
      my $n = $tags{NOBREAKSPC};
      $thistp =~ s/ (Apts|Ave?|Blvd|St|Ct|Dr|Rd|Pkwy|Sq|Terr|Fwy|Pl)\./${n}$1./g;
      $thistp =~ s/ (Plaza|Lane|School|Way|Mall|Road)/${n}$1/g;
      # make non-breaking spaces where we know we can
      }
      print OUT $thistp;
   }

   print OUT $tags{BOXBREAK} x (17 - $tpcolumns );

   ### print rows of times

   for my $row (0 .. $rows - 1) {

      print OUT NL if $row; # all but the first one
      print OUT parastyle ('times');
      #print OUT ($sked->{ROUTES}[$row] ) if $routescol;

      # currently this just does specdays. If you add other notes,
      # make an array of the relevant notes and print them all
      
      print OUT ($sked->{SPECDAYS}[$row] ) if $notescol;

      print OUT "\t";

      print OUT ($sked->{ROUTES}[$row] ) if $routescol;

      for my $col (0 .. $tpcolumns - 1 ) {
         my $time = $sked->{TIMES}[$col][$row] || "";
         my $ampm = chop $time;
         substr($time, -2, 0) = ":" if $time;
         if ($ampm eq "p") {
            print OUT "\t" , $tags{BOLDFONT} , $time, $tags{NOBOLDFONT};
         } else {
            print OUT "\t$time";
         } 
      }

      # add blank space for rules
      print OUT NL , parastyle('timesblank') unless (($row+1) % 6) ;
   } # row

   print OUT $tags{BOXBREAK} , parastyle ('legend') , $bottomnotes;

   close OUT;

}


sub whole_sked_notes {

   ### Assemble text of notes at bottom of page.
   ### These are ones that apply to the whole sked -- not to particular rows

   my $sked = shift;

   unless (exists ($skedadds{$sked->{SKEDNAME}})) {
      return "";
   } # if there aren't any full notes for this sked, skip it

   my %routes = %{+shift};
 
   my @wholenotes = ();
   my @notes2check;

   if (ref ($skedadds{$sked->{SKEDNAME}}) eq "ARRAY") {
      @notes2check = @{$skedadds{$sked->{SKEDNAME}}};
   } else { # it's a single one of the hash
      @notes2check = ( $skedadds{$sked->{SKEDNAME}}) ;
   }

   SKEDADD:
   foreach my $thisskedadd ( @notes2check ) {
      foreach my $thisnoteline (split (/\r/ , $thisskedadd->{Lines})) {
         if ($routes{$thisnoteline}) {
            push @wholenotes, $thisskedadd->{FullNote};
            next SKEDADD;
         }
      }
   }

   # so now @wholenotes contains all the notes that apply to the whole page.
 
   my %wholenotes;
   foreach (@wholenotes) {
      $wholenotes{$_} = 1 if $_;
   }
   @wholenotes = sort keys %wholenotes; # so now @wholenotes is unique

   @wholenotes = () unless join("" , @wholenotes);
   # if the contents of @wholenotes is empty, zero the thing out

   my $bottomnotes;
   if (@wholenotes) {
      $bottomnotes = $tags{ST} . $tags{BIGSPACE} . join(" " , @wholenotes);
   } else {
      $bottomnotes = "";
   }

   return $bottomnotes;

}


sub preparequark { %tags = %quark }

sub prepareindesign { %tags = %indesign }

sub parastyle { 
   return $tags{PARASTYSTART} . $_[0] . $tags{PARASTYEND}
}

sub charstyle { 
   return $tags{CHARSTYSTART} . $_[0] . $tags{CHARSTYEND}
}

