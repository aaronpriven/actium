require 'pubinflib.pl';

# someday I'm going to have to learn how to write modules

use strict;

chdir &get_directory or die "Can't change to specified directory.\n";

# so we cd to the appropriate directory

shift @ARGV; # $ARGV[0] is still the directory

open INDEX , ">tempindex.txt" or die "can't open tempindex: $!";

our $fullsched;

foreach (@ARGV) {

   read_fullsched($_,2,".sls");
   # 2 says not to cross-reference any timepoints here

   output_index ($_);

}

