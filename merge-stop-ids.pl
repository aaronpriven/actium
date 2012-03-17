#!/ActivePerl/bin/perl


use 5.014;
use warnings;

open my $new, '<', 'new-assignments.txt';

my %text_of;

while (<$new>) {
   chomp;
   my ($id) = split("\t" , $_, 2);
   $text_of{$id} = $_;
}

close $new;

open my $old, '<', 'assignments-sp12.txt';

while (<$old>) {
   chomp;
   my ($id) = split("\t" , $_, 2);
   next unless exists $text_of{$id};
   $text_of{$id} .= "\t$_";
}
   

foreach (keys %text_of) {
   say $text_of{$_};
}
