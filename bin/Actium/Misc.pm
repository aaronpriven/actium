#!/usr/bin/perl

package Actium::Misc;

# Miscellaneous routines not deserving of their own module

use warnings;
use strict;

use Actium::Constants;

use Actium::Init;

use Carp;

use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw(say sayt jt jn);

sub say { print @_ , "\n"; }

sub ensuredir {
  my $dir = shift;
  mkdir $dir or die "Can't make directory '$dir': $!"
               unless -d $dir;
}

sub noisysay { return if option('quiet'); say @_ };

sub noisyprint { return if option('quiet'); print @_ };

sub sayt {
   my $join = ( $ENV{'RUNNING_UNDER_AFFRUS'} ? '  ' : "\t" );
   print join ($join , @_) , "\n";
}

# syntactic sugar is so, so sweet

sub jt { return join ("\t" , @_ ) };
sub jn { return join ("\n" , @_ ) };


sub key {
   return join ($KEY_SEPARATOR, @_);
}

sub tab {
   return ( join ("\t", @_) . "\n");
}

sub avldata {
   print "Retrieving data...";
   my $avldata_r = %{
      Storable::retrieve ('avl.storable') or croak "Can't retreive avl.storable: $!"
   };
   print "done.\n";
   return $avldata_r;

}



1;
