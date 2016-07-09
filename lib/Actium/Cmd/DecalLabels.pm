package Actium::Cmd::DecalLabels 0.011;

# Makes spreadsheet to print decal labels

use Actium::Preamble;
use Actium::Util('add_before_extension');
use Actium::DecalPreparation(qw/make_labels/);

sub HELP {
    say 'Makes spreadsheet with labels for decal envelopes.';
    return;
}

sub OPTIONS {
    return 'actiumdb';
}

sub START {

    my $class     = shift;
    my $env = shift;
    my $actium_db = $env->actiumdb;
    
    my @argv = $env->argv;

    my $input_file = shift @argv;
    my $output_file = add_before_extension( $input_file, 'labels' );

    make_labels( $input_file, $output_file, $actium_db );

    return;

}

1;

__END__
