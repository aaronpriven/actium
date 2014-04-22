# FPMerge.pm
# vimcolor: #401000

# This is FPMerge.pm, a module to read (and maybe later, write) 
# the database files in "merge" format exported by FileMaker Pro.

# legacy stage 2

# obsolete - replace with Actium::O::Files::FMPXMLResult

package Actium::Files::Merge::FPMerge;

use strict;
use warnings;
use vars qw(@ISA @EXPORT_OK $VERSION);

use Carp;

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(FPread FPread_simple);

use constant QUOTE => '"';

use integer; # ever so slightly faster

# FPread can build two different data structures.
# It always builds an array in the anonymous space pointed to by
# the passed $fparray reference. If an index field is passed, it also
# builds a hash pointed to by $fphash.

# fparray looks like this:
# fparray[0..n]{$field} = "value"
# where 0..n is the number of the line in the file

# fphash looks like this:
# fphash{$indexfield}{$field} = "value"
# 
# If the index field isn't unique, all is not lost. The structure
# automagically changes to 
# fphash{$indexfield}[0..n]{$field} = "value"
#
# In any case, "value" can either be a single value, or -- if 
# FileMaker has put in ASCII 29 characters, meaning it's a repeated
# field in the FileMaker database -- an array of values.

# Although this routine handles non-unique index fields and
# repeating fields, it can't handle a repeating index field.
# How would that work anyway?

# @fparray and %fphash are filled with the same references -- so you can 
# manipulate references within @fparray and the data in %fphash will be changed.

sub FPread_simple {

   push @_ , 1, 1;
   # push shortcut numbers onto FPread. These save time

   goto &FPread; 
   # pretend that FPread was called with the new @_ , see "goto" documentation

}

sub FPread {

   # $ignorerepeat will simply pass through the \035 characters
   # to the calling program.

   # $ignoredupe will pass only the last entry for each unique ID in
   # %fphash. 

   # both of these are there to speed things up; the code is quite
   # intelligent enough to not need it, but it's slower.

   my ($file, $fparray, $fphash, $indexfield, $ignorerepeat, $ignoredupe) = @_;

   @$fparray = ();

   -f $file or croak "Can't find file $file (or it's not a plain file)";
   open CSVFILE , $file or croak "Can't open $file for reading";

   local ($/) = picknewline(\*CSVFILE)
      or croak "FPMerge Unidentified newline in $file" ;

   my $headerline = scalar <CSVFILE>;
   chomp ($headerline);
   
   my @fields = split (/\,/ , $headerline);
   # The headerline has no quotes or embedded commas, 
   # so no special CSV parsing necessary

   my %fieldorder;

   {
   my $i = 0;
   $fieldorder{$_} = $i++ foreach (@fields);
   } # so now $fieldorder{$field} is the order in which they come in the file

   my $make_fphash = 0;

   if ($indexfield) {
      %$fphash = ();
      foreach (@fields) {
         next unless $_ eq $indexfield;
         $make_fphash = 1;
         last;
      }
      croak "FPMerge: no $indexfield in $file" unless $make_fphash;
   }

   # if $indexfield is present and matches a field in the file, 
   # make the %fphash structure. Otherwise, it will just make
   # the @fparray structure.

   my %repeating=();
   my $multiple_index = 0;

   LINE:
   while (my $line = <CSVFILE>) {
      chomp($line);

      $line =~ s/\013/\n/g;
      # change all the vertical tabs to newlines. VT is how
      # FileMaker represents embedded newlines
      # s/// seems to be faster than tr///

      my $recordref = {}; # empty anonymous hash

      ### beginning of old NewCSV.pm
      # This is **NOT** a generic CSV-to-list routine.
      # It is much faster than the Text:CSV on CPAN, but
      # it relies on FileMaker's promises that ALL field data
      # is in quotes, and assumes that FileMaker writes valid
      # data.

      my $quotestatus = 0; # not in quotes

      CHAR:
      for (my $i = 0 ; $i != -1 ; $i = index ($line, QUOTE , $i + 1) ) {

         substr($line,$i,1,""); # remove the quote from the line.

         # if the next character is also a quote,
         if (substr($line, $i, 1) eq QUOTE) {
            next CHAR if $quotestatus; 
            # leave it alone if we're in a quoted area.
            # FileMaker encodes " as "" inside field data.

            substr($line,$i,1,"");
            # So this is seen double quotes not inside a field area,
            # It indicates an empty field. delete the quote. 
            # The only valid next character is a comma.

         } else {
            $quotestatus = not ($quotestatus);
            # it's not a double quote, so we toggle whether 
            # we're inside a field or not.
         }

         next CHAR if $quotestatus;

         substr($line, $i, 1, "\t") unless ($quotestatus);
         # OK. We know that we've just seen either a quote that ends
         # a field. The ONLY valid next character is a comma. Change it
         # to a tab, to avoid any commas in data.

      } # CHAR

      #### end of old NewCSV.pm

      my @values = split /\t/ , $line;

      foreach my $field (@fields) {
         my $value=$values[$fieldorder{$field}];
         # $value = "" unless defined($value);
         # I don't think that's necessary and it takes up time in the loop

         ($recordref->{$field} = $value , next) if $ignorerepeat;

         ### repeating fields
         if (not ( $repeating{$field} or $value =~ /\035/) ) {
                  # if not a repeating field
            $recordref->{$field} = $value;
         } else { 
            # it is a repeating field

            unless ($repeating{$field} ) {
               # if we don't already know it's repeating, 

               croak "FPMerge: Can't make hash keys from repeated field $indexfield" if $field eq $indexfield ;
               # if this is the same as the index field, die
                
               $_->{$field} = [ $_->{$field} ] foreach @$fparray;
               # go through each record and set the new value 
               # of the appropriate field to be a reference
               # to an anonymous array that contains one entry, the old value

               # This changes the structure from 
               # ... {$field} = "value" to
               # to ...{$field}[0..n] = "value"

               # The nice thing is that because it's a reference,
               # I don't have to do the same thing for %fphash (I think)

               $repeating{$field} = 1; # never do this again
            }
            $recordref->{$field} = [ split (/\035/ , $value) ];

         }

      } # field

      push @$fparray, $recordref;

      next unless $make_fphash;
      # now make the hash entry

      my $indexvalue = $recordref->{$indexfield};

      ($fphash->{$indexvalue} = $recordref , next) if $ignoredupe;
      
      if ($multiple_index or exists $fphash->{$indexvalue} ) {
        # if we've seen this one before or we know indexes aren't unique,
          unless ($multiple_index) {
             # then if this is the first we learn about non-unique indexes,

             $fphash->{$_} = [ $fphash->{$_} ] foreach (keys %$fphash);
             # go through the whole fphash and set the value of each
             # indexfield to be a reference to an anonymous array that
             # contains one entry, the old value

             # This changes the structure from $fphash{$indexarray}{$field}... 
             # to $fphash{$indexarray}[0..n]{$field}...

             $multiple_index = 1;
             # never do this again

          }

          push @{$fphash->{$indexvalue}} , $recordref;

      } else {
          # unique index
          $fphash->{$indexvalue} = $recordref;
      }

   } # line

   close CSVFILE;

   return ($fparray, $fphash, $multiple_index) if $make_fphash;

   return ($fparray);

}

# call picknewline with a reference to the typeglob:
# picknewline (\*FH)

# Assumes lines less than 8192 bytes long, and that the choices
# are one of CRLF (typical for DOS/Windows), LF (typical for Unix), 
# or CR (typical for Mac).


sub picknewline {

    # the tell and seek stuff restores the current position of the file.
    # I actually don't know why the position would be anything other than
    # zero, but I want to be on my best behavior...

    my $fh = shift;

    my $tell = tell $fh;

    my $nl;

    seek ($fh, 0, 0);

    local $_ = "";

    read ($fh, $_, 8192);

    if (/\cM\cJ/) {
        $nl = "\cM\cJ";
        # if there's a CRLF pair, the line ending must be CRLF.
    } elsif (/\cJ/) {
        $nl = "\cJ";
        # if there's a LF but no CRLF pair, the line ending must be LF.
    } elsif (/\cM/) {
        # if there's a CR but no LF, the line ending must be CR.
        $nl = "\cM";
    } else {
        # we don't know. Could be anything. We'll set it to undef
        $nl = undef;
    }

    seek ($fh, $tell, 0);

    return $nl;
    
}

1;
