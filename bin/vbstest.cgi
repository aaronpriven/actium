#!/usr/bin/perl5

require ('/home/priven/public_html/cgi-lib.pl');

&ReadParse;

# get data from form

print "Content-type: text/plain\n\n";

print "This bit isn't finished yet. Sorry!\n\n";

print "Here's the data I know:\n";

foreach (keys %in) {

$temp = $in{$_};

$temp =~ s/\0/, /g;

print "Key: $_   \tValue: $temp\n";

}

print "\nThanks for playing!\n";

