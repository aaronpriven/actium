#!/ActivePerl/bin/perl

#/Actium/O/Stoplists/ByDirection.pm

# legacy stage 4

package Actium::O::Stoplists::ByDirection 0.010;

use Moose; ### DEP ###
use MooseX::StrictConstructor; ### DEP ###

use namespace::autoclean; ### DEP ###

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
    is       => 'bare',
    isa      => 'HashRef[Str]',
    traits   => ['Hash'],
    handles  => { description_of => 'get', },
);

has 'id' => (
    is      => 'ro',
    builder => '_build_id',
    lazy    => 1,
);

sub _build_id {
    my $self = shift;
    return join( q{-}, $self->route, $self->dir );
}

sub textlist {
    my $self    = shift;
    my @stops   = $self->stops;
    my @results = map { "$_\t" . $self->description_of($_) } @stops;
    return join( "\n", $self->id, @results ) . "\n";
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__
