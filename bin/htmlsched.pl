#!perl

require 'pubinflib.pl';

# someday I'm going to have to learn how to write modules

use strict;

chdir &get_directory or die "Can't change to specified directory.\n";

# so we cd to the appropriate directory

shift @ARGV; # $ARGV[0] is still the directory

scalar (@ARGV) or die "Usage: $0 <directory> <files>\n";

unless (-d "html") {

   mkdir "html" or die "Can't make html directory\n";

}

our %fullsched;

foreach my $file (@ARGV) {

   read_fullsched($file,2,".acs");

   foreach my $day_dir (keys %fullsched) {

      open HTML , ">html/$file-$day_dir.html";

      print HTML "<html><head><title>Line $file Days $day_dir</title></head>\n";
      print HTML "<body><h1>Line $file Days $day_dir</h1>\n<pre>\n";
      
      foreach my $row ( 0 .. scalar (@{$fullsched{$day_dir}{ROUTES}})) {

         output_heads($day_dir) unless ($row % 25);

         print HTML "\n" unless ($row % 5);

         printf HTML "%3s  " , $fullsched{$day_dir}{ROUTES}[$row];

         foreach my $col ( 0 .. scalar (@{$fullsched{$day_dir}{TP}})) {
  
            my $time = $fullsched{$day_dir}{TIMES}[$col][$row];

            unless ($time) {

               print HTML "       ";
               next;

            }

            my $ampm = chop $time;

#           substr($time, -2, 0) = ":" if $time;
   
            printf HTML "%4s%1s  " , $time, $ampm;

         }

         print HTML "\n";

      }

      print HTML "\n</pre></body></html>";
      close HTML ;

   }

}

sub output_heads {

   my $day_dir = shift;

   our %fullsched;

   print HTML "\n<hr>";

   my ($firstline) = "RTE  ";
   my ($secondline) = "NUM  ";

#   foreach my $tp ( 0 .. scalar (@{$fullsched{$day_dir}{TP}})) {
    foreach my $tp ( @{$fullsched{$day_dir}{TP}}) {

      my @tps = split (/\s+/ , $tp);
      $firstline .= sprintf("%5s  " , $tps[0]);
      $secondline .= sprintf("%5s  " , $tps[1]);

   }

   print HTML "$firstline\n$secondline\n";

}
