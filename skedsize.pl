#!/ActivePerl/bin/perl
# vimcolor: #001800

# skedsize

use 5.010;

# This program determines how big the schedules are

use strict;
use warnings;

@ARGV = qw(-s w07) if $ENV{RUNNING_UNDER_AFFRUS};


####################################################################
#  load libraries
####################################################################

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Skedfile qw(Skedread );
use Actium::Sorting::Line ('sortbyline');
use List::Util;

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################


use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::Folders::Signup;
my $signupdir = Actium::Folders::Signup->new();
chdir $signupdir->get_dir();
my $signup = $signupdir->get_signup;

printq "skedsize - how big are the schedules\n\n" ;

printq "Using signup $signup\n" ;

open my $out , '>skedsizes.txt' or die "$!";

select $out;

my @skeds = sort glob "skeds/*.txt";

my %instances_of;

foreach my $file (@skeds) {

   my $name = $file;

   $name =~ s#skeds/##;
   $name =~ s#.txt##;

   my $skedref = Skedread($file);
   my $tps = scalar @{$skedref->{TP}};
   my $trips = scalar @{$skedref->{ROUTES}};
   
   my $height = 1.5 + ($trips / 8);
   my $width = $tps * .5;

   my $linegroup = $skedref->{LINEGROUP};
   push @{$instances_of{$linegroup}} ,  
     { TPS => $tps , TRIPS => $trips , H => $height , W => $width };

   #print "$name:$tps:$lines\n";

}

say join ("\t" , 
    qw< Line NumScheds 1Col 2Col 3Col 4Col 
        AnyFit? TP_x_Trips W_x_H > );

foreach my $line (sortbyline keys %instances_of) {

   my @instances =
           sort { $b->{H} <=> $a->{H} } @{$instances_of{$line}};
   # sorted by length, longest to shortest

   my @sizes = build_sizes (@instances);
   
   my @toprint = ( $line , scalar @instances );

   my $anyfit = 0;

   for my $num_columns (1 .. 4) {
      if ($sizes[$num_columns]) {
         push @toprint , $sizes[$num_columns]{W} . " x " . $sizes[$num_columns]{H};
         $anyfit = 1 if it_fits ($sizes[$num_columns]{W} , $sizes[$num_columns]{H});
      } else {
         push @toprint , '--';
      }
   }

   push @toprint , $anyfit ? "Y" : "N" ;

   my @tpxtrips;
   push @tpxtrips , $_->{TPS} . ' x ' . $_->{TRIPS}
       foreach @instances;
   push @toprint , join (" : "  , @tpxtrips);
   

   my @wxhs;
   push @wxhs , $_->{W} . ' x ' . $_->{H}
       foreach @instances;
   push @toprint , join (" : "  , @wxhs);

   say join ("\t" , @toprint);

}

sub build_sizes {

   my @instances = @_;

   my @sizes = [];

   foreach my $num_columns ( 1 .. 4 ) {

      next if $#instances < ($num_columns - 1);
      next if $num_columns == 3 and ( scalar (@instances) % $num_columns );

      my $last_row = int ($#instances / $num_columns) ;

      my @maxh;
      my @maxw;

      foreach my $i ( 0 .. $#instances) {

          my $col = $i % $num_columns;
          my $row = int ( $i / $num_columns );

          my $h = $instances[$i]{H};
          my $w = $instances[$i]{W};

          no warnings 'uninitialized';

          $maxh[$row] = $h if $maxh[$row] < $h;
          $maxw[$col] = $w if $maxw[$col] < $h;

      }

      my $total_h = List::Util::sum (0, @maxh) + (.33 * $last_row);
      my $total_w = List::Util::sum (0, @maxw) + (.33 * ( $num_columns - 1) ) ;

      $sizes[$num_columns] = { H => $total_h , W => $total_w };
      
   }

   return @sizes;

}

sub it_fits {

    my $panelwidth = (2/3 * 11 - .5);
    my $panelheight = 8;

    my ($h, $w) = @_;

    return 1 if ($w <= $panelwidth and $h <= $panelheight); # landscape
    return 1 if ($h <= $panelwidth and $w <= $panelheight); # portrait
    return 0;
   
}
      

__END__

   my $num_instances = scalar(@instances);



   print "$_\t$num_instances\t" ;

   my $total_height = 0;
   my $max_width  = 0;

   my $instances_text = '';

   foreach my $instance (@instances) {
      my ($columns, $lines, $height, $width) = @{$instance};
      $instances_text .= qq{\t$columns x $lines;$height" x $width"};
      $total_height += $height;
      $max_width = $width if $width > $max_width;
   }




   print "$_\t$num_instances\t" ;

  print qq{$total_height" x $max_width"};
  print "\t" , ( ( $total_height < 10.5 and $max_width < 7) ? 'Y' : 'N') ;
  say $instances_text;
   
}
