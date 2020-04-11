package Octium::Points::BTime 0.013;

# object for a single time in a box in a 2019 InDesign point schedule

use Actium('class');
use Octium;
use Octium::Types(qw/ActiumTime/);

has actiumdb => (
    is       => 'ro',
    isa      => 'Octium::Files::ActiumDB',
    required => 1,
);

has timeobj => (
    isa      => ActiumTime,
    is       => 'ro',
    init_arg => 'time',
    required => 1,
    coerce   => 1,
    handles  => [qw/timenum ap/]
);

method timesort (@objects) {
    Actium::Time->timesort(@objects);
}

has [qw/desttp4 line/] => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has [qw/place exception/] => (
    isa      => 'Maybe[Str]',
    is       => 'ro',
    required => 1,
);

has approxflag => (
    isa     => 'Bool',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_approxflag',
);

method _build_approxflag {
    return $self->place ? 0 : 1;
}

has destination => (
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_destination',
);

method _build_destination {
    my $tp4         = $self->desttp4;
    my $destination = $self->actiumdb->destination_or_warn($tp4);
}

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

