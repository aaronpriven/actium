# Skedtps.pm
# vimcolor: #004400

# This is Skedtps.pm, a module to deal with the timepoint stuff.

package Skedtps;

use strict;
our (@ISA ,@EXPORT_OK ,%EXPORT_TAGS);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(tphash tpxref %timepoints @timepoints destination );
%EXPORT_TAGS = (Constants => [ qw(TPXREF_FULL TPXREF_POINT) ]);

Exporter::export_ok_tags q(Constants);

use constant TPXREF_FULL => 2;
use constant TPXREF_POINT => 1;

use Actium::Files::Merge::FPMerge qw(FPread_simple);

our $init = 0;
our (%tphash , %tpxref);
my $tpxref;

our (%timepoints, @timepoints );

# tphash = the timepoint names. tphash("14TH BDWY") is 
# "Fourteenth St. & Broadway."

# tpxref = the cross-referenced timepoint abbreviation
# tpxref("BDWY 14TH") could be "14TH BDWY".

# tpxref and tphash subroutines strip punctuation.. the only characters
# used to determine the different timepoint names are [A-Za-z0-9= ]
# (note space) (but actually a trailing =[0-9] are stripped too)

# This is mainly to deal with a FileMaker quirk: it thinks "C.V. PKRD"
# is the same as "C,V, PKRD" and "DEJE M.S" the same as "DEJE M.S."
# so won't let you enter the second ones if the first ones are already there
# (in fields marked "unique")  Which is a good thing I guess. But requires
# this code to deal with it.


sub initialize { goto &init }

sub init {
   our (%timepoints, @timepoints );

   # assumes it's chdir'd to the proper directory

   $init=1;

   my $status;

   $tpxref = shift;
   $tpxref = TPXREF_POINT
       unless $tpxref == TPXREF_POINT or $tpxref == TPXREF_FULL;

   FPread_simple ('Timepoints.csv' , \@timepoints, \%timepoints, 'Abbrev9');

   # delete everything without punctuation

   foreach (0 .. $#timepoints) {
      delete $timepoints{$timepoints[$_]{Abbrev9}};
         # delete version with punct. from hash
      delete_punctuation ($timepoints[$_]{Abbrev9} , $timepoints[$_]{Xref} );
      $timepoints{$timepoints[$_]{Abbrev9}} = $timepoints[$_];
         # add version without punct. from 
         # %timepoints hash - replaces it from @timepoints array
   } # timepoints hash

   foreach (keys %timepoints) {

      $status = $timepoints{$_}{XrefStatus};

      my $xref = $timepoints{$_}{Xref};

      # It might be easier to use the exported names from the
      # FileMaker self-join, but for whatever reason, I didn't.

      if ($tpxref == TPXREF_FULL) {
         if ($status eq 'Always') {
            $tphash{$_} = $timepoints{$xref}{TPName}; 
            $tpxref{$_} = $xref;
            # use the xref
         } else { # $status is "Never" or "Point Only"
            $tphash{$_} = $timepoints{$_}{TPName}; # use the non-xref
            $tpxref{$_} = $_;
         }
      } else { # TPXREF_POINT
         if ($status eq 'Never') {
            $tphash{$_} = $timepoints{$_}{TPName}; # use the non-xref
            $tpxref{$_} = $_;
         } else { # $status is "Always" or "Point Only"
            $tphash{$_} = $timepoints{$xref}{TPName}; # use the xref
            $tpxref{$_} = $xref;
         }
      } 

   }  

   return scalar keys %tphash;

}

sub tphash {
  init() unless $init;
  local $_ = shift;
  delete_punctuation($_);
  s/=\d+$//;
  return $tphash{$_};
}

sub tpxref {
  init() unless $init;
  local $_ = shift;
  delete_punctuation($_);
  s/=\d+$//;
  return $tpxref{$_};
}

sub delete_punctuation {
   foreach (@_) {
      tr/[A-Za-z0-9= ]//cd;
   }
}

sub destination {
   init() unless $init;
   my @destinations;
   foreach (@_) {
      delete_punctuation($_);
      s/=\d+$//;
      push @destinations , $timepoints{$_}{DestinationF};
   }

   return wantarray ? @destinations : $destinations[0];

}

1;
