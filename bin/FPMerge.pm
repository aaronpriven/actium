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

# The data format looks like this:

# %data{field}[0..x] = "value" 
# repeating fields are
# %data{field}[0..x][0..x] = "value"

use MyCSV;
use PickNewline('picknewline');

sub FPread ($) {

   my $file = shift;
#   my %indexfield = shift;
   my %data = ();

   open CSVFILE , $file or die "Can't open $file for reading.";

   my $rs = picknewline(\*CSVFILE);
   die "Unidentified newline in $file" unless $rs;
   local ($/) = $rs;

   my $csv = MyCSV->new;

   $csv->parse(<CSVFILE>) 
     or die "Parse failed reading headers: ", $csv->error_input;

   my @fields = $csv->fields();

   my %repeating=();

   while (my $line = <CSVFILE>) {
      chomp($line);

      $csv->parse(<CSVFILE>) 
        or die "Parse failed reading values: ", $csv->error_input;
      my @values = $csv->fields();

      foreach my $field (@fields) {
         my $value = shift @values;
         $value =~ s/\013/\n/g;
         # this changes all the vertical tabs to newlines


         ### repeating fields

         if (not ( $repeating{$field} or $value =~ /\035/) ) {
                  # if not a repeating field
            push @{$data{$field}} , $value;
         } else { # else it is a repeating field

            if (not ($repeating{$field} )) {
               # if we don't already know it's repeating, 
               $_ = [ $_ ] foreach (@{$data{$field}}) ;
               # go through each field and set the new value to be a reference
               # to an anonymous array that contains one entry, the old value
               $repeating{$field} = 1; # never do this again
            }
            push @{$data{$field}} , [ split (/\035/ , $value) ];
            # push the array
         }

      }

   }

   close CSVFILE;

   return \%data;
   # %data goes out of scope so the value isn't retained for next time

}

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
