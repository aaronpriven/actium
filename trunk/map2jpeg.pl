#!/ActivePerl/bin/perl

use 5.012;
use warnings;

my $gsargs = '-sDEVICE=jpeg -dGraphicsAlphaBits=4 -dTextAlphaBits=4';

#my $resolution = 200;

my %percent_of = ( 288 => '100pct' ,
                   144 => '50pct' ,
                   72  => '25pct' ,
                   36 => '12.5pct',
                  );

foreach (@ARGV) {

   my $line = $_;

   $line =~ s/-.*//;
   $line =~ s/_/,/g;

   foreach my $resolution (sort { $a <=> $b } keys %percent_of) {
      my $percent = $percent_of{$resolution};

      say "\n$_ -> ${line}_$percent.jpg at $resolution ppi\n";
      system "gs -r$resolution $gsargs -o ${line}_$percent.jpg $_";
   }

}
