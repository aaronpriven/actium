#!/bin/perl

require 'pubinflib.pl';

($in, $out) = @ARGV;

open IN, $in;
open OUT, ">$out";

my @ary = <IN>;
# slurp

print OUT sort byroutes @ary;
