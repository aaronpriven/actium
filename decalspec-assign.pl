#!/ActivePerl/bin/perl

use strict;
use warnings;
use 5.010;

use autodie;
use FileCache;

use Readonly;
Readonly my $FLAGDIR => '/Volumes/Bireme/Actium/db/f12/flags';
Readonly my $ASSIGNDIR => "$FLAGDIR/assignments";
Readonly my $ASSIGNFILE => "$FLAGDIR/assignments-f12.txt";
Readonly my $STOPDECALFILE => "$FLAGDIR/stop-decals.txt";

open my $assignments , '<' , $ASSIGNFILE;

# first column is
# source-number-master

my %output_of_source = ( qw(

R-J-3     19.5x17-RJ
R-J-4N    14x26-RJ
R-J-5N    14x34-RJ
R-J-3N    14x22-RJ
R-J-5     19.5x22.25-RJ


) );

#F-F12-2  F-F12
#F-F12-3  F-F12
#F-F12-4  F-F12
#F-F12-5  F-F12

#R-G2-3   19.5x17-RG2
#R-G2-4N  14x26-RG2
#R-G2-5N  14x34-RG2

#R-E-9 19.5x32.75-R


#C-E-10 19.5x35.25-CE
#C-E-10R 19.5x45.75-CE-R
#C-E-4 19.5x19.5-CE
#C-E-6 19.5x24.75-CE
#C-E-6R 19.5x35.25-CE-R
#C-E-7W 28x19.5-CE

my %source_for;
my %sourcenum_of;

{ 
 
local ($/) = "\r";

$_ = <$assignments>; # skip header line
 
while (<$assignments>) {
   chomp;
   my @fields = split(/\t/);
   my ($stop, $source) = @fields[0,6];
   next if (not $source);
   next if $source eq 'SKIP' ;
   next unless exists $output_of_source{$source};
   next if $output_of_source{$source} eq 'SKIP';
   
   #if (not $output_of_source{$source}) {
   #    warn "Unknown source: $source";
   #    next;
   #}
   
   $source_for{$stop} = $source;

   next unless $source =~ /\d/;

   my $sourcenum = $source;
   $sourcenum =~ s/[^\d]//g;
   $sourcenum_of{$stop} = $sourcenum;
   
}

}

close $assignments;

mkdir $ASSIGNDIR unless -e $ASSIGNDIR;

open my $stop_decals , '<' , $STOPDECALFILE;

my $overcount = 0;
while (<$stop_decals>) {
   my $stop = $_;
   $stop =~ s/\t.*//sx;

   my @fields = split(/\t/);
   my $boxes = @fields - 2;

   if ($sourcenum_of{$stop} and 
      ( $sourcenum_of{$stop} < $boxes  ) ) {
      print "$source_for{$stop}\t$boxes\t$_";
   }

   {
   no strict 'refs';
   my $source = $source_for{$stop};
   next unless $source;
   my $sourcefile = $ASSIGNDIR . '/' . $output_of_source{$source};
   my $fh = cacheout $sourcefile;
   print $fh $_;
   }
}

say $overcount;

close $stop_decals;
