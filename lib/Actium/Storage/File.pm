package Actium::Storage::File 0.014;

# Objects representing files on disk
# A module adding methods (nothing else) to Path::Class::File

use Actium;
use Kavorka ('method');
use Path::Class();
use parent ('Path::Class::File');

=encoding utf8

=head1 NAME

Actium::Storage::File - File objects for the Actium system

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Actium::Storage::File (qw/file/);
 
 $file = file('/path/to/file');

or, equivalently,

 $file = Actium::Storage::File->new('/path/to/file');

=head1 DESCRIPTION

Actium::Storage::File provides an object-oriented interface to files on
disk.

It only adds methods to the L<Path::Class::File|Path::Class::File>
module  from CPAN.  All methods in Path::Class::File are supported by
this module, and readers should look at Path::Class::File for complete
documentation on it.

=cut

=head1 CLASS METHOD

=head3 file_class

Returns the class which is used to create folder objects: 
Actium::Storage::Folder.

=cut

method dir_class {'Actium::Storage::Folder'}

=head1 OBJECT METHODS

=head2 Folders and Files

=head3 exists

Returns a boolean value: true if there is actually a file on the file
system associated with this object.

=cut

method exists {
    return ( -e $self and not -d _ );
}

=head3 folder

Returns a Actium::Storage::Folder object representing the folder 
containing this file.

=cut

method folder {
    # enclosing folder
    return $self->dir;
}

=head3 is_folder

Returns a boolean value indicating whether this object represents a
folder. Actium::Storage::Folder objects always return true, and
Actium::Storage::File  objects always return false.

=cut

method is_folder {
    return 0;
}

=head2 Storing and Retrieving Data

A number of methods exist to store and retrieve data in various
formats,  from the file represented by the object.

=head3 json_retrieve()

This method retrieves data stored in JSON format.

=cut

method json_retrieve {
    my $basename  = $self->basename;
    my $cry       = cry("Retrieving JSON file $basename");
    my $json_text = $self->slurp_utf8;
    require JSON;    ### DEP ###
    my $data_r = JSON::from_json($json_text);
    $cry->done;
    return $data_r;
}

=head3 json_store(I<reference>)

This method stores data in JSON format. It takes a single argument, a
reference to a data structure, which is passed to the JSON module.

=cut

method json_store ($data_r!) {
    my $basename = $self->basename;
    my $cry      = cry("Storing JSON file $basename...");
    require JSON;    ### DEP ###
    my $json_text = JSON::to_json( $data_r, { pretty => 1, canonical => 1 } );
    my $result = $self->spew_utf8($json_text);
    $cry->done;
    return $result;
}

=head3 retrieve()

This method retrieves data stored in Perl's Storable format.

=cut

method retrieve {
    my $basename = $self->basename;
    my $cry      = cry("Retrieving $basename");
    require Storable;
    my $data_r = Storable::retrieve($self);
    unless ($data_r) {
        $cry->d_error();
        croak "Can't retreive $self: $!";
    }
    $cry->done;
    return $data_r;
}

=head3 sheet_retrieve

This method uses L<the new_from_file method of 
Actium::O::2DArray|Actium::O::2DArray/new_from_file> to retrieve data
stored in XLSX format.

=cut

method sheet_retrieve {
    my $basename = $self->basename;
    my $cry      = cry("Retrieving XLSX file $basename");

    require Actium::O::2DArray;
    my $sheet = Actium::O::2DArray::->new_from_file($self);

    $cry->done;
    return $sheet;
}

=head3 store(I<reference>)

This method stores data in Perl's Storable format. It takes a single
argument, a reference to a data structure, which is passed to L<the
nstore function in  the Storable module|Storable/nstore>.

=cut

method store ($data_r ) {
    my $basename = $self->basename;
    my $cry      = cry("Storing $basename...");
    require Storable;
    my $result = Storable::nstore( $data_r, $self );
    unless ($result) {
        $cry->d_error;
        croak "Can't store $self: $!";
    }
    $cry->done;
    return $result;
}

=head2 Reading and Writing Whole Files

=head3 slurp_utf8(...)

This is just like L<slurp from
Path::Class::File|Path::Class::File/slurp>, but sets the encoding to
strict UTF-8.  Any arguments are passed through to the slurp method.

=cut

method slurp_utf8 {
    return $self->slurp( iomode => '<:encoding(UTF−8)', @_ );
}

=head3 spew_utf8

This is just like L<spew from
Path::Class::File|Path::Class::File/spew>, but sets the encoding to
strict UTF-8.  Any arguments are passed through to the spew method.

=cut

method spew_utf8 {
    return $self->spew( { iomode => '>:encoding(UTF-8)' }, @_ );
}

=head3 spew_from_method

This routine takes an arbitrary object, takes the result of an object
method applied to it, and saves that result to the file represented by
the Actium::Storage::File object. It takes named arguments, as follows:

=over

=item object

An object. The object must implement the method passed in the C<method>
 argument.

=item method

The name of a method the object is to perform. The results are saved in
the file.

Also, this name is used to determine the I/O layers used on the file. 
The routine looks to see whether a method  "METHOD_layers" is
implemented on the object (e.g., for a method "spaced",  it looks for
the additional method "spaced_layers"). If that method exists, it is
called, and the return value is passed to perl's binmode function. See
L<perlfunc/binmode>.

=item args

A reference to an array. This array is passed through as the arguments
to the method generating the data. If not specified, will use no
arguments.

=item do_cry

If present and set to a false value, will omit the terminal status
display, which uses Actium::O::Crier. If not present, will display the
status.

=back

=cut

method spew_from_method ( :$object!, :$method!, :\@args = [], Bool :$do_cry = 1 ) {

    my $basename = $self->basename;
    my $cry;
    if ($do_cry) {
        $cry = cry("Writing results of $method to $basename");
    }

    my $result = $object->$method(@args);

    my $layermethod = $method . '_layers';
    if ( $object->can($layermethod) ) {
        $self->spew( { iomode => '>' . $object->$layermethod }, $result );
    }
    else {
        $self->spew_utf8($result);
    }
    $cry->done if $do_cry;
    return;

} ## tidy end: method exists2

### OPEN ###

=head2 Opening Files

There are a number of methods that provide shortcuts to opening files
in particular modes and encodings.   These croak if an error occurs.

head3 openr_raw

Opens the file with mode '<:raw' (raw input).

=cut

method openr_raw {
    my $fh = $self->open('<:raw') or croak "Can't read $self: $!";
    return $fh;
}

=head3 openr_utf8

Opens the file with mode '<:encoding(UTF-8)' (UTF-8 input).

=cut

method openr_utf8 {
    my $fh = $self->open('<:encoding(UTF-8)') or croak "Can't read $self: $!";
    return $fh;
}

=head3 openw_raw

Opens the file with mode '>:raw' (raw output).

=cut

method openw_raw {
    my $fh = $self->open('>:raw') or croak "Can't write $self: $!";
    return $fh;
}

=head3 openw_utf8

Opens the file with mode '>:encoding(UTF-8)' (UTF-8 output).

=cut

method openw_utf8 {
    my $fh = $self->open('>:encoding(UTF-8)') or croak "Can't write $self: $!";
    return $fh;
}

# Actium::O::Folder equivalents -- see list in Actium::Storage::Folder

1;

__END__

=head1 DIAGNOSTICS

=over 

=item Can't store I<file>: I<error>

An input/output error occurred while attempting to retrieve a Storable
file.

=item Can't store I<file>: I<error>

An input/output error occurred while attempting to store a Storable
file.

=item Can't read I<file>: I<error>

An input/output error occurred while attempting to open a  file using
C<openr_utf8> or C<openr_raw>.

=item Can't write I<file>: I<error>

An input/output error occurred while attempting to write a  file using
C<openw_utf8> or C<openw_raw>.

=back

=head1 DEPENDENCIES

=over

=item Actium

=item Kavorka

=item Path::Class

=back

The following are loaded only when necessary:

=over

=item Actium::O::2DArray

=item JSON

=item Storable

=back

=head1 SEE ALSO

L<< B<file> from Actium|Actium/file >>

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it
under  the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

