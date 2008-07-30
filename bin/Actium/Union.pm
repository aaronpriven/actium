#!/usr/bin/perl

use warnings;
use strict;

use Carp;

package Actium::Union;

use Algorithm::Diff;

use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw(ordered_union ordered_union_pair);

sub ordered_union {
   my @array_rs = @_;
   
   # return the first array if there's only one array
   return $array_rs[0] if $#array_rs == 0;
   
   @array_rs = reverse sort { @{$a} <=> @{$b} or "@{$a}" cmp "@{$b}" } @array_rs;

   my $union_r = shift @array_rs;
   foreach my $array_r (@array_rs) {
      $union_r = ordered_union_pair ($union_r, $array_r);
   }

   return $union_r;
   
}

sub ordered_union_pair {
   # usage: @union = @{ ordered_union_pair (\@a, \@b) };
   # accepts two array refs. Returns reference to the union of the 
   # two arrays, preserving their order as best determined by 
   # Algorithm::Diff.
   
   # in a sequence like (a, b, d) and (a, c, d), will return
   # entries in alphabetical order (a, b, c, d).
   
   # arguably using something that knew where the actual stops were and
   # picking the closest one might be the best thing. Or maybe not.
   
   my @union;
   
   unless (ref($_[0]) and ref($_[1])) {
      croak("Non-reference arguments to ordered_union");
   }
   
   foreach my $component ( Algorithm::Diff::sdiff ($_[0], $_[1]) ) {
   
      my ($action, $a_elem, $b_elem) = @$component;
      
      # in order of my expectation of frequency
      push @union, (   $action eq 'u' ? ( $a_elem )
                     : $action eq '+' ? ( $b_elem ) 
                     : $action eq '-' ? ( $a_elem )
                     : (sort ( $a_elem , $b_elem )) # $action eq "c"
                   );
      
   }

   return \@union;
}

1;
