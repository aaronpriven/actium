package Octium::Pattern::Trip 0.012;

use Actium ('class');
use Actium::Time;

sub id {
    my $self = shift;
    return $self->int_number;
}

has 'int_number' => (
    is       => 'ro',
    required => 1,
    isa      => 'Int',
);

has [qw/days pattern_id/] => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
);

has [
    qw/schedule_daytype event_and_status op_except
      block_id vehicle_group vehicle_type /
] => (
    is  => 'ro',
    isa => 'Str',
);

has 'stoptime_r' => (
    traits  => ['Array'],
    is      => 'ro',
    writer  => '_set_stoptime_r',
    isa     => 'ArrayRef[Actium::Time]',
    default => sub { [] },
    handles => {
        set_stoptime        => 'set',
        stoptime            => 'get',
        stoptimes           => 'elements',
        stoptime_count      => 'count',
        stoptimes_are_empty => 'is_empty',
        _delete_stoptime    => 'delete',
    },
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
