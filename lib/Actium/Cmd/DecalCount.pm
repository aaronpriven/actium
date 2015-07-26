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
    return;
}

sub OPTIONS {
    my ($class, $env) = @_;
    return Actium::Cmd::Config::ActiumFM::OPTIONS($env);
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);
    my @argv = $env->argv;

    my $input_file = shift @argv;
    my $output_file = add_before_extension( $input_file, 'counted' );

    make_decal_count( $input_file, $output_file, $actiumdb );

    return;

}

1;

__END__
