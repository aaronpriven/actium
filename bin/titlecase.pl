
$_ = join (" " , @ARGV);

chomp;

s/\b(\w+)/\u\L$1/g;

print $_ , "\n";

