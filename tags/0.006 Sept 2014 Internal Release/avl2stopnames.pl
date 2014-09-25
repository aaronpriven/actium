#!/usr/bin/perl

# avl2stopnames - see POD documentation below

# legacy stage 2

use warnings;
use strict;

our $VERSION = 0.002;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ($Bin , "$Bin/../bin");

use Carp;
#use Fatal qw(open close);
use Storable();

use Actium::Constants;
use Actium::Union('ordered_union');

use Text::Trim;

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2stopnames reads the data written by readavl and sends to standard output
a list of stop names, altered by some simple rules to make them more readable.
EOF

my $intro = 'avl2stoplists -- make more readable stop names from AVL data';

use Actium::Options;
use Actium::O::Folders::Signup;
my $signup = Actium::O::Folders::Signup->new();
chdir $signup->path();

# retrieve data

my %stp;

{ # scoping
# the reason to do this is to release the %avldata structure, so Affrus 
# (or, presumably, another IDE)
# doesn't have to display it when it's not being used. Of course it saves memory, too

my $avldata_r = $signup->retrieve('avl.storable');


%stp = %{$avldata_r->{STP}};

}

my %suffixes;

foreach my $stop_r (values %stp) {

   my $stopid = $stop_r->{Identifier};
   
   my $desc = $stop_r->{Description};
   my $orig = $desc;

   if ( lc($desc) eq $desc or uc($desc) eq $desc) {
      # if $desc is all uppercase or all lowercase,
      $desc =~ s/(\w+)/\u\L$1/g;
      # change it to title case
   }

   my $comment = '';

   {
   $desc =~ s/(\([^\)]*\))//;
   $comment = $1 || '';
   }

   if ($comment) {
     $comment =~ s/^\(//;
     $comment =~ s/\)$//;
   }
   

   my ($on, $at) = split (/:/ , $desc , 2);

   streetsuffixes($on);

   my $num = '';

   if ($at and $at =~ /^\#/) {

      ($num, $at) = split(/\s/ , $at, 2);
      $num =~ s/^\#//;

   }

   if ($at) {
      streetsuffixes($at);
   } 
   else {
      $at = ''
   }

   trim( $on, $at, $comment, $num);

   #print "[on:$on] [at:$at] [com:$comment]\n";

   my $newdesc = '';
   $newdesc = "$num " if $num;
   $newdesc .= $on;
   $newdesc .= " & $at" if $at;
   $newdesc .= " ($comment)" if $comment;

   print join("\t" , $stopid, $orig, $newdesc) , "\n";  

}

sub streetsuffixes {

   for (@_) {

   s/\b(N|S|E|W|Av|St|Blvd|Ct|Dr|Rd|Pkwy|Pl|Cir|Fwy)\.?\b/$1\./ig;
   s/bart station/BART/i;
   s/amtrak station/Amtrak/i;
   s/\bCom\b/Commons/i;
   s/\bbart\b/BART/i;
   s/\bAve\.?\b/Av./i;
   s/\bTer\.?\b/Terrace/i;
   s/\bWy\.?\b/Way/i;
   s/\bLn\.?\b/Lane/i;

   }

}

=head1 NAME

avl2stopnames -- make more readable stop names from AVL data.

=head1 DESCRIPTION

avl2stopnames reads the data written by readavl and sends to standard output
a list of stop names, altered by some simple rules to make them more readable.

The simple rules are regular expressions found in the program.

=head1 AUTHOR

Aaron Priven

=cut

