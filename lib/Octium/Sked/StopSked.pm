package Octium::Sked::StopSked 0.014;

use Octium 'class';

use Octium::Types (qw/DirCode ActiumDir ActiumDays/);

has dir_obj => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumDir,
    handles  => {
        direction                       => 'dircode',
        dircode                         => 'dircode',
        to_text                         => 'as_to_text',
        should_preserve_direction_order => 'should_preserve_direction_order',
    },
);

has linegroup => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has days_obj => (
    required => 1,
    coerce   => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumDays,
    handles  => {
        daycode       => 'daycode',
        sortable_days => 'as_sortable',
    },
);

has is_last_stop => (
    default => 0,
    isa     => 'Bool',
    traits  => ['Bool'],
    is      => 'ro',
    handles => ( make_last_stop => 'set' ),
);

has is_dropoff_only => (
    default => 0,
    isa     => 'Bool',
    traits  => ['Bool'],
    is      => 'ro',
    handles => ( make_dropoff_only => 'set' ),
);

has _trips_r => (
    required => 1,
    isa      => 'ArrayRef[Octium::Sked::StopSked::Trip]',
    is       => 'bare',
    init_arg => 'trips',
    traits   => ['Array'],
    handles  => ( 'trips' => 'elements' ),
);

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS or ATTRIBUTES

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

=item * 

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item * 

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

