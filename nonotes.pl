#!/usr/bin/perl
# 
# nonotes - make copy of /skeds without notes

@ARGV = qw(-s w07) if $ENV{RUNNING_UNDER_AFFRUS};

use strict;
use warnings;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::Folders::Signup;
my $signupdir = Actium::Folders::Signup->new();
chdir $signupdir->get_dir();
my $signup = $signupdir->get_signup;

my @files = glob ("skeds/*.txt");

mkdir "nonotes-skeds" or die "Can't create skeds-nonotes directory: $!"
   unless -d "nonotes-skeds";

foreach my $file (@files) {

   open IN , '<' , $file;
   open OUT , '>' , "nonotes-$file";

   $_ = <IN>;
   s/\t+$//;
   print OUT $_;
   $_ = <IN>;
   s/\t+$//;
   print OUT $_;
   # skip first two lines
   
   while (<IN>) {
      s/\t+$//;
      my @cols = split (/\t/);
      splice (@cols, 1, 1);
      print OUT join("\t" , @cols);
   }
   
   close IN;
   close OUT;

}

