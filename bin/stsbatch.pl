#!perl

# stsbatch.pl - Single Timepoint Schedules, batch mode

# first command-line argument is to be the directory where the files
# are stored

# second command-line argument, if present, is the file it is to use. 
# otherwise it uses "stsbatch.txt" in the same directory the file is
# stored in.

# -----------------------------------------------------------------
# ---- MAIN
# -----------------------------------------------------------------

use strict;

# use warnings;

require 'pubinflib.pl';

init_vars();

chdir get_directory() or die "Can't change to specified directory.\n";

build_tphash();

get_lines();

$/ = "\n---\n";

my ($stop, $stopcode, $stopdescription, @pickedtps);

open BATCH, ($ARGV[1] || "stsbatch.txt") or die "Can't open batch file";

while (<BATCH>) {

   chomp;
   ($stop, @pickedtps) = split (/\n/);
#  print (join "\n" , @pickedtps);
   ($stopcode, $stopdescription) = split ("\t" , $stop, 2);
   build_outsched (@pickedtps);
   output_outsched($stopcode, $stopdescription);

}

close BATCH;
