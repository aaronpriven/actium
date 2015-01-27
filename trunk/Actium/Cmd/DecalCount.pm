# /Actium/Cmd/DecalCount.pm
#
# Makes spreadsheet to calculate decal count

# Subversion: $Id$

package Actium::Cmd::DecalCount 0.008;

use Actium::Preamble;
use Actium::Util('add_before_extension');
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::DecalPreparation(
    qw/write_decalcount_xlsx count_decals decals_of_stop read_decal_list/);

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

    my %lines_of = %{ read_decal_list($input_file) };

    my $db_decals_of_r = $actium_db->all_in_column_key(qw/Stops_Neue p_decals/);

    my ( $decals_of_r, $found_decals_of_r ) =
      decals_of_stop( \%lines_of, $db_decals_of_r );

    my $count_of_r = count_decals($found_decals_of_r);

    write_decalcount_xlsx(
        output_file     => $output_file,
        decals_of       => $decals_of_r,
        found_decals_of => $found_decals_of_r,
        count_of        => $count_of_r
    );

    return;

}

1;

__END__
