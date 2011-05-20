#!/ActivePerl/bin/perl

use strict;
use 5.012;

use FindBin qw($Bin);
use lib $Bin;

use Actium::Sked;

my $object
  = Actium::Sked->new_from_prehistoric('/b/Actium/db/f10/skeds/31_SB_WD.txt')
  ;
 
use Data::Dumper;

say Dumper(\$object); 