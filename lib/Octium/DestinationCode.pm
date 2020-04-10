package Octium::DestinationCode 0.012;

use Actium ('class');
use Octium;

const my $JSON_FILE => 'destcodes.json';

has '_destination_code_of_r' => (
    is       => 'ro',
    init_arg => 'destination_code_of',
    isa      => 'HashRef[Str]',
    traits   => ['Hash'],
    default  => sub { {} },
    handles  => {
        _set_code_of => 'set',
        _get_code_of => 'get',
        _codes       => 'values',
    },
);

has '_folder' => (
    is       => 'ro',
    isa      => 'Octium::Folder',
    init_arg => 'folder',
);

sub load {
    my $class        = shift;
    my $commonfolder = shift;

    my %destination_code_of = $commonfolder->json_retrieve($JSON_FILE)->%*;

    return $class->new(
        destination_code_of => \%destination_code_of,
        folder              => $commonfolder,
    );

}

sub store {
    my $self = shift;

    \my %destination_code_of = $self->_destination_code_of_r;
    my $folder = $self->_folder;

    my $filespec = $folder->make_filespec($JSON_FILE);

    rename $filespec, "$filespec.bak";

    $folder->json_store_pretty( \%destination_code_of, $JSON_FILE );

}

sub code_of {

    my $self = shift;
    my $dest = shift;

    my $code = $self->_get_code_of($dest);

    if ( not defined $code ) {
        $code = $self->_highest_code;
        $code++;    # magic increment
        $self->_set_code_of( $dest => $code );
    }

    return $code;

}

sub _highest_code {
    my $self = shift;
    \my %destination_code_of = $self->_destination_code_of_r;

    my @sorted_codes
      = sort { length($b) <=> length($a) || $b cmp $a } $self->_codes;

    return $sorted_codes[0];

}

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

