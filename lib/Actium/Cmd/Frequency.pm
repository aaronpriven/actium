# /Actium/Cmd/Labels.pm
#
# Makes spreadsheet to print decal labels

package Actium::Cmd::Frequency 0.010;

use Actium::Preamble;
use Actium::O::2DArray;

sub HELP {
    say 'Determines the frequency of times.';
    return;
}

sub OPTIONS {

return 
[ 'column=i',     'Column that contains the times. Default is the first column.', 1],
[ 'skiplines=i',  'Lines to skip from the beginning. Default is 0.', 0],
}

sub START {

    my $class     = shift;
    my $env = shift;
    my $actium_db = actiumdb($env);
    
    my @argv = $env->argv;

    my $input_file = shift @argv;
    my $column = shift @argv;

    my $aoa = Actium::O::2DArray::->new_from_file($input_file);
    my @times;



    
    




    return;

}

1;

__END__
