# Actium/Cmd/Ems.pm
# Print number of ems for text

use warnings;
use strict;

package Actium::Cmd::Ems 0.010;

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
    my $env = shift;
    my @argv = $env->argv;

    foreach my $chars (@argv) {
        
        say "$chars: " , ems($chars);
        
    }

}

1;

__END__
# TODO: Add POD
