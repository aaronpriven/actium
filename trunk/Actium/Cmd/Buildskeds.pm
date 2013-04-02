# buildskeds - builds schedules from headways and from HSA files

# never completed or even hardly started, but is intended to combine
# schedules from headways and hastusasi files into a single set of schedules

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Cmd::Buildskeds 0.001;

use Actium::Cmd::Headways; 

# TODO - Move Headways processing to a module not in Cmd. 
# Or alternatively, delete this file which doesn't really do anything

use Actium::O::Folders::Signup;

sub START {

   my $signup = Actium::O::Folders::Signup->new();
   
   my @skeds = build_skeds($signup);
   
   # do something with @skeds

}

sub build_skeds {
    
   my $signup = shift;
    
   my @headwayskeds = process_headway_sheets($signup);
   my @skeds = process_HSAfiles($signup);
   @skeds = combine_headways_and_HSAs(\@headwayskeds, \@skeds);
   output_files($signup, @skeds);
    
}

sub process_headway_sheets {
   my $signup = shift;
   
   my $headwaysdir = $signup->subfolder("headways");
   my @headwaysfiles = $headwaysdir->glob_plain_files('*.{prt,txt}');

   my @skeds = Actium::Cmd::Headways::read_headways(@headwaysfiles);

   return @skeds;

}

__END__
