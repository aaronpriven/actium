# Actium/Files.pm
# Miscellaneous file routines associated with the Actium system

# Subversion: $Id$

# legacy stage 3

# This is now obsolete, and calls should be replaced with calls to 
# Actium::Folder::Signup or Actium::Folder

use strict;
use warnings;

package Actium::Files;

use 5.010;    # turns on features

our $VERSION = "0.001";
$VERSION = eval $VERSION;

use Actium::Term (qw<:all>);
use Storable();
use Carp;
#use Term::Emit qw(:all) , { -closestat => 'ERROR' };

use Params::Validate(':all');

use open ':encoding(utf8)';

use File::Spec;

use Exporter qw( import );
our @EXPORT_OK
  = qw(retrieve store write_files_with_method write_files_from_hash filename);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use English qw<'-no_match_vars'>;

sub retrieve {

    my $filespec = shift;

    croak "$filespec does not exist"
      unless -e $filespec;

    my $filename = filename($filespec);

    emit("Retrieving $filename");

    my $data_r = Storable::retrieve($filespec);

    unless ($data_r) {
        emit_error();
        croak "Can't retreive $filespec: $OS_ERROR";
    }

    emit_done;

    return $data_r;

} ## tidy end: sub retrieve

sub store {

    my $data_r   = shift;
    my $filespec = shift;
    my $filename = filename($filespec);

    emit("Storing $filename...");

    my $result = Storable::nstore( $data_r, $filespec );

    unless ($result) {
        emit_error;
        croak "Can't store $filespec: $OS_ERROR";
    }

    emit_done;

    return;

} ## tidy end: sub store

sub filename {

    my $filespec = shift;
    my $filename;
    ( undef, undef, $filename ) = File::Spec->splitpath($filespec);
    return $filename;
}

sub write_files_with_method {

    my %params = validate(
        @_,
        {   OBJECTS   => { type => ARRAYREF },
            FILETYPE  => 1,
            SIGNUP    => { can => 'make_filespec' },
            EXTENSION => 1,
            METHOD    => 0,
        }
    );

    my @objects   = @{ $params{OBJECTS} };
    my $filetype  = $params{FILETYPE};
    my $folder    = $params{SIGNUP};
    my $extension = $params{EXTENSION};
    my $method    = $params{METHOD} || $filetype;

    my $count;

    emit("Writing $filetype files");

    $folder = Actium::Signup->new($filetype)
      unless $folder;

    my %seen_id;

    foreach my $obj (@objects) {

        my $out;

        my $id = $obj->id;
        emit_over $id;

        $seen_id{$id}++;

        $id .= "_$seen_id{$id}" unless $seen_id{$id} == 1;
        write_file_with_method(
            {   OBJECT   => $obj,
                FOLDER   => $folder,
                METHOD   => $method,
                FILENAME => "$id.$extension"
            }
        );

    }

    emit_done;

} ## tidy end: sub write_files_with_method

sub write_file_with_method {
    my %params   = %{ +shift };
    my $obj      = $params{OBJECT};
    my $folder   = $params{FOLDER};
    my $filename = $params{FILENAME};
    my $method   = $params{METHOD};

    my $out;

    my $file = $folder->make_filespec($filename);

    unless ( open $out, '>', $file ) {
        emit_error;
        die "Can't open $file for writing: $OS_ERROR";
    }

    print $out $obj->$method() or die "Can't print to $file: $OS_ERROR";

    unless ( close $out ) {
        emit_error;
        die "Can't close $file for writing: $OS_ERROR";
    }

} ## tidy end: sub write_file_with_method

sub write_files_from_hash {

    my %hash      = %{ shift @_ };
    my $filetype  = shift;
    my $extension = shift;

    my $count;

    emit("Writing $filetype files");

    my $folder = Actium::Signup->new($filetype);

    foreach my $key ( sort keys %hash ) {

        my $out;
        emit_over $key;

        my $file = $folder->make_filespec( $key . ".$extension" );

        unless ( open $out, '>', $file ) {
            emit_error;
            die "Can't open $file for writing: $OS_ERROR";
        }

        print $out $hash{$key} or die "Can't print to $file: $OS_ERROR";

        unless ( close $out ) {
            emit_error;
            die "Can't close $file for writing: $OS_ERROR";
        }

    } ## tidy end: foreach my $key ( sort keys...)

    emit_done;

} ## tidy end: sub write_files_from_hash

1;

=head1 NAME

Actium::Files - File subroutines for use with the Actium system

=head1 VERSION

This documentation refers to Actium::Files version 0.001

=head1 SYNOPSIS

 use Actium::Files;

 $data_r = Actium::Files::retrieve('/usr/nifty/filename.storable');
 
 Actium::Files::store($data_r , '/var/niftier/another.storable')
 
 $filename = Actium::Files::filename('/var/niftier/woohoo.file');
 # $filename now is 'woohoo.file', at least under Unix
 
=head1 DESCRIPTION

Actium::Files is a module containing routines associated with
reading or writing files.  At the moment, it contains two sets of routines. 
The first is merely 
some simple wrappers for the L<Storable> module. All they do is print
some reassuring information on the screen before and after invoking
Storable, so that users know to expect little activity as Storable
runs. The second is a function that returns the filename portion of a 
file specification (using L<File::Spec>).

=head1 SUBROUTINES

=over

=item B<store($data_r , $filespec)>

A wrapper for Storable::nstore, storing the structure pointed to by the
reference $data_r in the file pointed to by $filespec.

=item B<retrieve($filespec)>

A wrapper for Storable::retrieve, loading a serialized data structure
from the file $filespec and returning a reference to it in memory.

=item B<filename($filespec>)>

Uses L<File::Spec> to get the filename portion of the file specification and
returns it.

=back

=head1 DIAGNOSTICS

See L<Storable> for possible errors.

=head1 DEPENDENCIES

=over

=item *
Perl 5.010 and its distribution.

=item *
L<Actium::Term>.

=item *

L<Term::Emit>.

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
