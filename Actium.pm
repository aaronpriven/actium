#!/usr/bin/perl

# Actium.pm
# Various initialization and other routines related to the Actium system

package Actium;
use strict;
use warnings;

use Getopt::Long;
use FindBin('$Bin');
use Carp;
use Storable;
use Text::Wrap;
use Memoize;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK 
   = qw(add_option ensuredir chdir_signup all_true option initialize avldata 
        byroutes underlinekey jt jn jtn key say sayf sayq printq sayt );

use Actium::Constants;

my (%optionspecs, %caller_of, %options);

#################
#### OPTIONS ####
#################

sub add_option {

   # If another module (as opposed to a main program)
   # calls this routine, it should do so in an INIT block

   while (@_) {

       my $option = lc(+shift);
       my $optiontext = shift;
       
       my $caller = (scalar(caller())) || 'main';

       # check to see that there are no duplicate options
      
       foreach my $optionname (_split_optionnames($option)) {
       
          if (exists $caller_of{$optionname} ) {
             croak "Duplicate option $optionname. Set by $caller_of{$optionname} and $caller";
          }
          $caller_of{$optionname} = $caller;
       }
       $optionspecs{$option} = $optiontext;
   }
}

sub _split_optionnames {

   # This routine takes an option (in the form used in Getopt::Long)
   # and returns a list of the aliases. 
   my $option = shift;
   $option =~ s/([a-z\?\-\|]+).*/$1/;
   return split(/\|/ , $option);

}

sub option {
   return $options{$_[0]} if exists($options{$_[0]});
   # else
   return undef;
}

####################
#### INITIALIZE ####
####################

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

   add_option ('basedir=s' , 'Base directory (normally [something]/Actium/db)');
   add_option ('signup=s' 
               , 'Signup. This is the subdirectory under the base directory. '
               . 'Typically something like "f08" (meaning Fall 2008).'
               );
   add_option ('quiet!' , 'Do not display status information.' );
   add_option ('help'   , 'Display this message and quit.');
   add_option ('debug!' , 'Produce debugging text.');
   
   add_option ('lettersfirst!'
      , 'When routes are sorted, sort letters ahead of numbers (like Muni, not AC)');
       # useful for others, maybe
      

   # the ACTIUMCMD environment variable goes on the front of the command line.
   # This allows the command line to override items. I think this should work.
   # The Getopt::Long documentation is not clear.
   
   if ($ENV{'ACTIUMCMD'}) {
      unshift (@ARGV, split (/\s+/ , $ENV{'ACTIUMCMD'}) );
   }

   my $optresult = GetOptions (\%options, keys %optionspecs);
   # From Getopt::Long
   
########
# help
#
   
   if ( option('help') or not $optresult) {

      my %helpmessages;
      
      print "\n";
      
      $helptext =~ s/\n+\z//;
      
      print $helptext , "\n\nOptions:\n";
      
      my $longest = 0;
      
      foreach my $spec (keys %optionspecs) {
         my (@optionnames) = _split_optionnames($spec);

         foreach (@optionnames) {
            $longest = length($_) if $longest < length($_);
         }
         
         my $first = shift @optionnames;

         $helpmessages{$first} = $optionspecs{$spec};
         $helpmessages{$_} = "Same as -$first." foreach @optionnames;

      }
      
      $longest++; # add one for the hyphen in front
      
      foreach (sort keys %helpmessages) {
         my $optionname = sprintf "%*s -- " , $longest, "-$_";
         
         #local($Text::Wrap::columns) = 75 - ($longest);
         say (Text::Wrap::wrap($EMPTY_STR, " " x ($longest + 4) , $optionname . $helpmessages{$_}));
         
      }
      print "\n";
      exit 1;
   
   }
   
   sayq ($intro);

   
#############
# check for, and change to, directories

   $options{basedir} = $options{basedir} 
         || $ENV{'ACTIUM_BASEDIR'}
         || "$Bin/../db/";

   croak "Base directory $options{basedir} not found" 
      unless -d $options{basedir};

   chdir_signup (qw(signup ACTIUM_SIGNUP signup));
    
   return;
   
}

#####################################
### DIRECTORIES, FILES, ETC ROUTINES
#####################################

sub chdir_signup {
   my $option = shift;
   my $env_variable = shift;
   my $description = shift;
   
   $options{$option} = $options{$option}
       || $ENV{$env_variable}
       || croak "No $description directory specified.";

   chdir "$options{basedir}/$options{$option}"
        or croak "Can't change directory to $options{basedir}/$options{$option}";

}

sub ensuredir {
  my $dir = shift;
  mkdir $dir or croak "Can't make directory '$dir': $!"
               unless -d $dir;
}

sub avldata {
   printq ("Retrieving data...");
   
   my $avldata_r = 
      Storable::retrieve ('avl.storable') 
      or croak "Can't retreive avl.storable: $!";
   
   sayq ("done.");
   return $avldata_r;

}


##########################
#### SAY, PRINT, JOIN, ETC.
##########################

sub say { print @_ , "\n"; }

sub sayf {
   my $fh = shift;
   print $fh @_ , "\n";
}

sub sayq { return if option('quiet'); say @_ };

sub printq { return if option('quiet'); print @_ };

sub sayt {
   my $join = ( $ENV{'RUNNING_UNDER_AFFRUS'} ? '  ' : "\t" );
   print join ($join , @_) , "\n";
}

# syntactic sugar is so, so sweet

sub jt { return join ("\t" , @_ ) };

sub jn { return join ("\n" , @_ ) };

sub jtn {
   return ( join ("\t", @_) . "\n");
}

##########################
### KEY ROUTINES
##########################

sub key {
   return join ($KEY_SEPARATOR, @_);
}

sub underlinekey {
  local $_ = shift;
  s/$KEY_SEPARATOR/_/g;
  return $_;
}


##########################
### LISTS
##########################

sub all_true { $_ || return 0 for @_; 1 }
# tests each entry of @_, and returns 0 if any of them are false.


##########################
### BYROUTES
##########################

# The following is set to my initial assumption about the longest 
# used component length. But the program will make the length
# larger if it finds a longer one.
# Or, if you know it's longer, specify it by doing 
# "sortable_maxcomplength(yournum);"

my $max_comp_length = 3;

sub sortable_maxcomplength {
   $max_comp_length = $_[0] unless $_[0] < $max_comp_length;
   return $max_comp_length;
}

#memoize('sortable_route', NORMALIZER => '_normalize_sortable_route');
#memoize('_sortable_route_generate');


sub sortable_route {

   # This routine takes a list of routes and returns a list of values
   # that you can use to sort the routes properly.
   
   # for example, if you do
   #
   # @sorted_value_of{@routes} = sortable_route(@routes);
   #
   # then
   #
   # @routes = sort { $sorted_value_of{$a} cmp $sorted_value_of{$b} } @routes 
   #
   # will give you a properly sorted list of routes.

   # The idea here is that you can't just do an ASCII sort on
   # routes to give a reasonable result (otherwise you get 1, 10, 1R, 2...)
   # but you can generate an intermediate value that you can directly compare.

   # This routine is here, rather than simply placed in the "byroutes"
   # sub, to allow memoization (caching), which should speed up
   # processing significantly.
   
   # Note that the values are only guaranteed to be consistent within a single
   # operation of sortable_route, because the length of each component
   # (group of digits or letters) may change. If you do 
   #
   # $a = sortable_route($route1);
   # $b = sortable_route($route2);
   #
   # then the values of $a and $b may or may not be comparable, depending on
   # the makeup of $route2. So don't do that unless you know the maximum component
   # length won't change.
   
   # Anything other than a digit is treated like a letter and sorted in character-code
   # order. Which is probably not what you want, but I can't imagine anybody
   # actually using routes like "dollar-sign" or "e-with-acute" and if they did I don't
   # know how they'd sort them.

  my @sortables;
     
  ROUTES:
  {

  foreach (@_) {
     my $sortable = _sortable_route_generate($_);
     unless (defined($sortable)) {
         # _sortable_route_generate returns undef if maximum
         # component length has changed
         
         #Memoize::flush_cache('sortable_route');
         #Memoize::flush_cache('_sortable_route_generate');
         @sortables = ();
         redo ROUTES;
     }
         
     # If the maximum component length has changed, go back
     # and do everything over, since that means all the 
     # old ones aren't long enough to be sorted.
     
     # Another way to do this would be to go through all the routes passed
     # to sortable_routes first, calculate the longest component 
     # length, and then use that.
     
     # But this makes it do lots and lots of calculating of the longest 
     # component length of each possible set of routes sorted, and this
     # would have to be re-done over and over. Since the
     # longest component is only going to be reset *at most* a couple
     # of times -- and more likely, never, since I've preset it to 3
     # and not many systems have routes like "1000" or "AAAA", I thought
     # it was better to do it this way.

     push @sortables, $sortable;
     
     }
  } # ROUTES

  return @sortables;
   
}

sub _normalize_sortable_route {

   # Memoize uses the string that this returns to figure out whether
   # this argument has been seen before.
   
   # This allows sortable_route('B', 'A') to use value from 
   # the cache for sortable_route('A', 'B'). 
   
   my @routes = map ( uc , @_);
   # uppercase each entry
  
   return join($KEY_SEPARATOR , sort @routes);
   # return the list of routes, naively sorted

}

sub _sortable_route_generate {

   # This returns either a sortable route string, or "undef" if the 
   # caches need to be cleared because the maximum component length was
   # too short.
   
   my @components = split (/(?<=\d)(?=\D)|(?<=\D)(?=\d)/, uc($_[0]));
   # That is the zero-width boundary between a number and a non-number.
   # (regardless of order). Converts to uppercase letters.

   for (@components) {
      
      # if the component length is longer the maximum, raise the maximum
      # and return undef (so the calling routine can flush the caches).

      if (length($_) > $max_comp_length) {
         $max_comp_length = length($_);
         return undef;
      }

      # right-justify numbers. left-justify letters. This gives a proper
      # ASCII sort for both letters and numbers.
      if (/\d/) { # numbers

         $_ = sprintf('%0*s'  , $max_comp_length , $_);

         tr/0-9/a-j/ if option('lettersfirst');
         # convert numbers to lowercase letters. These sort after uppercase
         # letters. Effectively this changes the sort order to make letters
         # first and not second.

      } 
      else { # letters (or anything else)
         $_ = sprintf('%-*s' , $max_comp_length , uc($_));
      }
   }
   
   return join($EMPTY_STR, @components);

}

sub byroutes ($$) {

   my ($a, $b) = sortable_route(@_);
   return $a cmp $b;

}

1;
