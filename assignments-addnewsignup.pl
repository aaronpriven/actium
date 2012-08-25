#!/ActivePerl/bin/perl

use 5.014;
use warnings;

# Takes old assignments.txt and adds new stops from stoplines-dir to it

@ARGV = qw(-s f12 -b /Volumes/Bireme/Actium/db -c /tmp/c);

use FindBin('$Bin');
use lib ($Bin );

use Actium::Folders::Signup;

use Actium::Options ('init_options');

init_options;

my $signup = Actium::Folders::Signup->new();


$/ = "\r";

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
   my @fields = split (/\t/);
   
   my $stopid = shift @fields;
   my @use_new = splice (@fields, 0, 5); 
   # use new values for these fields, so throw these away
   my $text = join("\t" , @fields);
#   my ($stopid, $text) = split (/\t/ , $_);
   
   $old_assignment_of{$stopid} = $text;
 
}

close $old or die $!;

$/ = "\n";

my $newfile = $signup->make_filespec('stoplines-dir.txt');

open my $new, '<' , $newfile
   or die $!;
   
my $newheaders = <$new>;

while (<$new>) {
   chomp;
   
   my @fields = split(/\t/);
   
   $fields[6] = ''; # blank out "size" field
   $fields[10] = 'New ' . $signup->signup;
   
   foreach (@fields) {
      $_ = '' unless defined $_ ;
   }
   
   my $stopid = $fields[0];
   my $use_new = join("\t" , @fields[1..5] );
   my $text = join("\t" , @fields[6 .. $#fields] );
   
   if (exists $old_assignment_of{$stopid}) {
      $assignment_of{$stopid} = 
         "$stopid\t$use_new\t$old_assignment_of{$stopid}";
   } else {
      $assignment_of{$stopid} = 
         "$stopid\t$use_new\t$text";
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
