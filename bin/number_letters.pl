
while (@ARGV) {

@combos = split( /(?<=\d)(?=\D)|(?<=\D)(?=\d)/ , shift);

# ain't that cool? That uses "lookaheads" and "lookbehinds" to specify
# first, a break between a digit and a non-digit, and second,
# a break between a non-digit and a digit.
# 
# basically, it's like split /\b/, except that instead of alphanumerics,
# it only likes numerics.


foreach (@combos) {

   print "[$_]";

}

print "\n";

}
