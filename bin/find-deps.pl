#!/usr/bin/env perl

# find-deps.pl
# Goes through the source code and finds everything marked with a dependency
# tag on the same line.  Omits Actium dependencies since the purpose of it
# is to identify which modules need to be installed for Actium to work.

# This handles most of the typical "use" and "require" statements such that
# just adding the tag on the use or require line will work. Otherwise
# they can be added on comment lines with the tag.

use 5.010;
use warnings;

our $VERSION = 0.010;

#use List::MoreUtils('uniq'); 
# I don't want to have a dependency in the dependency-finding program!

my $tag = '### ' . 'DEP' . ' ###';
# writing it that way avoids finding the literal tag in this file

my @deps = `grep '$tag' -hIR .`;

foreach (@deps) {
   
   s/$tag//;
   s/;//g;
   s/^\s+//;
   s/\s+$//;
   s/^use //;
   s/^require //;
   s/(?:qw)?\(.*\)//g; # deliberately greedy
   s/qw<.*\>//g; 
   s/'.*'//g; 
   s/^#+//;
   s/^\s+//;
   s/\s+$//;

}

@deps = grep { ! /^Actium::/ } @deps;

push @deps, qw( 
     PadWalker 
     Perl::Critic 
     Perl::Critic::Moose 
     Perl::Critic::StricterSubs 
     Perl::Critic::Tics 
     Perl::Tidy 
     App::Ack 
); # general dependencies of the system, not for any single module

@deps = uniq (@deps);
@deps = sort @deps;

say join("\n", @deps);

sub uniq {
  my %seen;
  return grep { !$seen{$_}++ } @_;
}

__END__
