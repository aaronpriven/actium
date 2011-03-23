#!/ActivePerl/bin/perl

use warnings;
use 5.012;

# initialization

use FindBin('$Bin'); 
use lib ($Bin);

{
    no warnings('once');
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
    }
}

use IDTags;
use Skedfile qw(Skedread getfiles GETFILES_PUBLIC_AND_DB);
use Actium (qw(option ensuredir ));
use Skedvars qw(%longerdaynames %daydirhash %specdaynames);
use Array::Transpose;
use File::Slurp;

use Actium::Sorting('sortbyline');

use List::Util ('max');


use constant CR => "\r";

use FPMerge qw(FPread_simple);

my $helptext = <<'EOF';
tabula. Reads schedules and makes tables out of them.
EOF

my $intro = $helptext;

Actium::initialize ($helptext, $intro);

my (@timepoints, %timepoints);
FPread_simple ('Timepoints.csv' , \@timepoints, \%timepoints, 'Abbrev9');

ensuredir('tabulae');
ensuredir('tabulae/big');
ensuredir('tabulae/small');

my @files = getfiles(GETFILES_PUBLIC_AND_DB);

my %tags = indesign_tags();

my %tables_of_line;

foreach my $file (@files) {
    
   # open files and print InDesign start tag
   my %sked = %{Skedread($file)};
   my $skedname = $sked{SKEDNAME};
   my $linegroup = $sked{LINEGROUP};
   my $dir = $sked{DIR};
   my $day = $sked{DAY};
   
   my %specdays_used;

   # get number of columns and rows

   my @tps = @{$sked{TP}};

   s/=[0-9]+$// foreach @tps;

   my $tpcount = scalar @tps;
 
   my $halfcols = 0;

   my ($has_route_col,$has_specdays_col);

   my %seenroutes;
   $seenroutes{$_} = 1 foreach @{$sked{ROUTES}};
   my @seenroutes = sortbyline keys %seenroutes;

   if ( (scalar @seenroutes) != 1 ) {
      $halfcols++;
      $has_route_col = 1;
   }

   my $routechars = length (join('' , @seenroutes)) 
                    + ( 3 * ( $#seenroutes) ) 
                    + 1 ;
   # number of characters in routes, plus three characters -- space bullet 
   # space -- for each route except the first one, plus a final space

   my $bullet 
       = '<0x2009><CharStyle:SmallRoundBullet><0x2022><CharStyle:><0x2009>';
   my $routetext = join ($bullet, @seenroutes);

   my $dayname =  $longerdaynames{$sked{DAY}};

   my %seenspecdays;
   $seenspecdays{$_} = 1 foreach @{$sked{SPECDAYS}};
   if ( (scalar keys %seenspecdays) != 1 ) {
      $halfcols++;
      $has_specdays_col = 1;
   } 
   else {
      my ($specdays, $count) = each %seenspecdays; # just one
      if ($specdays) {
         $dayname = $specdaynames{$specdays};
      }
   }
         

         

   
   my $colcount = $tpcount + $halfcols;

   my %tpname_of;
   $tpname_of{$_} = $timepoints{$_}{TPName} foreach (@tps);
   my $destination = $timepoints{$tps[-1]}{DestinationF} || $tps[-1];

   my $timerows = scalar (@{$sked{ROUTES}});

   print $skedname ;
   print " (" , join(" " , sort keys %seenroutes) , ")" 
      if scalar keys %seenroutes > 1;
   print ", $tpcount";
   print "+$halfcols" if $halfcols;
   say " x $timerows" ;

   my $rowcount = $timerows + 2 ; # headers

   my $table;
   open my $th , '>' , \$table or die "Can't open table scalar for writing: $!";

   # Table Start
   print $th IDTags::parastyle('UnderlyingTables');
   print $th '<TableStyle:TimeTable>';
   print $th "<TableStart:$rowcount,$colcount,2,0<tCellDefaultCellType:Text>>";
   print $th '<ColStart:<tColAttrWidth:27.9444444444444>>' for ( 1 .. $halfcols) ;
   print $th '<ColStart:<tColAttrWidth:53.3333333333333>>' for ( 1 .. $tpcount) ;

   # Header Row (line, days, dest)
   print $th '<RowStart:<tRowAttrHeight:43.128692626953125>>';
   print $th '<CellStyle:ColorHeader><StylePriority:2>';
   print $th "<CellStart:1,$colcount>";
   print $th IDTags::parastyle('dropcaphead');
   print $th "<pDropCapCharacters:$routechars>$routetext ";
   print $th IDTags::charstyle('DropCapHeadDays');
   print $th $dayname;
   print $th IDTags::nocharstyle , '<0x000A>' ;
   print $th IDTags::charstyle('DropCapHeadDest', "\cGTo $destination"); # control-G is "Insert to Here"
   print $th IDTags::nocharstyle , '<CellEnd:>';
   for (2 .. $colcount)  {
      print $th '<CellStyle:ColorHeader><CellStart:1,1><CellEnd:>';
   }
   print $th '<RowEnd:>';

   # Timepoint Name Row

   print $th '<RowStart:<tRowAttrHeight:35.5159912109375><tRowAttrMinRowSize:3>>';

   if ($has_route_col) {
      print $th '<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>Line<CellEnd:>';
   }
   if ($has_specdays_col) {
      print $th '<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>Note<CellEnd:>';
   }
   for my $i (0 .. $#tps) {
      my $tp = $tps[$i];
      my $tpname = $timepoints{$tp}{TPName} || $tp;
      if ($i != 0 and $tps[$i - 1] eq $tp) {
         $tpname = "Leaves $tpname";
      } elsif ($i != $#tps and $tps[$i + 1] eq $tp) {
         $tpname = "Arrives $tpname";
      }
      print $th "<CellStyle:Timepoints><StylePriority:20><CellStart:1,1><ParaStyle:Timepoints>$tpname<CellEnd:>";
   }
   print $th '<RowEnd:>';

   # Time Rows

   my @timerows = Array::Transpose::transpose $sked{TIMES};

   for my $i ( 0 .. $#timerows ) {
      my @row = @{$timerows[$i]};

      print $th '<RowStart:<tRowAttrHeight:10.5159912109375>>';


      if ($has_route_col) {
         my $route = $sked{ROUTES}[$i];
         print $th "<CellStyle:LineNote><StylePriority:20><CellStart:1,1><ParaStyle:Time>$route<CellEnd:>";
      }
      if ($has_specdays_col) {
         my $specdays = $sked{SPECDAYS}[$i];
         print $th "<CellStyle:LineNote><StylePriority:20><CellStart:1,1><ParaStyle:Time>$specdays<CellEnd:>";
         $specdays_used{$specdays} = 1;
      }
 
      for my $j ( 0 .. $#row) {
         my $time = $row[$j];
         my $parastyle = 'Time'; 
         if ($time) { 
            substr($time, -3, 0) = ":"; # add colon
         } 
         else {
            $time = IDTags::emdash;
            $parastyle = 'LineNote'; 
         }
         print $th "<CellStyle:Time><StylePriority:20><CellStart:1,1><ParaStyle:$parastyle>";
         if ($time =~ /p$/ ) {
             print $th IDTags::bold($time);
         } 
         else {
            print $th $time;
         }
         print $th '<CellEnd:>';
      }

      print $th '<RowEnd:>';

   }


   # Table End
   print $th "<TableEnd:>\r";
   
   foreach my $specdays (keys %specdays_used ) {
       given ($specdays)  {
           when ('SD') {
               print $th "\rSD - School days only";
           }
           when ('SH') {
               print $th "\rSH - School holidays only";
           }
           
       }
       
   }
   
   close $th;

   $tables_of_line{$linegroup}{"${dir}_$day"}{TEXT} = $table;
   $tables_of_line{$linegroup}{"${dir}_$day"}{SPECDAYSCOL} = $has_specdays_col;
   $tables_of_line{$linegroup}{"${dir}_$day"}{ROUTECOL} = $has_route_col;
   $tables_of_line{$linegroup}{"${dir}_$day"}{WIDTH} = $tpcount + ($halfcols / 2);
   $tables_of_line{$linegroup}{"${dir}_$day"}{HEIGHT} = (3*12) + 6.136  # 3p6.136 height of color header
                                                      + (3*12) + 10.016 # 3p10.016 four-line timepoint header
                                                      + ($timerows * 10.516); # p10.516 time cell
                                                      
}

my $boxwidth = 4.5; # table columns in box
my $boxheight = 49*12; # points in box

for my $linegroup (keys %tables_of_line) {

    my @texts;
    my @heights;
    my @widths;
    my $specdayscol;

    foreach my $dirday ( sort { $daydirhash{$a} <=> $daydirhash{$b} } 
        keys %{$tables_of_line{$linegroup}} ) {
        push @texts , $tables_of_line{$linegroup}{$dirday}{TEXT};
        push @heights , $tables_of_line{$linegroup}{$dirday}{HEIGHT};
        push @widths , $tables_of_line{$linegroup}{$dirday}{WIDTH};
        $specdayscol = 1 if $tables_of_line{$linegroup}{$dirday}{SPECDAYSCOL};
    }

    my $size = 'small';

    given (scalar @heights) {
       when (1) {
          $size = 'big' if $heights[0] > $boxheight or $widths[0] > $boxwidth;
       }
       when (2) {

          $size = 'big' 
             unless 
                $heights[0] + $heights[1] + 18 < $boxheight and $widths[0] < $boxwidth * 2 and $widths[1] < $boxwidth * 2
                # they fit up and down
              or $widths[0] + $widths[1] < $boxwidth and $heights[0] < $boxheight and $heights[1] < $boxheight;
                # or they fit side by side
       }
       default { # TODO - figure out for larger sizes
           $size = 'big';
       }
    }

   open my $out , '>' , "tabulae/$size/$linegroup.txt" or die "Can't open tabulae/$size/$linegroup.txt: $!";
   print $out $tags{start} , join (CR , @texts);
   close $out;

}

my @texts;

my $maxwidth = 0;
my $maxheight = 0;

for my $linegroup (sortbyline keys %tables_of_line) {

    foreach my $dirday ( sort { $daydirhash{$a} <=> $daydirhash{$b} } 
        keys %{$tables_of_line{$linegroup}} ) {
        push @texts , $tables_of_line{$linegroup}{$dirday}{TEXT};
        $maxwidth  = max ($maxwidth , $tables_of_line{$linegroup}{$dirday}{WIDTH});
        $maxheight  = max ($maxheight , $tables_of_line{$linegroup}{$dirday}{HEIGHT});
    }

}

open my $out , '>' , "tabulae/all.txt" or die "Can't open tabulae/all.txt: $!";
print $out $tags{start} , join (IDTags::boxbreak , @texts);
close $out;

$maxheight = $maxheight / 72; # inches instead of points

say "Maximum height in inches: $maxheight; maximum columns: $maxwidth";

sub indesign_tags {

   my %tags;
   $tags{start} = "<ASCII-MAC>\r<Version:6><FeatureSet:InDesign-Roman><DefineParaStyle:Time=><DefineParaStyle:dropcaphead=><DefineTableStyle:TimeTable=><DefineCellStyle:ColorHeader=><DefineCharStyle:DropCapHeadDays=>";

  return %tags;

}
