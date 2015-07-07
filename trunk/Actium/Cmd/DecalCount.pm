# /Actium/Cmd/DecalCount.pm
#
# Makes spreadsheet to calculate decal count

package Actium::Cmd::DecalCount 0.010;

use Actium::Preamble;
use Actium::Util('add_before_extension');
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::DecalPreparation(qw/make_decal_count/);

sub HELP {
    say 'Makes spreadsheet to calculate decal count.';
}

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};

    my $actium_db = actiumdb($config_obj);

    my $input_file = shift @{ $params{argv} };
    my $output_file = add_before_extension( $input_file, 'counted' );

    make_decal_count( $input_file, $output_file, $actium_db );

    return;

}

1;

__END__


