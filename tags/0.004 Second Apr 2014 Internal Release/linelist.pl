#!/ActivePerl/bin/perl

# linelist
#
# List lines in order by name
# 

use 5.010;

use strict;
use warnings;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::Sorting::Line (qw(sortbyline));
use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);
use Actium::Term (':all');

use Actium::Options (qw<option init_options add_option>);

add_option ('1' , 'One-column output');

init_options();

use Actium::O::Folders::Signup;
my $signupdir = Actium::O::Folders::Signup->new();
chdir $signupdir->path();

my $signup = $signupdir->signup;

# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.

# open and load files

our (@idx, %idx);

FPread_simple ("Skedidx.csv" , \@idx, \%idx, 'SkedID');

my %seen;
foreach my $idx (@idx) {
   my @lines = split ("\c]" , $idx->{Lines});
   foreach (@lines) {
      if (defined($_) and $_ ne '') {
      $seen{$_} = 1;
      
#      } else {
#          say "Bad lines: @lines";
      }
   }
}

my @lines = sortbyline keys %seen;

#say join("\n" , @lines);

if (option('1')) {
   print join("\n" , @lines) , "\n";
} 
else {
   print_in_columns ({PADDING => 5} , @lines);
}
