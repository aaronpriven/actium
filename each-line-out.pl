#!/ActivePerl/bin/perl

use warnings;
use 5.014;
use File::Copy;

my @files = glob ('*.pdf');

my $folder = 'output';

if (! -d $folder) {
   mkdir $folder or die "Can't create $folder";
}

foreach my $file (@files) {

   my @lines = split (/[-_]/ , $file);
   s/\.pdf$// foreach @lines;
   #my $tail = pop @lines;
   
   #my @newfiles = map { "output/${_}_$tail"} @lines;
   my @newfiles = map { "output/${_}_timetable.pdf"} @lines;

   foreach my $newfile (@newfiles) {
   say "copy $file , $newfile";
   copy $file , $newfile;
   }

}
