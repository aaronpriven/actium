#!perl

$e = $ENV{PATH};

$e =~ s/Z:.//;
$e =~ s/;;//;
$e =~ s/;$//;
open OUT , ">/temp/mypath.cmd";
print OUT  "PATH $e\n";
close OUT;
