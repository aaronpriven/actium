#!perl

# sts.pl - Single Timepoint Schedules

# first command-line argument is to be the directory where the files
# are stored

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

my @pickedtps = pick_timepoints();

build_outsched(@pickedtps);

output_outsched("Stop Code", "Stop Name");
