#!perl 

open OUT, ">" . pop @ARGV ;
select OUT;
print OUT sort { length($b) <=> length($a) } <>;

# blasted not-working stdout redirection in cmd.exe
