# This is FPMerge.pm, a module to read (and maybe later, write) 
# the database files in "merge" format exported by FileMaker Pro.

# this is untested...

package FPMerge;

use strict;
use vars qw(@ISA @EXPORT_OK $VERSION);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(FPread FPwrite);
$VERSION = '0.00';

#use MyCSV;
use NewCSV;
use PickNewline('picknewline');

use integer; # ever so slightly faster

# FPread can build two different data structures.
# It always builds @fparray. If an index field is passed, it also
# builds %fphash.

# @fparray looks like this:
# @fparray[0..n]{$field} = "value"
# where 0..n is the number of the line in the file

# %fphash looks like this:
# %fphash{$indexfield}{$field} = "value"
# 
# If the index field isn't unique, all is not lost. The structure
# automagically changes to 
# %fphash{$indexfield}[0..n]{$field} = "value"
#
# In any case, "value" can either be a single value, or -- if 
# FileMaker has put in ASCII 29 characters, meaning it's a repeated
# field in the FileMaker database -- an array of values.

# Although this routine handles non-unique index fields and
# repeating fields, it can't handle a repeating index field.
# How would that work anyway?

sub FPread ($;$) {

   my ($file, $indexfield) = @_;
   my @fparray = ();
   my %fphash = ();


   -f $file or die "Can't find file $file";
   open CSVFILE , $file or die "Can't open $file for reading";

   my $rs = picknewline(\*CSVFILE);
   die "FPMerge Unidentified newline in $file" unless $rs;
   local ($/) = $rs;

   my $headerline = scalar <CSVFILE>;
   chomp ($headerline);
   my @fields = parse_csv($headerline);

   my $make_fphash = 0;

   if ($indexfield) {
      foreach (@fields) {
         next unless $_ eq $indexfield;
         $make_fphash = 1;
         last;
      }
      die "FPMerge: no $indexfield in $file" unless $make_fphash;
   }

   # if $indexfield is present and matches a field in the file, 
   # make the %fphash structure. Otherwise, it will just make
   # the @fparray structure.

   my %repeating=();
   my $multiple_index = 0;

    # time

   while (my $line = <CSVFILE>) {
      chomp($line);

      $line =~ s/\013/\n/g;
      # change all the vertical tabs to newlines. VT is how
      # FileMaker represents embedded newlines
      # amazingly enough s/// seems to be faster than tr///

      my $recordref = +{}; # empty anonymous hash

      my @values = parse_csv($line);

# faster than foreach @fields and shift @values
      for (my $i = 0; $i <= $#fields ; $i++) { # faster than foreach @fields an
         my $field=$fields[$i];
         my $value=$values[$i];

         ### repeating fields
         if (not ( $repeating{$field} or $value =~ /\035/) ) {
                  # if not a repeating field
            $recordref->{$field} = $value;
         } else { 
            # it is a repeating field

            unless ($repeating{$field} ) {
               # if we don't already know it's repeating, 

               die "FPMerge: Can't make hash keys from repeated field $indexfield" if $field eq $indexfield ;
               # if this is the same as the index field, die
                
               $_->{$field} = [ $_->{$field} ] foreach @fparray;
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

      push @fparray, $recordref;

      next unless $make_fphash;
      # now make the hash entry

      my $indexvalue = $recordref->{$indexfield};
      
      if (exists $fphash{$indexvalue} or ($multiple_index)) {
        # if we've seen this one before or we know indexes aren't unique,
          unless ($multiple_index) {

             print "$indexfield ($indexvalue) is not a unique field in $file\n";
             # then if this is the first we learn about non-unique indexes,

             $fphash{$_} = [ $fphash{$_} ] foreach (keys %fphash);
             # go through the whole fphash and set the value of each
             # indexfield to be a reference to an anonymous array that
             # contains one entry, the old value

             # This changes the structure from $fphash{$indexarray}{$field}... 
             # to $fphash{$indexarray}[0..n]{$field}...

             $multiple_index = 1;
             # never do this again

          }

          push @{$fphash{$indexvalue}} , $recordref;

      } else {
          # unique index
          $fphash{$indexvalue} = $recordref;
      }

   } # line

   close CSVFILE;

   return (\@fparray , \%fphash, $multiple_index) if $make_fphash;

   return \@fparray;

   # @fparray and %fphash go 
   # out of scope so the value isn't retained for next time

}
