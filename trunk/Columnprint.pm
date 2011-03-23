# Columnprint.pm

use strict;
use warnings;
use 5.010;

package Columnprint;

use Exporter qw(import);
our @EXPORT_OK = 'columnprint';
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use List::Util qw(max);
use POSIX qw(ceil floor);
use Scalar::Util qw(reftype);

sub columnprint {

   my $screenwidth = 80;
   my $padding = 1;

   if (reftype($_[0]) eq 'HASH' ) {
      my %args = %{+shift};
      $screenwidth = $args{SCREENWIDTH} || $screenwidth ;
      $padding = $args{PADDING} || $padding;
   }

   my $return = '';

   my @list = @_;
   my $colwidth = $padding + max map { length } @list;
   @list = map { sprintf ("%*s" , - ( $colwidth ),  $_) } @list;

   my $cols = floor($screenwidth / ($colwidth)) || 1;
   my $rows = ceil(@list / $cols);

   push @list , (" " x $colwidth) x ($cols*$rows - @list);

   for my $y ( 0 .. $rows - 1 ) {
      for my $x (0 .. $cols - 1) {
         $return .= $list[$x * $rows + $y ] ;
      }
      $return .= "\n";
   }

   return $return;
      
}
