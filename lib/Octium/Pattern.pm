package Octium::Pattern 0.012;

# used by Xhea:::ToSkeds

use Actium ('class');
use Octium;

use Actium::Types (qw/Dir/);
use Actium::Dir;
use Octium::Pattern::Stop;

has [ 'line', 'linegroup' ] => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has [qw/vdc via/] => ( is => 'ro', );

for (qw/linedir lgdir/) {
    has $_ => (
        is      => 'ro',
        lazy    => 1,
        builder => "_build_$_",
        isa     => 'Str',
    );
}

sub _build_lgdir {
    my $self = shift;
    return $self->linegroup . '.' . $self->dircode;
}

sub _build_linedir {
    my $self = shift;
    return $self->line . '.' . $self->dircode;
}

has 'dir_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => Dir,
    handles  => ['dircode'],
);

has 'identifier' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'unique_id' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_unique_id',
);

sub id {
    my $self = shift;
    return $self->unique_id;
}

sub _build_unique_id {
    my $self = shift;
    return join( '.', $self->line, $self->identifier );
}

#has 'place_objs_r' => (
#    is      => 'rw',
#    writer  => '_set_place_obj_r',
#    isa     => 'ArrayRef[Octium::Pattern::Place]',
#    default => sub { [] },
#    traits  => ['Array'],
#    handles =>
#      { place_objs => 'elements', 'place_obj' => 'get', place_count => 'count',
#          set_place_obj => 'set', },
#);

has 'stop_objs_r' => (
    is      => 'rw',
    writer  => '_set_stops_obj_r',
    isa     => 'ArrayRef[Octium::Pattern::Stop]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        stop_objs    => 'elements',
        'stop_obj'   => 'get',
        stop_count   => 'count',
        set_stop_obj => 'set',
    },
);

has 'trip_objs_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Octium::Pattern::Trip]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        trip_count => 'count',
        trips      => 'elements',
        add_trip   => 'push',
    },
);

#sub add_trip {
#    my $self = shift;
#    my $trip = shift;
#    \my %place_neue_of = shift;
#
#    $self->_push_trip($trip);
#
#    unless ( $self->trip_count ) {
#        my @trip_stop_objs = $trip->stop_objs;
#        my @stop_objs;
#
#        foreach my $trip_stop_obj (@trip_stop_objs) {
#            my %place_info;
#            if ( $trip_stop_obj->has_place ) {
#                my $place     = $trip_stop_obj->tstp_place;
#                my $ref_place = $place_neue_of{$place}{h_plc_reference_place};
#                %place_info = (
#                    tstp_place => $place,
#                    ref_place  => $place_neue_of{$place}{h_plc_reference_place},
#                    place8     => $place_neue_of{$ref_place}{h_plc_number},
#                );
#            }
#
#            push @stop_objs,
#              Octium::Pattern::Stop->new(
#                h_stp_511_id => $trip_stop_obj->h_stp_511_id,
#                %place_info
#              );
#
#        }
#
#        $self->_set_stop_objs_r( \@stop_objs );
#    } ## tidy end: unless ( $self->trip_count)
#    return;
#} ## tidy end: sub add_trip

#has 'stops_and_places_r' => (
#    is      => 'bare',
#    isa     => 'ArrayRef[Str]',
#    lazy    => 1,
#    builder => '_build_stops_places_r',
#    traits  => ['Array'],
#    handles => { stops_and_places => 'elements', },
#);
#
#sub _build_stops_places_r {
#    my $self = shift;
#    return [ map { $_->stop_and_place } $self->stop_objs ];
#}

has union_indexes_r => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    traits  => ['Array'],
    handles => { union_indexes => 'elements', union_index => 'get', },
);

Actium::immut;

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

