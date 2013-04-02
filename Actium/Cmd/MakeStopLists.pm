# Actium/Cmd/MakeStopLists.pm

# Program for making stop lists

# Subversion: $Id$

# legacy stage 4

use 5.012;
use warnings;

package Actium::Cmd::MakeStopLists 0.001;

use Actium::O::Folders::Signup;
use Actium::O::Patterns::Stop;
use Actium::O::Patterns::Route;

use Actium::O::Stoplists::ByDirection;
use Actium::Term;
use Actium::Sorting::Line('sortbyline');

my $xml_db;

sub START {

    my $signup                = Actium::O::Folders::Signup->new();
    my $stoplists_folder      = $signup->subfolder('slists');
    my $stoplists_line_folder = $stoplists_folder->subfolder('line');

    my ( $stoplist_objs_r, $stops_of_line_r ) = stop_lists($signup);

    $stoplists_line_folder->write_files_with_method(
        {
            OBJECTS   => $stoplist_objs_r,
            METHOD    => 'textlist',
            EXTENSION => 'txt',
        }
    );

    $stoplists_folder->store( $stops_of_line_r, 'line.storable' );

    emit_done;

    return;

}    ## tidy end: sub START

sub stop_lists {

    my $signup = shift;

    my $pattern_folder = $signup->subfolder('patterns');

    my %stop_obj_of  = %{ $pattern_folder->retrieve('stops.storable') };
    my %route_obj_of = %{ $pattern_folder->retrieve('routes.storable') };

    $xml_db = $signup->load_xml;
    $xml_db->ensure_loaded('Stops');

    emit 'Getting stop descriptions from FileMaker export';

    my $dbh = $xml_db->dbh;

    my $stops_row_of_r =
      $xml_db->all_in_columns_key(qw/Stops DescriptionCityF/);

    emit_done;

    emit 'Making stop lists';

    my %stops_of_line;

    my @stoplist_objs;

    foreach my $route ( sortbyline keys %route_obj_of ) {

        my $route_obj = $route_obj_of{$route};
        emit_over($route);

        foreach my $dir ( $route_obj->dircodes ) {

            my @stops = $route_obj->stops_of_dir($dir);
            my %description_of =
              map { $_ => $stops_row_of_r->{DescriptionCityF}{$_} } @stops;
            $stops_of_line{"$route-$dir"} = \@stops;

            # for the storable file

            push @stoplist_objs,
              Actium::O::Stoplists::ByDirection->new(
                route          => $route,
                dir            => $dir,
                stops          => \@stops,
                description_of => \%description_of
              );

        }

    }    ## tidy end: foreach my $route ( sortbyline...)

    return \@stoplist_objs, \%stops_of_line;
}

1;

__END__

