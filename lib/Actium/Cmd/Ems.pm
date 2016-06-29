package Actium::Cmd::Ems 0.011;

# Print number of ems for text

use Actium::Preamble;

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
