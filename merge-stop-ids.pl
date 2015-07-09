#!/ActivePerl/bin/perl


use 5.014;
use warnings; ### DEP ###
use autodie; ### DEP ###

our $VERSION = 0.003;

my $firstfile = shift @ARGV;
my $secondfile = shift @ARGV;

open my $new, '<', $secondfile ;

my $headers = <$new>;
chomp $headers;

my %text_of;

while (<$new>) {
   chomp;
   my ($id) = split("\t" , $_, 2);
   $text_of{$id} = $_;
}

close $new;

#$/ = "\r";
open my $old, '<', $firstfile;


my $newheaders  = <$old>;
chomp $newheaders;

my ($headerid, $headerrest) = split (/\t/ ,$newheaders);

$headers .= "\t" . $headerrest;

while (<$old>) {
   chomp;
   my ($id, $rest) = split("\t" , $_);
   next unless exists $text_of{$id};
   $text_of{$id} .= "\t$rest";
}
   
say $headers;
foreach (sort keys %text_of) {
   say $text_of{$_};
}
