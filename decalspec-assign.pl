#!/ActivePerl/bin/perl

use strict;
use warnings;
use 5.010;

use autodie;
use FileCache;

use Readonly;
Readonly my $FLAGDIR => '/Volumes/Bireme/Actium/db/f11/flags';
Readonly my $ASSIGNDIR => "$FLAGDIR/assignments";
Readonly my $ASSIGNFILE => "$FLAGDIR/assignments.txt";
Readonly my $STOPDECALFILE => "$FLAGDIR/stop-decals.txt";

open my $assignments , '<' , $ASSIGNFILE;

# first column is
# source-number-master

my %output_of_source = ( qw(
C4          SKIP
I5          SKIP
I9          SKIP
P10         SKIP
SKIP        SKIP

Field       SKIP

PBR10       SKIP
PBR6        SKIP
PBR2        SKIP
PB10        SKIP
PB15        SKIP

IC2         SKIP
IC3         SKIP
IC4N        SKIP
IC5         SKIP
IC5N        SKIP
IC9         SKIP
IC15        SKIP

CC15        28x35.25-CC
CC4         19.5x19.5-CC

PC4         SKIP
PC6         SKIP
PC15        SKIP

IB2         SKIP
IB2N        SKIP
IB3         SKIP
IB3N        SKIP
IB4N        SKIP
IB5         SKIP
IB5N        SKIP
IB9         SKIP

CB15        SKIP
CBR10       SKIP
CBR6       SKIP
CBR4       SKIP

) );



# ignoring these old sources

#PBR10       20x46.25-PB-R
#PBR6        20x35.75-PB-R
#PBR2        20x25.25-PB-R
#PB10        19.5x35.25-PB
#PB15        28x35.25-PB

#IC3         19.5x17-IC
#IC3N        14x22-IC
#IC4N        14x26-IC
#IC5         14x34-IC
#IC5N        19.5x22.25-IC
#IC9         19.5x32.75-IC

#PB4         19.5x19.5-PC
#PB6         19.5x24.75-PC

# and these new ones

#IB2         20x16-IB
#IB2N        14x16-IB
#IB3         19.5x17-IB
#IB3N        14x22-IB
#IB4N        14x26-IB
#IB5         19.5x22.25-IB
#IB5N        14x34-IB
#IB9         19.5x32.75-IB
#
#CB15        28x35.25-CB
#CBR10       19.5x45.75-CB-R
#CBR6       19.5x35.25-CB-R
#CBR4       19.5x30-CB-R

# size - purchase source - master-or-oversize

my %source_for;
my %sourcenum_of;

$_ = <$assignments>; # skip header line
 
while (<$assignments>) {
   chomp;
   my @fields = split(/\t/);
   my ($stop, $source) = @fields[0,6];
   next if (not $source);
   next if $source eq 'SKIP' ;
   next if $output_of_source{$source} eq 'SKIP';
   
   if (not $output_of_source{$source}) {
       warn "Unknown source: $source";
       next;
   }
   
   $source_for{$stop} = $source;

   next unless $source =~ /\d/;

   my $sourcenum = $source;
   $sourcenum =~ s/[^\d]//g;
   $sourcenum_of{$stop} = $sourcenum;
   
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
