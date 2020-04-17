package Octium::Sked::StopSkedCollection 0.015;
# vimcolor: #c8d8b8

use Actium 'class';
use Actium::Types('Folder');

has _stopskeds_r => (
    traits   => ['Array'],
    is       => 'bare',
    init_arg => 'stopskeds',
    isa      => 'ArrayRef[Octium::Sked::StopSked]',
    required => 1,
    handles  => { stopskeds => 'elements', },
);

method _build_stopskeds_of_stopid_r {
    my %stopskeds_of_stopid;
    foreach my $stopsked ( $self->stopskeds ) {
        my $stopid = $stopsked->stopid;
        push $stopskeds_of_stopid{$stopid}->@*, $stopsked;
    }
    return \%stopskeds_of_stopid;
}

has _stopskeds_of_stopid_r => (
    lazy    => 1,
    builder => 1,
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Octium::Sked::StopSked]]',
    handles => {
        stopids                  => 'keys',
        _has_stopskeds_of_stopid => 'exists',
        _stopskeds_of_stopid_r   => 'get',
    },
);

has first_stopid => (
    lazy     => 1,
    builder  => 1,
    is       => 'ro',
    init_arg => undef,
);

method _build_first_stopid {
    my @sorted = sort $self->stopids;
    return $sorted[0];
}

method stopskeds_of_stopid (Str $stopid) {
    return () if not $self->_has_stopskeds_of_stopid;
    return $self->_stopskeds_of_stopid_r($stopid)->@*;
}

method writedumped (Folder $folder does coerce) {
    my $stopids = join( "_", sort $self->stopids );
    # there may be more than one collection with the same stop IDs in which
    # case this will write over one of them
    env->crier->over($stopids);
    my $file = $folder->file( $stopids . '.dump' );
    local $Data::Dumper::Indent = 1;
    $file->spew_text( $self->dump );
    return;
}

method store_bundled (Folder $folder does coerce) {
    my $stopids = join( "_", sort $self->stopids );
    env->crier->over($stopids);
    my $file = $folder->file( $stopids . '.json' );
    $file->spew_text( JSON->new->pretty->canonical->encode( $self->bundle ) );
}

method bundle {
    return [ map { $_->bundle } $self->stopskeds ];
}

method unbundle (ArrayRef $bundle ) {
    my $stopskeds_r = map { $_->unbundle } $bundle->@*;
    return $self->new( stopskeds => $stopskeds_r );
}

1;

__END__

=encoding utf8

=head1 NAME

Octium::Sked::StopSkedCollection -  Object representing schedule info
for a particular bus stop or group of bus stops

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use Octium::Sked::StopSkedCollection;
 # do something with Octium::Sked::StopSkedCollection
   
=head1 DESCRIPTION

This represents schedule information for a particular bus stop or group
of bus stops.

=head1 CLASS METHODS

=head2 new(...)

The module inherits its constructor from Moose.

=head2 unbundle($string)

The C<unbundle> method takes a structure created by the C<bundle>
method and returns a recreated object.

=head1 ATTRIBUTE

=head2 stopskeds

An array of L<Octium::Sked::StopSked|Octium::Sked::StopSked> objects. 
The "stopskeds" argument in the constructor should be a reference to
the array, while the stopskeds() method will return the list.

=head1 OBJECT METHODS

=head2 stopids

Returns a list of the stop IDs associated with the stop schedules.

=head2 stopskeds_of_stopid($stopid)

Takes a stop ID and returns the associated StopSked objects of that
stop ID.

=head2 bundle

This returns a struct which, when passed to the C<unbundle> class
method, will recreate the object.

=head1 DIAGNOSTICS

None specific to this class.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

The Actium system.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * 

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item * 

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

