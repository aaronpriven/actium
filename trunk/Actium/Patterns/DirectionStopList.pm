#!/ActivePerl/bin/perl

#/Actium/Patterns/DirectionStopList.pm

# Subversion: $Id$

# legacy stage 4

# This is only supposed to be used inside MakeStopLists.pm

use 5.012;
use warnings;

package Actium::Patterns::DirectionStopList 0.001;

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
  return join('-' , $self->route , $self->dir);
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
