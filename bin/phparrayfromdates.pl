#!/ActivePerl/bin/perl

use 5.012;
use warnings;
use autodie;

use Byroutes 'byroutes';

my $dir = '/Volumes/Bireme/Online projects/timetable dates';

open my $in, '<' , "$dir/dates.tab";

my (%timetables);

while (<$in>) {
   chomp;

   my ($line, $date) = split(/\t/);
   $line =~ s/\s+\z//;
   $line =~ s/\A\s+//;

   $date =~ s/"//g;

   my $text = sprintf("%-3s" , $line) . " (last updated: $date)";
   my $type;
  
   given ($line) {
      when (/6\d\d+/) {
         $type = 'school';
      }
      when (/8\d\d+/) {
         $type = 'allnight';
      }
      when (/^[[:alpha:]]/) {
         $type = 'trans';
      }
      default {
         $type = 'local';
      }
   }
   $timetables{"${type}_arr"}{$line} = $text;

}

close $in;

open my $out , '>' , "$dir/timetable_arrays.php";

foreach my $type (keys %timetables) {
    print $out "\t" x 8 , '$' , "$type = Array(";

       foreach my $line (sort byroutes keys %{$timetables{$type}}) {
          print $out qq{"$timetables{$type}{$line}", };
       }

    print $out ");\r\n";

}

close $out;
