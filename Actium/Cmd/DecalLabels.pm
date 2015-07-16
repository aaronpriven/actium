# /Actium/Cmd/Labels.pm
#
# Makes spreadsheet to print decal labels

package Actium::Cmd::DecalLabels 0.010;

use Actium::Preamble;
use Actium::Util('add_before_extension');
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::DecalPreparation(qw/make_labels/);

sub HELP {
    say 'Makes spreadsheet with labels for decal envelopes.';
    return;
}

sub OPTIONS {
    return Actium::Cmd::Config::ActiumFM::OPTIONS();
}

sub START {

    my $class     = shift;
    my %params    = @_;
    my $actium_db = actiumdb(@_);

    my $input_file = shift @{ $params{argv} };
    my $output_file = add_before_extension( $input_file, 'labels' );

    make_labels( $input_file, $output_file, $actium_db );

    return;

}

1;

__END__
