package Actium::Storage::Ini 0.015;
# vimcolor: #FFCCCC

use Actium        ('class');
use Actium::Types ('File');

use MooseX::SingleArg;
single_arg 'file';

# Class for reading .ini files.
# At the moment, and possibly permanently, a thin wrapper around
# Config::Tiny, but could be more later. Maybe.

use Config::Tiny;    ### DEP ###

has 'file' => (
    isa    => File,
    reader => '_file',
    coerce => 1,
);

has '_values_r' => (
    is      => 'ro',
    isa     => 'HashRef[HashRef[Str]]',
    lazy    => 1,
    builder => '_build_values',
);

method BUILD {
    $self->sections;
    # that could be anything that runs _build_values
    # I wanted to just not make _values_r lazy, but it depends on _file
}

method _build_values {
    if ( not $self->_file->exists ) {
        my $empty_hoh = +{ '_' => +{} };
        return $empty_hoh;
    }
    my $string = $self->_file->slurp_text;
    my $config = Config::Tiny::->read_string($string);
    if ( not defined $config ) {
        my $errstr = Config::Tiny::->errstr;
        $errstr = 'Unknown error' if not defined $errstr or $errstr eq $EMPTY;
        croak __PACKAGE__ . ': ' . $errstr;
    }
    my $ini_hoh = { %{$config} };
    # shallow clone, in order to get an unblessed copy
    return $ini_hoh;
}

method value ( :$section = '_' , :$key!  ) {
    my $ini_hoh = $self->_values_r;
    return $ini_hoh->{$section}{$key};
}

method section ( $section = '_' ) {
    my $ini_hoh = $self->_values_r;
    if ( exists $ini_hoh->{$section} ) {
        return wantarray ? %{ $ini_hoh->{$section} } : $ini_hoh->{$section};
    }
    return;
}

method sections {
    my $ini_hoh = $self->_values_r;
    return sort keys %{$ini_hoh};
}

1;

__END__

=encoding utf8

=head1 NAME

Actium::Storage::Ini - Configuration using .ini files

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use Actium::Storage::Ini;
 my $ini = Actium::Storage::Ini->new('/path/to/file');

 my @sections = $ini->sections;
 my %values_of_section = $ini->section($sections[0]);
 my $value = $ini->value(section => $section[1], key => 'key');

=head1 DESCRIPTION

Actium::Storage::Ini provides methods to access the values from .ini
files. It is a thin wrapper around L<Config::Tiny|Config::Tiny>. See
that module for more information about how the files are processed.

=head1 CONSTRUCTION

Pass a file specification, either as a string or as an
Actium::Storage::File object, to the class method "new."

 Actium::Storage::Ini->new('/any/file/path');

=head1 METHODS 

=head2 section

 my $hashref = $ini->section();
 my %hash = $ini->section('sectionname');

Returns the entire section of the .ini file.  Returns a list of keys
and values (in list context), or a reference to a hash (in scalar
context).  If no section name is passed as an argument, returns the
section '_'.

If the section doesn't exist, returns nothing (in list context), or
undef (in scalar context).

=head2 sections

 my @sections = $ini->sections;

Returns the list of sections in the file.

=head2 value

 my $value = value ( section => 'section name', key => 'key name');

Returns a single value.  Accepts two named parameters: 'key' (which is
mandatory' and 'section' (which, if not supplied, defaults to '_').

=head1 DIAGNOSTICS

If any error is found from Config::Tiny, it will croak. See that module
for specific errors.

=head1 DEPENDENCIES

=over

=item * 

Actium

=item *

Config::Tiny

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2014-2018

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

