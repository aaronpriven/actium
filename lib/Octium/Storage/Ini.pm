package Octium::Storage::Ini 0.011;

# Class for reading .ini files.
# At the moment, and possibly permanently, a thin wrapper around
# Config::Tiny, but could be more later. Maybe.

use Actium ('class');
use Octium;
use Octium::Types ('ActiumFolderLike');

use File::HomeDir;    ### DEP ###
use Config::Tiny;     ### DEP ###

around BUILDARGS ($orig, $class : slurpy @ ) {

    my %args;

    # one arg, hashref: args are in hashref
    # one arg, not hashref: one arg is filename
    # more than one arg: args are hash

    if ( @_ == 1 ) {
        if ( Actium::reftype $_[0] and Actium::reftype $_[0] eq 'HASH' ) {
            %args = %{ $_[0] };
        }
        else {
            %args = ( filename => $_[0] );
        }
    }
    else {
        %args = (@_);
    }

    #$args{folder} //= $ENV{HOME};
    $args{folder} //= File::HomeDir::->my_home;

    return $class->$orig(%args);

}    ## tidy end: around BUILDARGS

has 'filename' => (
    isa => 'Str',
    is  => 'ro',
);

has 'folder' => (
    isa    => ActiumFolderLike,
    is     => 'ro',
    coerce => 1,
);

has 'filespec' => (
    is       => 'ro',
    init_arg => undef,
    builder  => '_build_filespec',
    lazy     => 1,
);

sub _build_filespec {
    my $self     = shift;
    my $folder   = $self->folder;
    my $filespec = $folder->make_filespec( $self->filename );
    return $filespec;
}

has '_values_r' => (
    is      => 'ro',
    isa     => 'HashRef[HashRef[Str]]',
    lazy    => 1,
    builder => '_build_values',
);

sub _build_values {
    my $self   = shift;
    my $config = Config::Tiny::->read( $self->filespec );
    if ( not defined $config ) {
        my $errstr = Config::Tiny::->errstr;
        if ( $errstr =~ /does not exist/i or $errstr =~ /no such file/i ) {
            return +{ '_' => +{} };
        }
        croak $errstr;
    }
    my $ini_hoh = { %{$config} };
    # shallow clone, in order to get an unblessed copy
    return $ini_hoh;
}

method value ( :$section = '_' , :$key!  ) {

    my $ini_hoh = $self->_values_r;
    return $ini_hoh->{$section}{$key};
}

sub section {
    my $self    = shift;
    my $section = shift // '_';
    my $ini_hoh = $self->_values_r;
    if ( exists $ini_hoh->{$section} ) {
        return wantarray ? %{ $ini_hoh->{$section} } : $ini_hoh->{$section};
    }
    return;
}

sub sections {
    my $self    = shift;
    my $ini_hoh = $self->_values_r;
    return keys %{$ini_hoh};
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

=head1 BUGS

Sections and keys are case-sensitive.


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

