package Actium::Cmd::Timetables 0.012;

# Produces InDesign tag files that represent timetables.

use Actium::Preamble;

use Actium::O::Sked::Collection;
use Actium::O::Sked;
use Actium::IDTables;

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
timetables. Reads schedules and makes timetables out of them.
HELP

    return;
}

sub OPTIONS {
    return qw/signup actiumdb/;
}

sub START {
    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;
    my $signup   = $env->signup;

    my $tabulae_folder    = $signup->subfolder('timetables');
    my $pubtt_folder      = $tabulae_folder->subfolder('pubtt');
    my $multipubtt_folder = $tabulae_folder->subfolder('pub-idtags');
    my $storablefolder    = $signup->subfolder('s');

    #my $prehistorics_folder = $signup->subfolder('skeds');

    my $collection
      = Actium::O::Sked::Collection->load_storable($storablefolder);

    chdir( $signup->path );

    # my %front_matter = _get_configuration($signup);

    # my @skeds
    #   = Actium::O::Sked->load_prehistorics( $prehistorics_folder, $actiumdb );

    my @skeds = $collection->skeds;

    my @all_lines = map { $_->lines } @skeds;
    @all_lines = grep { $_ ne 'BSD' and $_ ne 'BSN' } @all_lines;
    @all_lines = u::uniq u::sortbyline @all_lines;

    my ( $pubtt_contents_with_dates_r, $pubtimetables_r )
      = Actium::IDTables::get_pubtt_contents_with_dates( $actiumdb,
        \@all_lines );

    @skeds = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->sortable_id() ] } @skeds;

    my ( $alltables_r, $tables_of_r )
      = Actium::IDTables::create_timetable_texts( $actiumdb, @skeds );

    Actium::IDTables::output_all_tables( $tabulae_folder, $alltables_r );

    Actium::IDTables::output_a_pubtts( $multipubtt_folder,
        $pubtt_contents_with_dates_r, $pubtimetables_r, $tables_of_r, $signup );

    return;

} ## tidy end: sub START

1;
