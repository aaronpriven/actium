package Actium::Storage::File 0.014;
#vimcolor: #D8B8B8

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

=head3 dir_class

Returns the class which is used to create folder objects: 
Actium::Storage::Folder.

=cut

method dir_class {
    require Actium::Storage::Folder;
    return 'Actium::Storage::Folder';
}

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

=head3 remove

Like L<< I<remove> in Path::Class::File|Path::Class::File/remove >>,
but croaks on error, and returns false only if the file doesn't exist
in the first place.

=cut

method remove {
    return 0 unless -e $self;
    my $result = $self->SUPER::remove;
    return $result if $result;
    croak "Can't remove $self: $!";
}

=head3 touch

Exactly like L<< I<touch> in Path::Class::File|Path::Class::File/touch
>>, but throws an exception on failure.

=cut

method touch {
    if ( -e $self ) {
        my $result = utime undef, undef, $self;
        croak "Can't modify time of $self: $!" unless $result;
    }
    else {
        $self->openw_binary;
    }
}

=head2 Filename Manipulation

=head3 add_before_extension (I<component>)

Returns a new file object, in the same folder as the old file object.
Adds the supplied argument to the filename of the file object, prior to
the extension, separated from it by a hyphen. So:

 $file = Actium::Storage::File->new('sam.txt');
 $file->add_before_extension('fred');
 # $file is now "sam-fred.txt"

=cut

method add_before_extension ( $self : Str $addition! ) {
    my ( $filepart, $ext ) = $self->basename_ext;
    my $newfilename
      = $ext eq $EMPTY ? "$filepart-$addition" : "$filepart-$addition.$ext";
    return $self->folder->file($newfilename);
}

=head3 basename_ext

Like L<< I<basename> in Path::Class::File|Path::Class::File/basename
>>,  but returns two separate strings: the filename without extension,
and the  extension.  Neither string contains the separating period.

=cut

method basename_ext {
    my $basename = $self->basename;
    return $basename, $EMPTY unless $basename =~ /[.]/;

    my ( $filepart, $ext )
      = $basename =~ m{(.*)    # as many characters as possible
                      [.]     # a dot
                      ([^.]+) # one or more non-dot characters
                      \z}sx;
    return ( $filepart, $ext );

}

=head2 Storing and Retrieving Data

A number of methods exist to store and retrieve data in various
formats,  from the file represented by the object.

=head3 ini_retrieve()

This method retrieves data stored as an .ini file. It returns an
L<Actium::Storage::Ini|Actium::Storage::Ini> object.

=cut

method ini_retrieve {
    require Actium::Storage::Ini;
    return Actium::Storage::Ini->new($self);
}

=head3 json_retrieve()

This method retrieves data stored in JSON format.

=cut

method json_retrieve {
    my $basename  = $self->basename;
    my $cry       = env->cry("Retrieving JSON file $basename");
    my $json_text = $self->slurp_text;
    require JSON;    ### DEP ###
    my $data_r = JSON::from_json($json_text);
    $cry->done;
    return $data_r;
}

=head3 json_store(I<reference>)

This method stores data in JSON format. It takes a single argument, a
reference to a data structure, which is passed to the JSON module.

=cut

method json_store ( $data_r ! ) {
    my $basename = $self->basename;
    my $cry      = env->cry("Storing JSON file $basename...");
    require JSON;    ### DEP ###
    my $json_text = JSON::to_json( $data_r, { pretty => 1, canonical => 1 } );
    my $result    = $self->spew_text($json_text);
    $cry->done;
    return $result;
}

=head3 retrieve()

This method retrieves data stored in Perl's Storable format.

=cut

method retrieve {
    my $basename = $self->basename;
    my $cry      = env->cry("Retrieving $basename");
    require Storable;
    my $data_r = Storable::retrieve($self);
    unless ($data_r) {
        $cry->error();
        croak "Can't retreive $self: $!";
    }
    $cry->done;
    return $data_r;
}

=head3 sheet_retrieve

This method uses L<the new_from_file method of 
Array::2D|Array::2D/new_from_file> to retrieve data stored in XLSX
format.

=cut

method sheet_retrieve {
    my $basename = $self->basename;
    my $cry      = env->cry("Retrieving XLSX file $basename");

    require Array::2D;
    my $sheet = Array::2D::->new_from_file( $self->stringify );

    $cry->done;
    return $sheet;
}

=head3 store(I<reference>)

This method stores data in Perl's Storable format. It takes a single
argument, a reference to a data structure, which is passed to L<the
nstore function in  the Storable module|Storable/nstore>.

=cut

method store ($data_r) {
    my $basename = $self->basename;
    my $cry      = env->cry("Storing $basename...");
    require Storable;
    my $result = Storable::nstore( $data_r, $self );
    unless ($result) {
        $cry->error;
        croak "Can't store $self: $!";
    }
    $cry->done;
    return $result;
}

=head2 Reading and Writing Whole Files

=head3 slurp_binary(...)

This is just like L<slurp from
Path::Class::File|Path::Class::File/slurp>, but sets the encoding to
raw (binary) input.  Any arguments are passed through to the slurp
method.

=cut

method slurp_binary {
    return $self->slurp( iomode => '<:raw', @_ );
}

=head3 slurp_text(...)

This is just like L<slurp from
Path::Class::File|Path::Class::File/slurp>, but sets the encoding to
strict UTF-8.  Any arguments are passed through to the slurp method.

=cut

method slurp_text {
    return $self->slurp( iomode => '<:encoding(UTF-8)', @_ );
}

=head3 spew_binary

This is just like L<spew from
Path::Class::File|Path::Class::File/spew>, but sets the encoding to raw
(binary) output.  Any arguments are passed through to the spew method.

=cut

method spew_binary {
    return $self->spew( iomode => '>:raw', @_ );
}

=head3 spew_text

This is just like L<spew from
Path::Class::File|Path::Class::File/spew>, but sets the encoding to
strict UTF-8.  Any arguments are passed through to the spew method.

=cut

method spew_text {
    return $self->spew( iomode => '>:encoding(UTF-8)', @_ );
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
display, which uses Actium::CLI::Crier. If not present, will display
the status.

=back

=cut

method spew_from_method (
    : $object !,
    : $method !,
    : \@args = [],
    Bool : $do_cry = 1
  ) {

    my $basename = $self->basename;
    my $cry;
    if ($do_cry) {
        $cry = env->cry("Writing results of $method to $basename");
    }

    my $result = $object->$method(@args);

    my $layermethod = $method . '_layers';
    if ( $object->can($layermethod) ) {
        $self->spew( iomode => '>' . $object->$layermethod, $result );
    }
    else {
        $self->spew_text($result);
    }
    $cry->done if $do_cry;
    return;

}

### OPEN ###

=head2 Opening Files

There are a number of methods that provide shortcuts to opening files
in particular modes and encodings.   These croak if an error occurs.
They return a filehandle.

=head3 open

Like L<< I<open> in Path::Class::File|Path::Class::File/open >>, but
croaks on error.

=cut

{
    no autodie;    # eliminates redefinition errors

    method open {
        my $result = $self->SUPER::open(@_);
        return $result unless not defined $result;
        croak "Can't open $self: $!";
    }
}

=head3 openr, openw, opena

These methods throw exceptions; don't call them. The equivalent methods
in Path::Class::File do not allow for an encoding; they should thus not
be used.

=cut

method openr {
    croak 'Disallowed method openr() invoked. '
      . 'Use an open() with an explicit encoding';
}

method openw {
    croak 'Disallowed method openw() invoked. '
      . 'Use an open() with an explicit encoding';
}

method opena {
    croak 'Disallowed method opena() invoked. '
      . 'Use an open() with an explicit encoding';
}

=head3 openr_binary

Opens the file with mode '<:raw' (binary input).

=cut

# I use SUPER::open below so that it gives better error messages --
# if I didn't, it would default to the "Can't open" message instead
# of giving the "Cant' read" or "Can't write" message.

method openr_binary {
    my $fh = $self->SUPER::open('<:raw') or croak "Can't read $self: $!";
    return $fh;
}

=head3 openr_text

Opens the file with mode '<:encoding(UTF-8)' (UTF-8 input).

=cut

method openr_text {
    my $fh = $self->SUPER::open('<:encoding(UTF-8)')
      or croak "Can't read $self: $!";
    return $fh;
}

=head3 openw_binary

Opens the file with mode '>:raw' (raw output).

=cut

method openw_binary {
    my $fh = $self->SUPER::open('>:raw') or croak "Can't write $self: $!";
    return $fh;
}

=head3 openw_text

Opens the file with mode '>:encoding(UTF-8)' (UTF-8 output).

=cut

method openw_text {
    my $fh = $self->SUPER::open('>:encoding(UTF-8)')
      or croak "Can't write $self: $!";
    return $fh;
}

=head2 Copying and Moving Files

=head3 copy_to, move_to

Just like their equivalents in Path::Class::File, but throw an
exception on failure.

=cut

method copy_to {
    my $newfile = $self->_copy_to(@_);
    return $newfile if defined $newfile;
    croak "Couldn't copy $self: $!";
}

# moving _copy_to here because Path::Class::File::copy_to
# uses "system 'cp'" instead of using File::Copy, which I think
# is pretty crazy.

sub _copy_to {
    my ( $self, $dest ) = @_;
    if ( eval { $dest->isa("Path::Class::File") } ) {
        $dest = $dest->stringify;
        croak "Can't copy to file $dest: it is a directory" if -d $dest;
    }
    elsif ( eval { $dest->isa("Path::Class::Dir") } ) {
        $dest = $dest->stringify;
        croak "Can't copy to directory $dest: it is a file" if -f $dest;
        croak "Can't copy to directory $dest: no such directory"
          unless -d $dest;
    }
    elsif ( ref $dest ) {
        croak "Don't know how to copy files to objects of type '"
          . ref($self) . "'";
    }

    require File::Copy;
    return unless File::Copy::cp( $self->stringify, "${dest}" );

    return $self->new($dest);
}

method move_to {
    my $newfile = $self->SUPER::move_to(@_);
    return $newfile if defined $newfile;
    croak "Couldn't move $self: $!";
}

# Actium::Folder equivalents -- see list in Actium::Storage::Folder

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
C<openr_text> or C<openr_raw>.

=item Can't write I<file>: I<error>

An input/output error occurred while attempting to write a  file using
C<openw_text> or C<openw_raw>.

=back

=head1 DEPENDENCIES

=over

=item Actium

=item Kavorka

=item Path::Class

=back

The following are loaded only when necessary:

=over

=item Array::2D

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

