#!/usr/bin/perl -pi -0777

s/\cM/\cJ/g;
s/\s+\cJ/\cJ/g;

$_ .= "\cJ" unless substr ($_ , -1, 1) eq "\cJ";
