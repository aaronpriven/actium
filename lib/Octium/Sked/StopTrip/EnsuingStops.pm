package Octium::Sked::StopTrip::EnsuingStops 0.015;
# vimcolor: #132600

# The subsequent stops, after the one represented by a StopTrip

use Actium 'class';
use Types::Standard (qw/ArrayRef Maybe Str/);
*Moose::Object::_octium_sked_stoptrip_ensuingstops_new = \&Moose::Object::new;

has _stopids_r => (
    required => 1,
    isa      => ArrayRef [ Maybe [Str] ],
    is       => 'bare',
    init_arg => 'stopids',
    traits   => ['Array'],
    handles  => {
        stopids       => 'elements',
        is_final_stop => 'is_empty'
    },
);

const my $JOINER => "\N{UNIT SEPARATOR}";

my %obj_cache;

override new ( Str @stopids is ref_alias) {
    my $cachekey = join( $JOINER, @stopids );
    return $obj_cache{$cachekey}
      //= $self->_octium_sked_stoptrip_ensuingstops_new(
        { stopids => \@stopids } );
}

Actium::immut( constructor_name => '_octium_sked_stoptrip_ensuingstops_new' );

1;

__END__

=encoding utf8

=head1 NAME

Octium::Sked::StopTrip::EnsuingStops - subsequent stops of a trip in a
stop schedule

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use Octium::Sked::StopTrip::EnsuingStops;
 my $ensuingstops = 
    Octium::Sked::StopTrip::EnsuingStops->new(qw/55555 51038 52382/);

=head1 DESCRIPTION

A stop schedule represents a transit schedule at a particular stop. But
one doesn't just want to show the time -- it's also desirable to show
the destination and other information about where that bus is going.
Hence, it's important to store information about the subsequent stops
on the trip. This object stores those subsequent stops. Note that order
is significant here.

Octium::Sked::StopTrip::EnsuingStops caches its objects, so that
passing the same stops will result in another reference to the same
object. This is useful for determining equality of the two sets of
ensuing stops.

 my $ensuingstops1 = 
    Octium::Sked::StopTrip::EnsuingStops->new(qw/55555 51038 52382/);
 my $ensuingstops2 = 
    Octium::Sked::StopTrip::EnsuingStops->new(qw/55555 51038 52382/);
 say "Yes" if $ensuingstops1 == $ensuingstops2;
 # Output: Yes

=head1 CLASS METHOD

=head2 Octium::Sked::StopTrip::EnsuingStops->new(@stopids)

The C<new> method takes a list of stop IDs, determines whether an
object with those stops already exists, and if it does, returns it. If
it doesn't, it creates a new one.

=head1 OBJECT METHOD

=head2 $ensuingstops->stopids

The C<stopids> method returns the list of stop IDs.

=head2 $ensuingstops->is_final_stop

The C<is_final_stop> method indicates that the stop is the final one
(in other words, that there are no stop IDs in the ensuingstops).

=head1 DIAGNOSTICS

None specific to this module, but see L<Actium|Actium> and
L<Moose|Moose>.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

The Actium system.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues|https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2020

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
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

