#!perl

require 'pubinflib.pl';

init_vars();

chdir get_directory() or die "Can't change to specified directory.\n";

our %tphash;

build_tphash();

mkdir "fullout" or die 'Can\'t make directory "fullout"'  unless -d "fullout";

our %index = read_index();

LINE:
foreach $line (keys %index) {

   DAY_DIR:
   foreach $daydir (keys %{$index{$line}}) {


      output_full_schedule ($line, $daydir);

   }

}

sub output_full_schedule($$) {

my $line = shift;
my $daydir = shift;




}

