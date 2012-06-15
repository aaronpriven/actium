#!/ActivePerl/bin/perl

use 5.014;
use warnings;

# Takes old assignments.txt and adds new stops from stoplines-dir to it

@ARGV = qw(-s su12 -b /Volumes/Bireme/Actium/db -c /tmp/c);

use FindBin('$Bin');
use lib ($Bin );

use Actium::Folders::Signup;

use Actium::Options ('init_options');

init_options;

my $signup = Actium::Folders::Signup->new();


#$/ = "\r";

my $flagfolder = $signup->subfolder('flags');

my $oldfile = $flagfolder->make_filespec('assignments-old.txt');

open my $old, '<' , $oldfile
   or die $!;
   
my $headers = <$old>;
chomp $headers;

my %old_assignment_of;
my %assignment_of;

while (<$old>) {
   chomp;
   my ($stopid, $text) = split (/\t/ , $_);
   
   $old_assignment_of{$stopid} = $_;
 
}

close $old or die $!;

$/ = "\n";

my $newfile = $signup->make_filespec('stoplines-dir.txt');

open my $new, '<' , $newfile
   or die $!;
   
my $newheaders = <$new>;

while (<$new>) {
   chomp;
   my ($stopid, $text) = split (/\t/ , $_);
   if (exists $old_assignment_of{$stopid}) {
      $assignment_of{$stopid} = $old_assignment_of{$stopid};
   } else {
      $assignment_of{$stopid} = $_;
   }
 
}

close $new or die $!;

my $outfile = $flagfolder->make_filespec('assignments-new.txt');

open my $out , '>' , $outfile
   or die $!;
   
say $out $headers;

foreach my $stopid (sort keys %assignment_of) {
    say $out $assignment_of{$stopid};
}

close $out or die $!;