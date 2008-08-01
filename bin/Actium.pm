#!/usr/bin/perl

# Actium/Init.pm
# Initialization routines related to the Actium system

package Actium::Init;
use strict;
use Getopt::Long;
use FindBin('$Bin');
use Carp;

use Actium::Misc;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(add_option option initialize);

my (%optionspecs, %caller_of, %options);


sub add_option {

   while (@_) {

       my $option = lc(+shift);
       my $optiontext = shift;
       
	    $option = lc($option);

	    my $caller = (scalar(caller())) || 'main';

	    # check to see that there are no duplicate options
	   
	    foreach my $optionname (split_optionnames($option)) {
	    
		    if (exists $caller_of{$optionname} ) {
		       croak "Duplicate option $optionname. Set by $caller_of{$optionname} and $caller";
		    }
		    
		    $caller_of{$_} = $caller;

		 }
		 
		 $optionspecs{$option} = $optiontext;

   }

}

sub split_optionnames {

   # This routine takes an option (in the form used in Getopt::Long)
   # and returns a list of the aliases. 
   my $option = shift;
   $option =~ s/([a-z\?\-\|]+).*/$1/;
   return split(/\|/ , $option);

}

sub initialize {

#  1) Get command-line options
#  2) Prints help message if --help specified
#  3) Get the Actium directory information
#  4) Dies if there's no signup or basedir
#  5) changes current directory

# #######
# Specify the default options, add options from other modules, and
# get them from the command line via Getopts::Long

   my $helptext = shift;
   my $intro = shift;

   add_option ('basedir=s' , '-basedir -- Base directory (normally .../Actium/db)');
   add_option ('signup=s' ,  '-signup -- Signup. This is the subdirectory under the base directory.' 
                       .     '           Typically something like "f08" (meaning Fall 2008).'
                       );
   add_option ('quiet!' , '-quiet -- Do not display status information.' );
   add_option ('help'   , '-help -- Display this message and quit.');
   add_option ('debug!' , '-debug -- produce debugging text.');

   GetOptions (\%options, keys %optionspecs);
   # From Getopt::Long
   
########
# help
#
   
   if ( $options{help} ) {

      print $helptext , "\nOptions:\n";
      foreach (sort values %optionspecs) {
         print $_ , "\n";
      }
      print "\n";
      exit 1;
   
   }
   
   noisysay ($intro);

   
#############
# directories

   $options{basedir} = $options{basedir} 
         || $ENV{"ACTIUM_BASEDIR"}
         || "$Bin/../db/";

   croak "Base directory $options{basedir} not found" unless -d $options{basedir};

   $options{signup} = $options{signup}
       || $ENV{"ACTIUM_SIGNUP"}
       || croak "No signup directory specified.";

   chdir "$options{basedir}/$options{signup}"
        or croak "Can't change directory to $options{basedir}/$options{signup}";
   
   return;
   
}

#########
# access to options

sub option {
   return $options{$_[0]} if exists($options{$_[0]});
   # else
   return undef;
}

sub _alloptions {
   return \%options;
}

1;

# old import routine
#sub import {
#
#   my $package = shift; # always gonna be Actium::Init
#
#   # If the first argument is a hash ref remove and process the reference
#   # before calling Exporter on the rest.
#   
#   # import is always called as part of a BEGIN block so it will activate
#   # before INIT
#   
#   # The hash can have the following entries
#   
#   # HELPTEXT - text to display when user chooses --help. Ignored unless called from main pgm
#   # ARGS - hash. Keys are command-line arguments to pass to Getopt::Long. 
#   #              Values are help texts to print along with the options
#
#   if (ref($_[0]) eq 'HASH') {
#   
#     my $passed_hr = shift(@_);
#     
#     my $caller = (scalar(caller())) || 'main';
#     
#     my %passed_args = %{$passed_hr->{ARGS}};
#     
#     foreach my $arg (keys %{$passed_hr->{ARGS}}) {
#        
#        my $argname = $arg;
#        $argname =~ s/(\w+).*/$1/;
#        
#        if (exists $caller_of{$argname} ) {
#           croak "$caller_of{argname} and " . scalar(caller()) . " both define $argname";
#        }
#        
#        $caller_of{$argname} = $caller;
#     }
#
#     %all_passed_args = (%all_passed_args , %passed_args) ;
#     
#     $helptext = $passed_hr->{HELPTEXT}
#        if ( exists ($passed_hr->{HELPTEXT}) and $caller eq 'main' );
#     
#   }
#   
#   Actium::Init->export_to_level(1, $package, @_);
#   
##   if ($_[0] eq 'option') {
##
##      my $caller = caller;
##      no strict 'refs';
##      *{ $caller . '::option'} = \&option;
##
##   }
#
#}
