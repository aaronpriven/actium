#!/ActivePerl/bin/perl

#/Actium/Flagspecs/RelevantPlaces.pm

# Subversion: $Id$

use warnings;
use strict;

package Actium::Flagspecs::Descriptions;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Actium::Constants;
use Actium::Flagspecs::RelevantPlaces ('relevant_places');

use Perl6::Export::Attrs;

my $timepoint_data;
sub load_timepoint_data {
    my $signup = shift;
    $timepoint_data = $signup->mergeread('Timepoints.csv');
    return;
}

sub destination_of :Export {
    my $dir        = shift;
    my @placelists = @_;
    
    load_timepoint_data() unless $timepoint_data;
    
    my $column     = $timepoint_data->column_order_of('DestinationF');

    my %destinations;
    my @place_arys;

    foreach my $placelist (@placelists) {
        push @place_arys, [ sk($placelist) ];
    }

    my @union = ordered_union(@place_arys);
    my %order;

    foreach ( 0 .. $#union ) {
        $order{ $union[$_] } = $_;
    }

    foreach my $placelist (@placelists) {
        my $place = $placelist;
        $place =~ s/.*$KEY_SEPARATOR//sx;
        my $row = $timepoint_data->rows_where( 'Abbrev4', $place );
        $destinations{ $row->[$column] } = $order{$place};
    }

    my $destination = join( q{ / },
        sort { $destinations{$b} <=> $destinations{$a} }
          keys %destinations );

    return (
          $dir eq 'CW' ? 'Clockwise to '
        : $dir eq 'CC' ? 'Counterclockwise to '
        : 'To '
    ) . $destination;

} ## tidy end: sub destination_of

my %description_of;

sub add_descriptions :Export{
    
    my $routedir = shift;
    my @placelists = @_;
    
    load_timepoint_data() unless $timepoint_data;

        my %relevant_places = relevant_places(@placelists);

        while ( my ( $placelist, $relevant ) = each %relevant_places ) {

            my @descriptions;
            foreach my $place ( sk($relevant) ) {
                my $row = $timepoint_data->rows_where( 'Abbrev4', $place );
                $row = $timepoint_data->hashrow($row);
                push @descriptions, $row->{TPName};
            }

            $description_of{$routedir}{$placelist}
              = join( ' -> ', @descriptions );

        }

    return;

} ## tidy end: sub build_placelist_descriptions

sub description_of {
    my ( $routedir, $placelist ) = @_;
    return $description_of{$routedir}{$placelist};
}

1;