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

use MyCSV;
use PickNewline('picknewline');

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
   print "FPMerge: f: $file , i: $indexfield\n";
   my @fparray = ();
   my %fphash = ();


   -f $file or die "Can't find file $file";
   open CSVFILE , $file or die "Can't open $file for reading";

   my $rs = picknewline(\*CSVFILE);
   die "FPMerge Unidentified newline in $file" unless $rs;
   local ($/) = $rs;

   my $csv = MyCSV->new;

   $csv->parse(scalar(<CSVFILE>)) 
     or die "Parse failed reading headers: ", $csv->error_input;

   my @fields = $csv->fields();

   my $make_fphash = 0;
   foreach (@fields) {
      next unless $_ eq $indexfield;
      $make_fphash = 1;
      last;
   }

   # if $indexfield is present and matches a field in the file, 
   # make the %fphash structure. Otherwise, it will just make
   # the @fparray structure.

   die "FPMerge: no $indexfield in $file."
      if $indexfield and not $make_fphash;

   my %repeating=();
   my $unique_index = 1;

    # time

   while (my $line = <CSVFILE>) {
      chomp($line);

      $line =~ s/\013/\n/g;
      # change all the vertical tabs to newlines. VT is how
      # FileMaker represents embedded newlines

      # amazingly enough s/// seems to be faster than tr///

      my %record = ();

      $csv->parse($line)
        or die "Parse failed reading values: ", $csv->error_input;

      my @values = $csv->fields();

      foreach my $field (@fields) {
         # go through all the fields in order and
         my $value = shift @values;
         # get the appropriate value.

         ### repeating fields
         if (not ( $repeating{$field} or $value =~ /\035/) ) {
                  # if not a repeating field
            $record{$field} = $value;
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
               # I don't have to do the same thing for %fphash

               $repeating{$field} = 1; # never do this again
            }
            $record{$field} = [ split (/\035/ , $value) ];
            # now $record 
         }

      } # field

      my $recordref = { %record };
      # copy the hash out of %record to a new anonymous hash
      push @fparray, $recordref;

      next unless $make_fphash;
      # now make the hash entry
      
      if ($fphash{$record{$indexfield}} or (not $unique_index)) {
        # if we've seen this one before or we know indexes aren't unique,
          if ($unique_index) {
             # then if this is the first we learn about non-unique indexes,

             $fphash{$_} = [ $fphash{$_} ] foreach (keys %fphash);
             # go through the whole fphash and set the value of each
             # indexfield to be a reference to an anonymous array that
             # contains one entry, the old value

             # This changes the structure from $fphash{$indexarray}{$field}... 
             # to $fphash{$indexarray}[0..n]{$field}...

             $unique_index = 0;
             # never do this again

          }

          push @{$fphash{$record{$indexfield}}} , $recordref;

      } else {
          # unique index
          $fphash{$record{$indexfield}} = $recordref;
      }

   } # line

   close CSVFILE;

   return (\@fparray , \%fphash, $unique_index) if $make_fphash;

   return \@fparray;

   # @fparray and %fphash go 
   # out of scope so the value isn't retained for next time

}

__END__

I haven't made FPWrite work with the current data structure. It uses the 
now-obsolete $data{$field}[0..n] structure. It could be fixed.

sub FPwrite ($$) {

# call FPwrite as FPMerge::FPwrite($filename, \%data)

   my $file = shift;
   my %data = %{shift()};
   # perl thinks %{shift} is the variable %shift.
   # vim thinks %{shift} is a function call. Interesting.

   my $csv = MyCSV->new;

   my @fields = keys %data;

   # the only real reason to do this is to ensure that the order is
   # always the same. At some point I may write this so it specifies an
   # order.
   
   open CSVFILE, ">$file" or die "Can't open $file for writing";

   print CSVFILE join("," , @fields)  , "\n";

   # This uses the system default newline. I hope, anyway, that FileMaker
   # will recognize it.

   my $max = 0;

   foreach (@fields) {
      my $thislength = @{$data{$_}};
      next if $thislength >= $max;
      $max = $thislength;
   }

   my @values;
   foreach my $count (0 .. $max) { # the big .. array is optimized away, yay
      @values = ();
      foreach my $field (@fields) {
          my $value = $data{$field}[$count];
          if (ref ($value)) {
             $value = join("\013" , @$value);
          }
          push @values, $value;
      }

      $csv->combine(@values) 
        or die "Combine failed with values: ", $csv->error_input;

      print CSVFILE $csv->string();

   }

close CSVFILE;
   
}

1;
