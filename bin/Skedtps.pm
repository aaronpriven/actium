# Skedtps.pm
# vimcolor: #004400

# This is Skedtps.pm, a module to deal with the timepoint stuff.

package Skedtps;

use strict;
our (@ISA ,@EXPORT_OK ,%EXPORT_TAGS);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(tphash tpxref);
%EXPORT_TAGS = (Constants => [ qw(TPXREF_FULL TPXREF_POINT) ]);

Exporter::export_ok_tags q(Constants);

use constant TPXREF_FULL => 2;
use constant TPXREF_POINT => 1;

use FPMerge qw(FPread_simple);

our $init = 0;
our (%tphash , %tpxref);
my $tpxref;

# don't use this %tphash or %tpxref prior to "initialize"!

# %tphash = the timepoint names. $tphash{"14TH BDWY"} is 
# "Fourteenth St. & Broadway."

# %tpxref = the cross-referenced timepoint abbreviation
# $tpxref{"BDWY 14TH"} could be "14TH BDWY".

# to use something that might be "S.C. PARK=2" -- with the 
# =2 -- use the tphash and tpxref functions, not the hash itself

sub initialize { goto &init }

sub init {
   my (%timepoints, %tpnames, @timepoints, @tpnames);

   # assumes it's chdir'd to the proper directory

   $init=1;

   my $status;

   $tpxref = shift;
   $tpxref = TPXREF_POINT
       unless $tpxref == TPXREF_POINT or $tpxref == TPXREF_FULL;

   FPread_simple ('Timepoints.csv' , \@timepoints, \%timepoints, 'Abbrev9');
   FPread_simple ('TPNames.csv' , \@tpnames, \%tpnames, 'Abbrev9');

   # delete everything without punctuation

   foreach (0 .. $#timepoints) {
      delete_punctuation ($timepoints[$_]{Abbrev9} , $tpnames[$_]{Xref} )
      my $ref = $timepoints[$_]
      delete $tpnames
      $tpnames{$tpnames[$_]{Abbrev9}} = $tpnames[$_];
   } # tpnames hash


   delete_punctuation ($tpnames[$num]{Abbrev9});
      foreach my $num (0 .. $#tpnames) {

   foreach my $num (0 .. $#timepoints) {

      delete_punctuation ($timepoints[$num]{Abbrev9});

      $status = $timepoints[$num]{XrefStatus};

      my $xref = $timepoints[$num]{Xref};
      my $_ = $timepoints[$num]{Abbrev9};

      if ($tpxref == TPXREF_FULL) {
         if ($status eq 'Always') {
            $tphash{$_} = $tpnames{$xref}{Modified}; 
            $tpxref{$_} = $xref;
            # use the xref
         } else { # $status is "Never" or "Point Only"
            $tphash{$_} = $tpnames{$_}{Modified}; # use the non-xref
            $tpxref{$_} = $_;
         }
      } else { # TPXREF_POINT
         if ($status eq 'Never') {
            $tphash{$_} = $tpnames{$_}{Modified}; # use the non-xref
            $tpxref{$_} = $_;
         } else { # $status is "Always" or "Point Only"
            $tphash{$_} = $tpnames{$xref}{Modified}; # use the xref
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

1;
