package Octium::Sked::StopSkedCollection 0.015;

use Actium 'class';

has _stopskeds_r => (
    traits   => ['Array'],
    is       => 'bare',
    init_arg => 'stopskeds',
    isa      => 'ArrayRef[Octium::Sked::StopSked]',
    required => 1,
    handles  => { stopskeds => 'elements', },
);

method _build_stopskeds_of_stopids_r {
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

method stopskeds_of_stopid (Str $stopid) {
    return () if not $self->_has_stopskeds_of_stopid;
    return $self->_stopskeds_of_stopid_r($stopid)->@*;
}

method store ($folder) {
    my $count     = 0;
    my @stopskeds = $self->stopskeds;
    @stopskeds = @stopskeds[ 0 .. 99 ];
    $folder->write_files_with_method(
        OBJECTS   => \@stopskeds,
        METHOD    => 'dump',
        EXTENSION => 'dump',
        SUBFOLDER => 'dumped',
    );
    return;
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

=head1 ATTRIBUTE

=head2 stopskeds

An array of L<Octium::Sked::StopSked|Octium::Sked::StopSked> objects. 
The "stopskeds" argument in the constructor should be a reference to
the array, while the stopskeds() method will return the list.

=head1 METHOD

=head2 stopids

Returns a list of the stop IDs associated with the stop schedules.

=head2 stopskeds_of_stopid($stopid)

Takes a stop ID and returns the associated StopSked objects of that
stop ID.

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

