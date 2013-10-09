#!/ActivePerl/bin/perl

use 5.016;
use Actium::Preamble;

say jt(qw/a b c/);

use List::MoreUtils('true');

say true {$_ == 0 } (1,1,0,0,1);

