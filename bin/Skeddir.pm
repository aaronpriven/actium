# Skeddir.pm
# vimcolor: #300030

# routine to put Skeds programs in the right directory

use strict;
use warnings;

package Skeddir;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw(change get options);

use FindBin('$Bin');

# the following are Getopt::Long options. Include this as part of the list
# sent to Getopt::Long
sub options () {
   ('basedir=s' , 'signupdir=s');
}

sub change {

   my @returns = &get; # get inherits @_ when invoked as &get

   chdir $returns[0] or die "Can't change directory to $returns[0]";
   # skedsdir

   return @returns;

}

sub get {

   my $options = shift; # $options is hash ref

   my $basedir = $options->{basedir} || "$Bin/../db/";

   my $signup = $options->{signupdir}
       || $ENV{"SKEDS_SIGNUP"}
       || die "No signup directory specified.\n";

   my $skedsdir = "$basedir/$signup";

   return $skedsdir, $basedir, $signup;

}
