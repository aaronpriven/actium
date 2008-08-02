#!/usr/bin/perl

# Actium.pm
# Various initialization and other routines related to the Actium system

package Actium;
use strict;
use Getopt::Long;
use FindBin('$Bin');
use Carp;
use Storable;
use Text::Wrap;
use Memoize;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK 
   = qw(add_option ensuredir all_true option initialize avldata byroutes
        underlinekey jt jn jtn key say sayf sayq printq sayt transposed);

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
		    $caller_of{$_} = $caller;
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

   add_option ('basedir=s' , 'Base directory (normally .../Actium/db)');
   add_option ('signup=s' ,  'Signup. This is the subdirectory under the base directory. '
                          .  'Typically something like "f08" (meaning Fall 2008).'
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

#####################################
### DIRECTORIES, FILES, ETC ROUTINES
#####################################

sub ensuredir {
  my $dir = shift;
  mkdir $dir or croak "Can't make directory '$dir': $!"
               unless -d $dir;
}

sub avldata {
   printq ("Retrieving data...");
   
   my $avldata_r = Storable::retrieve ('avl.storable') or croak "Can't retreive avl.storable: $!";
   
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
### TRANSPOSE
##########################

sub transposed {
    my $self = shift;
    my @result;
    my $m;

    for my $col (@{$self->[0]}) {
        push @result, [];
    }
    for my $row (@{$self}) {
        $m=0;
        for my $col (@{$row}) {
            push(@{$result[$m++]}, $col);
        }
    }
    return \@result;
}

##########################
### BYROUTES
##########################

# The following is set to my initial assumption about the longest 
# used component length. But it will expand it if it finds a longer one.

my $max_comp_length = 3;
my $redo_expansion = '*';

memoize('_expand_route');

sub _expand_route {

   # The idea here is that since you can't just do an ASCII sort on
   # routes to give a reasonable result (otherwise you get 1, 10, 1R...)
   # but you can generate an intermediate value that you can directly compare.

   # This routine is here, rather than simply placed in the "byroutes"
   # sub, to allow memoization (caching), which should speed up
   # processing significantly.

   my @components = split (/(?<=\d)(?=\D)|(?<=\D)(?=\d)/, $_[0]);
   # That is the zero-width boundary between a number and a non-number.
   # (regardless of order)

   for (@components) {
      
	   # if the component length is longer the maximum, raise the maximum.
	   # Then return a fake entry, indicating that the caller should call again.
	   # We can't just flush the cache and leave it at that, since the caller
	   # may be comparing this one to a previous entry, and we need the
	   # previous entry to be zeroed out too.)
      if (length($_) > $max_comp_length) {
         $max_comp_length = length($_);
         Memoize::flush_cache('_expand_route');
         return $redo_expansion;
      }

      # right-justify numbers. left-justify letters. This gives a proper
      # ASCII sort for both letters and numbers.
      if (/\d/) { # numbers

         tr/0-9/a-j/ if option('lettersfirst');
         # convert numbers to lowercase letters. These sort after uppercase
         # letters. Effectively this changes the sort order to make letters
         # first and not second.

         $_ = sprintf('%*s'  , $max_comp_length , $_);
      } 
      else { # letters
         $_ = sprintf('%-*s' , $max_comp_length , uc($_));
      }
   }
   
   return join($EMPTY_STR, @components);

}

sub byroutes ($$) {

   my ($a, $b);
   LOOP:
   {
      $a = _expand_route ($_[0]);
      $b = _expand_route ($_[1]);
      if ($a eq $redo_expansion or $b eq $redo_expansion) {
         redo LOOP;
      }
   }

   return $a cmp $b;
}

1;
