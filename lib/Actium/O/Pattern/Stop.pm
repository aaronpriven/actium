package Actium::O::Pattern::Stop 0.012;

use Actium ('class');

sub id {
    my $self = shift;
    return $self->stp_511_id;
}

has 'h_stp_511_id' => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has 'tstp_place' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_place',
);

has 'place_rank' => (
    is        => 'rw',
    isa       => 'Int',
    predicate => 'has_place_rank',
);

#has 'stop_and_place' => (
#    isa     => 'Str',
#    is      => 'ro',
#    lazy    => 1,
#    builder => '_build_stop_and_place',
#);

#has place_obj => (
#    is      => 'ro',
#    writer  => 'set_place_obj',
#    predicate => 'has_place_obj',
#    isa     => 'Actium::O::Pattern::Place',
#);

#sub _build_stop_and_place {
#    my $self           = shift;
#    my $stop_and_place = $self->h_stp_511_id;
#    return $stop_and_place unless $self->has_place;
#    $stop_and_place .= '|' . $self->tstp_place;
#    if ( $self->has_place_rank ) {
#        $stop_and_place .= '|' . $self->place_rank;
#    }
#    return $stop_and_place;
#}

u::immut;

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

