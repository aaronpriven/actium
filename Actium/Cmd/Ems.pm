# Actium/Cmd/Ems.pm
# Print number of ems for text

# Subversion: $Id: Time.pm 465 2014-09-25 22:25:14Z aaronpriven $

use warnings;
use strict;

package Actium::Cmd::Ems 0.009;

use 5.020;

use Actium::Text::CharWidth ('ems');

###########################################
## COMMAND
###########################################

sub HELP {

say 'Not implemented.';

}

sub START {

    my $class = shift;
    my %params = @_;

	my @argv = @{$params{argv}};
  
    foreach my $chars (@argv) {
        
        say "$chars: " , ems($chars);
        
    }

}

1;

__END__
# TODO: Add POD
