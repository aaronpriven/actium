# Actium/Cmd/Timetables.pm

# Produces InDesign tag files that represent timetables.

# Subversion: $Id$

# legacy status: 4

use warnings;
use 5.012;

package Actium::Cmd::Timetables 0.001;

use English '-no_match_vars';
use autodie;
use Text::Trim;
use Actium::EffectiveDate ('effectivedate');
use Actium::Sorting::Line ( 'sortbyline', 'byline' );
use Actium::Constants;
use Actium::Text::InDesignTags;
use Actium::Text::CharWidth ( 'ems', 'char_width' );
use Actium::O::Folders::Signup;
use Actium::Term;
use Actium::O::Sked;
use Actium::O::Sked::Timetable;
use Actium::Util(qw/doe in chunks population_stdev/);
use Const::Fast;
use List::Util ( 'max', 'sum' );
use List::MoreUtils (qw<uniq pairwise natatime each_arrayref>);
use Algorithm::Combinatorics ('combinations');

const my $IDT        => 'Actium::Text::InDesignTags';
const my $SOFTRETURN => $IDT->softreturn;

# saves typing

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
tabula. Reads schedules and makes tables out of them.
HELP

    Actium::Term::output_usage();

    return;
}

sub START {

    my $signup            = Actium::O::Folders::Signup->new();
    my $tabulae_folder    = $signup->subfolder('tabulae');
    my $pubtt_folder      = $tabulae_folder->subfolder('pubtt');
    my $multipubtt_folder = $tabulae_folder->subfolder('m-pubtt');

    my $xml_db = $signup->load_xml;

    my $prehistorics_folder = $signup->subfolder('skeds');

    chdir( $signup->path );

    # my %front_matter = _get_configuration($signup);

    my @skeds
      = Actium::O::Sked->load_prehistorics( $prehistorics_folder, $xml_db );

    my @all_lines = map { $_->lines } @skeds;
    @all_lines = uniq sortbyline @all_lines;
    my $pubtt_contents_r = _get_pubtt_contents( $xml_db, \@all_lines );

    @skeds = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->sortable_id() ] } @_;

    my ( $alltables_r, $tables_of_r )
      = Actium::IDTables::create_timetable_texts( $xml_db, @skeds );

    Actium::IDTables::output_all_tables( $tabulae_folder, $alltables_r );
    Actium::IDTables::output_pubtts( $pubtt_folder, $pubtt_contents_r,
        $tables_of_r, $signup );
    Actium::IDTables::output_m_pubtts(
        $multipubtt_folder, $pubtt_contents_r, $tables_of_r,
        $signup
    );

    return;

} ## tidy end: sub START

1;