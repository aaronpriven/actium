#!/ActivePerl/bin/perl

# Test the Actium::Time module

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

# Subversion: $Id$

use 5.010;

use warnings;
use strict;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

# add the current program directory to list of files to include
use FindBin qw($Bin);
use lib $Bin;

use Actium::Time (qw(timenum timestr timestr_sub));

say Actium::Time::timenum ('0945a');

say join("\t" , timenum qw(-1015 2638 114 12:15a 1:15x 4:45b 3:00p));

say join("\t" , timestr(15,-1,1000, 1441 , XB => 1  ));

