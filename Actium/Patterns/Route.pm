#!/ActivePerl/bin/perl

#/Actium/Patterns/Route.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Patterns::Route 0.001;

use Moose;
use MooseX::StrictConstructor;

use Actium::Union('ordered_union');
use Actium::Util('positional');

use Array::Transpose;

around BUILDARGS => sub {
    return positional( \@_, 'route' , 'patterns_r' );
};

has 'route' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

sub id {
   my $self = shift;
   return $self->route;
}

has 'patterns_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::Patterns::Pattern]',
    default => sub { [] },
    traits  => ['Array'],
    handles => { patterns => 'elements', },
);

has 'dir_obj_of' => (
    is      => 'bare',
    traits  => ['Hash'],
    isa     => 'HashRef[Actium::Sked::Dir]',
    builder => '_build_dir_objs_of',
    lazy    => 1,
    handles => {
        _unsorted_dircodes      => 'keys',
        dir_obj_of    => 'get',
        dir_objs      => 'values',
        has_direction => 'exists',
    },
);

sub dircodes {
    my $self = shift;
    my @objs = $self->dir_objs;
    my %sortable_of = map { $_->dircode, $_->as_sortable } @objs;
    my @dircodes = sort {$sortable_of{$a} cmp $sortable_of{$b}} keys %sortable_of;
    return @dircodes;
}

sub _build_dir_objs_of {
    my $self = shift;
    my %dir_obj_of;
    foreach my $pattern ( $self->patterns ) {
        my $dir_obj = $pattern->dir_obj;
        my $dircode = $dir_obj->dircode;
        $dir_obj_of{$dircode} = $dir_obj;
    }
    return \%dir_obj_of;
}

# $hashref->{placelist}->[0..n]

has 'pattern_of_placelist_r' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Actium::Patterns::Pattern]]',
    builder => '_build_pattern_of_placelist_r',
    lazy    => 1,
    traits  => ['Hash'],
    handles => {
        _pattern_list_of_placelist_r     => 'get',
        _set_pattern_list_of_placelist_r => 'set',
        has_placelist                    => 'exists',
        placelists                       => 'keys',
    },
);

sub _build_pattern_of_placelist_r {
    my $self = shift;
    my %patterns_of;
    foreach my $pattern ( $self->patterns ) {
        push @{ $patterns_of{ $pattern->placelist } }, $pattern;
    }
    return \%patterns_of;
}

sub patterns_of_placelist {
    my $self      = shift;
    my $placelist = shift;
    return @{ $self->_pattern_list_of_placelist_r($placelist) };
}

has 'pattern_of_dir_r' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Actium::Patterns::Pattern]]',
    builder => '_build_pattern_of_dir_r',
    lazy    => 1,
    traits  => ['Hash'],
    handles => {
        _pattern_list_of_dir_r     => 'get',
        _set_pattern_list_of_dir_r => 'set',
    },
);

sub _build_pattern_of_dir_r {
    my $self = shift;
    my %patterns_of;
    foreach my $pattern ( $self->patterns ) {
        push @{ $patterns_of{ $pattern->dircode } }, $pattern;
    }
    return \%patterns_of;
}

sub patterns_of_dir {
    my $self = shift;
    my $dir  = shift;
    return @{ $self->_pattern_list_of_dir_r($dir) };
}

has stops_of_dir_r => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]]',
    builder => '_build_stops_of_dir',
    traits  => ['Hash'],
    handles => { _stops_of_dir_r => 'get', 
                _stoplists_by_dir => 'kv' ,
    },
);

sub stops_of_dir {
   my $self = shift;
   my $dir = shift;
   return @{ $self->_stops_of_dir_r($dir)};
}

sub _build_stops_of_dir {
    my $self = shift;
    my %stops_of_dir;
    foreach my $dircode ( $self->_unsorted_dircodes ) {
        my @stoplist_rs = map { [ $_->stops ] }
          $self->patterns_of_dir($dircode);
        $stops_of_dir{$dircode} = ordered_union(@stoplist_rs);
    }
    return \%stops_of_dir;
}

has stoplist_r => (
   is => 'bare',
   isa => 'ArrayRef[ArrayRef[Str]]' ,
   traits => ['Array'],
   builder => '_build_stoplist_r',
   lazy => 1,
   handles => {stoplist => 'elements' },
);
   
=for comment

"stoplist" returns a matrix as follows:

 [
  [ stop_id, marker],
  [ stop_id, marker],
  ...
 ]
   
The marker is either < for the first direction only, > for the second 
direction only, or nothing for both directions.

=cut
    
sub _build_stoplist_r {
  my $self = shift;
  my @dircodes = $self->dircodes; # sorted
  my @lists = map { [ $_ , $self->stops_of_dir($_) ] } @dircodes; 
  
  my ($union_r, $markers_r) = comm($lists[0][1] , $lists[1][1]);
  # so in the markers, < is always the first direction when sorted, and 
  # > always the second
  
  my @stoplist_items = Array::Transpose::transpose([$union_r , $markers_r]);
  
  return \@stoplist_items; 
  
}

# the usual lists we publish like that use shading for different patterns
# (e.g., short turns). Might want to think about that.

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
