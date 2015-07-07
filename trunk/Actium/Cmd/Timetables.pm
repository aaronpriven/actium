# Actium/Cmd/Timetables.pm

# Produces InDesign tag files that represent timetables.

# Subversion: $Id: Timetables.pm 465 2014-09-25 22:25:14Z aaronpriven $

# legacy status: 4

use warnings;
use 5.012;

package Actium::Cmd::Timetables 0.006;

use Actium::O::Folders::Signup;
use Actium::O::Sked;
use List::MoreUtils       (qw<uniq pairwise natatime each_arrayref>);
use Actium::Sorting::Line (qw(sortbyline byline));
use Actium::IDTables;
use Actium::Cmd::Config::ActiumFM ('actiumdb');

use English '-no_match_vars';
use autodie;
use Actium::Constants;

# saves typing

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
timetables. Reads schedules and makes timetables out of them.
HELP

    Actium::Term::output_usage();

    return;
}

sub START {
    
    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};

    my $actiumdb = actiumdb($config_obj);

    my $signup            = Actium::O::Folders::Signup->new();
    my $tabulae_folder    = $signup->subfolder('timetables');
    my $pubtt_folder      = $tabulae_folder->subfolder('pubtt');
    my $multipubtt_folder = $tabulae_folder->subfolder('pub-idtags');

    my $prehistorics_folder = $signup->subfolder('skeds');

    chdir( $signup->path );

    # my %front_matter = _get_configuration($signup);

    my @skeds
      = Actium::O::Sked->load_prehistorics( $prehistorics_folder, $actiumdb );

    my @all_lines = map { $_->lines } @skeds;
    @all_lines = grep { $_ ne 'BSD' and $_ ne 'BSN'} @all_lines;
    @all_lines = uniq sortbyline @all_lines;
    
    my ($pubtt_contents_with_dates_r , $pubtimetables_r) 
      = Actium::IDTables::get_pubtt_contents_with_dates( $actiumdb, \@all_lines );

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
