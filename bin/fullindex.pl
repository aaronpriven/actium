#!/usr/bin/perl
# vimcolor: #001800

# fullindex

# This program regenerates the index files from the files in /skeds

use strict;
use warnings;

@ARGV = qw(-s w07) if $ENV{RUNNING_UNDER_AFFRUS};


####################################################################
#  load libraries
####################################################################

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Skedfile qw(Skedread Skedwrite trim_sked copy_sked remove_blank_columns);
use Myopts;
use Skeddir;
use Storable;
use Algorithm::Diff;
use Byroutes 'byroutes';

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

our (%options);    # command line options
my  (%index);      # data for the index
 
Myopts::options (\%options, Skeddir::options(), 'effectivedate:s' , 'quiet!');
# command line options in %options;

$| = 1; 
# don't buffer terminal output

print "fullindex - generate index files\n\n" unless $options{quiet};

my $signup;
$signup = (Skeddir::change (\%options))[2];
print "Using signup $signup\n" unless $options{quiet};
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.


my @skeds = sort glob "skeds/*.txt";

my $displaycolumns = 0;

my $prevlinegroup = "";
foreach my $file (@skeds) {
   next if $file =~ m/=/; # skip file if it has a = in it

   unless ($options{quiet}) {
      my $linegroup = $file;
      $linegroup =~ s#^skeds/##;
      $linegroup =~ s/_.*//;

      unless ($linegroup eq $prevlinegroup) {
         $displaycolumns += length($linegroup) + 1;
         if ($displaycolumns > 70) {
            $displaycolumns = 0;
            print "\n";
         }
         $prevlinegroup = $linegroup;
         print "$linegroup ";
      }
   
   }

   my $dataref = Skedread($file);

   $index{$dataref->{SKEDNAME}} = skedidx_line ($dataref);

}

open IDX, ">Skedidx.txt" or die "Can't open $signup/skedidx.txt";
print IDX "SkedID\tTimetable\tLines\tDay\tDir\tTP9s\tNoteLetters\n";

my %num_of;

foreach (values %index) {
   m/(^\d+)/;
   $num_of{$_} = $1 || 1000;
}

print IDX join("\n" , sort {$num_of{$a} <=> $num_of{$b} or $a cmp $b} values %index) , "\n" ;
close IDX;

open TPS, ">Skedtps.txt" or die "Can't open $signup/skedtps.txt";
foreach ( sort {$num_of{$a} <=> $num_of{$b} or $a cmp $b} values %index) {
   my @values = split (/\t/, $_) ;
   my $skedid = $values[0];
   my @tps = split (/\035/, $values[5]);
   for (my $i = 0; $i < scalar(@tps); $i++) {
      print TPS join ("\t" , $skedid , $i , $tps[$i]) , "\n";
   }
}
close TPS;

print <<"EOF" unless $options{quiet};


Indexes $signup/Skedidx.txt and $signup/Skedtps.txt written.
Remember to import it into FileMaker or the databases won't work properly.
EOF

######################################################################
#### end of main
######################################################################



sub skedidx_line {

   my $dataref = shift;

   my @indexline = ();

   my %seen = ();
   my @routes = sort byroutes grep {! $seen{$_}++}  @{$dataref->{ROUTES}};
   %seen = ();
   my @notes = sort grep {$_ and ! $seen{$_}++}  @{$dataref->{NOTES}};

   push @indexline, $dataref->{SKEDNAME};
   push @indexline, $dataref->{LINEGROUP};
   push @indexline, join("\035" , @routes);
   # \035 says "this is a repeating field" to FileMaker
   push @indexline, $dataref->{DAY};
   push @indexline, $dataref->{DIR};

   my @tps = ($dataref->{TP}[0]);
   for (1 .. $#{$dataref->{TP}}) {
      my @thesetps;
      for (@thesetps = @{$dataref->{TP}}[$_-1,$_] ) {s/=\d+$//};
      push @tps , $dataref->{TP}[$_] 
            if $thesetps[0] ne $thesetps[1];
   } # drop out duplicate arrival/departure timepoints (like merge_columns)

   push @indexline, join("\035" , @tps);

   push @indexline, join ("\035" , @notes);

   return join("\t" , @indexline);

}

__END__

sub add_duplicate_tp_markers {

   my $dataref = shift;

   my %seen = ();
   foreach (@{$dataref->{"TP"}}) {
      $_ .= "=" . $seen{$_} if $seen{$_}++;
   }
      # If there's a duplicate timepoint, 
      # it now has a "=" and number (usually "2") appended to it

   return $dataref;

} 

##### added 11/03 ####

sub stripblanks {

   my @ary = @_;
   foreach (@ary) {
     s/^\s+//;
     s/\s+$//;
   }

   return wantarray ? @ary : $ary[0];

}


sub byskednamenum {

   (my $aa = $a) =~ s/.*=//;
   (my $bb = $b) =~ s/.*=//;
   return $aa <=> $bb;

}

sub writeeffectivedate {

my $effectivedate = $_[0];

open OUT , ">effectivedate.txt" 
    or die "Can't open effectivedate.txt for output";
print OUT $effectivedate ;
close OUT;

}

