package Actium::O::Sked::Stop::Time 0.012;

# the stop time object, containing all the info for each time of a schedule

use 5.016;
use strict;

use Moose;    ### DEP ###
#use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;    ### DEP ###
use Actium::O::Days;
use Actium::Constants;

use namespace::autoclean;            ### DEP ###

use MooseX::Storage;                 ### DEP ###
with Storage( traits => ['OnlyWhenBuilt'] );

use Actium::Types qw(Str4 TimeNum ActiumDays);

has [qw(origin destination follower previous)] => (
    is       => 'ro',
    isa      => Str4,
    required => 1,
);

has at_place => (
    is      => 'bare',
    isa     => Str4,
    lazy    => 1,
    builder => '_build_at_place',
);

sub _build_at_place {
    my $self     = shift;
    my $previous = $self->previous;
    my $follower = $self->follower;

    return $previous eq $follower ? $previous : $EMPTY;

}

has line => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has days_obj => (
    required => 1,
    coerce   => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumDays,
    handles  => {
        daycode       => 'daycode',
        schooldaycode => 'schooldaycode',
        sortable_days => 'as_sortable',
    },
);

has 'time' => (
    is       => 'ro',
    isa      => TimeNum,
    coerce   => 1,
    required => 1,
);

has stop_index => (
    is  => 'ro',
    isa => 'Int',
);

my $kpoint_timestr_sub = Actium::Time::timestr_sub( SEPARATOR => '', XB => 1 );

sub for_kpoint {
    my $self = shift;

    my @kpoint_time = $kpoint_timestr_sub->( $self->time ), $self->line,
      $self->destination, $self->place, $self->daysexc

}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

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

