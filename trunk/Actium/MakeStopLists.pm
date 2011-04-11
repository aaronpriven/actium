# Actium/MakeStopLists.pm

# Program for making stop lists

# Subversion: $Id$

# legacy stage 4

use 5.012;
use warnings;

package Actium::MakeStopLists 0.001;

use Actium::Signup;
use Actium::Patterns::Stop;
use Actium::Patterns::Route;
#use Actium::Patterns::DirectionStopList;
use Actium::Term;
use Actium::Sorting('sortbyline');
use Actium::Files('write_files_with_method');
use Actium::Sked::Dir;

my $xml_db;

sub START {

    my $signup                = Actium::Signup->new();
    my $pattern_folder        = $signup->subdir('patterns');
    my $stoplists_folder      = $signup->subdir('slists');
    my $stoplists_line_folder = $stoplists_folder->subdir('line');

    my %stop_obj_of  = %{ $pattern_folder->retrieve('stops.storable') };
    my %route_obj_of = %{ $pattern_folder->retrieve('routes.storable') };

    $xml_db = $signup->load_xml;
    $xml_db->ensure_loaded('Stops');

    emit 'Getting stop descriptions from FileMaker export';

    my $dbh          = $xml_db->dbh;
    my %all_descrips = @{
        $dbh->selectcol_arrayref(
            'select PhoneID, DescriptionCityF from Stops',
            { Columns => [ 1, 2 ] } )
      };

    emit_done;

    emit 'Making stop lists';

    my %stops_of_line;

    my @stoplist_objs;

    foreach my $route ( sortbyline keys %route_obj_of ) {

        my $route_obj = $route_obj_of{$route};
        emit_over($route);

        foreach my $dir ( $route_obj->dircodes ) {

            my @stops = $route_obj->stops_of_dir($dir);
            my %description_of = map { $_ => $all_descrips{$_} } @stops;

            $stops_of_line{"$route-$dir"} = \@stops;
            # for the storable file

            push @stoplist_objs,
#              Actium::Patterns::DirectionStopList->new(
              Actium::MakeStopLists::DirectionStopList->new(
                route          => $route,
                dir            => $dir,
                stops          => \@stops,
                description_of => \%description_of
              );

        }

    } ## tidy end: foreach my $route ( sortbyline...)

    write_files_with_method(
        {   OBJECTS   => \@stoplist_objs,
            SIGNUP    => $stoplists_line_folder,
            FILETYPE  => 'textlist',
            METHOD    => 'textlist',
            EXTENSION => 'txt',
        }
    );
    $stoplists_folder->store( \%stops_of_line, 'line.storable' );

    emit_done;

    return;

} ## tidy end: sub START

#sub get_description {
#    my $stop = shift;
#    state %cache;
#    return $cache{$stop} if $cache{stop};
#
#    my $stop_row_r = $xml_db->row( 'Stops', $stop );
#    return $cache{$stop} = $stop_row_r->{DescriptionCityF};
#}

package Actium::MakeStopLists::DirectionStopList;

use Moose;
use MooseX::StrictConstructor;

has [ 'dir', 'route' ] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'stops_r' => (
    init_arg => 'stops',
    is       => 'bare',
    isa      => 'ArrayRef[Str]',
    handles  => { stops => 'elements' },
    traits   => ['Array'],
);

has 'description_of_r' => (
    init_arg => 'description_of',
    is => 'bare',
    isa => 'HashRef[Str]',
    traits => ['Hash'],
    handles => { description_of => 'get' ,
    },
);

has 'id' => (
   is => 'ro' ,
   builder => '_build_id',
   lazy => 1,
);

sub _build_id {
  my $self = shift;
  return join(q{-} , $self->route , $self->dir);
}

sub textlist {
  my $self = shift;
  my @stops = $self->stops;
  my @results = map { "$_\t" . $self->description_of($_) } @stops;
  return join("\n" , $self->id, @results) . "\n";
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

