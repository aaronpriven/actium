#!/ActivePerl/bin/perl
# vimcolor: #001800

# fullindex

# This program regenerates the index files from the files in /skeds

our $VERSION = 0.002;

use strict;
use warnings;

####################################################################
#  load libraries
####################################################################

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

{
    no warnings('once');
    ## no critic (RequireExplicitInclusion, RequireLocalizedPunctuationVars)
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
    ## use critic
    }
}

use Skedfile qw(Skedread Skedwrite trim_sked copy_sked remove_blank_columns);
use Storable;
use Algorithm::Diff;
use Actium::Sorting::Line (qw(sortbyline));

use Actium::Options (qw<option add_option init_options>);

add_option ('effectivedate:s' , 'Effective date of signup');

use Actium::Term (qw<printq sayq>);
use Actium::O::Folders::Signup;

init_options;

my $signupdir = Actium::O::Folders::Signup->new();
chdir $signupdir->path();

my $signup = $signupdir->signup;

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

my  (%index);      # data for the index
 

$| = 1; 
# don't buffer terminal output

printq "fullindex - generate index files\n\n" ;

printq "Using signup $signup\n";
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.


my @skeds = sort glob "skeds/*.txt";

my $displaycolumns = 0;

my $prevlinegroup = "";
foreach my $file (@skeds) {
   next if $file =~ m/=/; # skip file if it has a = in it

   unless (option('quiet')) {
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

printq <<"EOF" ;


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
   my @routes = sortbyline grep {! $seen{$_}++}  @{$dataref->{ROUTES}};
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
   
   if (not defined $tps[0]) {
      print "not defined!\n";
   }

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

