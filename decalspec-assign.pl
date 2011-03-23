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
Pten-over	19.5x35.25-P-O
Rsix-over	19.5x35.25-R-O

R10	19.5x45.75-R-R
R6	19.5x35.25-R-R

P10	19.5x35.25-P
P10R	19.5x35.25-R
P6	19.5x24.75-P

R6P  19.5x35.25-P-R
R2P  19.5x24.75-P-R

I3N	14x22-I
I3	19.5x17-I
I4N	14x26-I
I5	14x34-I
I5N	19.5x22.25-I
I9	19.5x32.75-I

C4	19.5x19.5-C
) );

# size - purchase source - master-or-oversize

my %source_for;
my %sourcenum_of;
while (<$assignments>) {
   chomp;
   my @fields = split(/\t/);
   my ($stop, $source) = @fields[0,6];
   next if (not $source) or $source eq 'SKIP';
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
