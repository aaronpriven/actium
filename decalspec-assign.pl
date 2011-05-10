#!/ActivePerl/bin/perl

use strict;
use warnings;
use 5.010;

use autodie;
use FileCache;

use Readonly;
Readonly my $FLAGDIR => '/Volumes/Bireme/Actium/db/f10/flags';
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
R10         SKIP
R6          SKIP
R2          SKIP
SKIP        SKIP

IB2         20x16-IB
IB2N        14x16-IB
IB3         19.5x17-IB
IB3N        14x22-IB
IB4N        14x26-IB
IB5         14x34-IB
IB5N        19.5x22.25-IB
IB9         19.5x32.75-IB

PBO         SKIP

IC3         SKIP
IC3N        SKIP
IC4N        SKIP
IC5         SKIP
IC5N        SKIP
IC9         SKIP

PB4         SKIP
PB6         SKIP

) );

# ignoring

#IC3         19.5x17-IB
#IC3N        14x22-IB
#IC4N        14x26-IB
#IC5         14x34-IB
#IC5N        19.5x22.25-IB
#IC9         19.5x32.75-IB

#PB4         19.5x19.5-PB
#PB6         19.5x24.75-PB


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
