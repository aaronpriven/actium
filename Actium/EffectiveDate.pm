#Actium/EffectiveDate.pm

# Subversion: $Id$

# Lame, and should be replaced by a database lookup

use 5.012;
use warnings;

package Actium::EffectiveDate 0.001;

use Perl6::Export::Attrs;

sub effectivedate :Export {

    my $signup = shift;
    my $filespec = $signup->make_filespec('effectivedate.txt');

    open my $date, '<', $filespec
      or die "Can't open $filespec for input";

    our $effdate = scalar <$date>;
    close $date;
    chomp $effdate;
    $effdate =~ s/\r//g;
    return $effdate;

} 

1;