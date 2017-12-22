package Actium::Signup 0.014;

# Object representing the current signup

use Actium('class');
use Actium::Storage::Folder;
use Actium::Types;

has base_folder => (
    isa      => 'Actium::Storage::Folder',
    coerce   => 1,
    is       => 'ro',
    required => 1,
    trigger  => sub {
        my $self = shift;
        my $base = shift;
        croak "Base folder doesn't exist" unless $base->exists;
    },
);

has name => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has is_new => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0,
);

has folder => (
    isa      => 'Actium::Storage::Folder',
    init_arg => undef,
    is       => 'ro',
    handles  => [qw/ensure_subfolder existing_subfolder subfolder/],
    lazy     => 1,
    builder  => 1,

);

method _build_folder {
    if ( $self->is_new ) {
        return $self->base_folder->ensure_subfolder( $self->name );
    }
    return $self->base_folder->existing_subfolder( $self->name );
}

method phylum_folder ( :$phylum!, :$collection!, :$format ) {
    # at the moment, nothing special is done with these... but that could
    # change

    return $self->ensure_subfolder( $phylum, $collection )
      if ( not defined $format or $format eq $EMPTY );

    return $self->ensure_subfolder( $phylum, $collection, $format );
}

Actium::immut;

1;

__END__

=head1 NAME

Actium::Signup - Object representing the signup in the Actium system

=head1 VERSION

This documentation refers to version 0.010

=head1 SYNOPSIS

 use Actium::Signup;

 $signup = Actium::Signup->new(
      base_folder => '/Actium/signups/',
      signup => 'w00',
    );
 $skeds = $signup->subfolder('skeds');


 $oldsignup = Actium::Signup->new(
    { base_folder => '/Actium/signups/' , signup => 'f08'}
    );
 $oldskeds = $oldsignup->subfolder('skeds');

=head1 DESCRIPTION

=head2 Introduction

Actium::Signup is the object representing the "signup," or the 
particular set of transit schedules in effect at any one time.  (It is
named after the drivers' activity of "signing up" for a new piece of
work for a period of time.)

Data associated with a particular signup is located in a folder on
disk. This object contains information about those folders.

The module L<Actium::CLI|Actium::CLI> contains utilities for selecting
the base folder and signup name from command line programs, using
configuration files, environment variables, or commnad-line options.

=head1 ATTRIBUTES

Unless otherwise specified, all attributes must be set in the
constructor but are otherwise read-only.

=head2 name

This is the name of the signup.  The signup is usually named after the
period of time when the signup becomes effective ("w08" meaning "Winter
2008", for example).

=head2 signup_folder

The signup folder is stored as an Actium::Storage::Folder object, and
is  generated from the base_folder and the name. It cannot be set
separately in the constructor.

=head2 base_folder

Usually, signup folders are all located together in a folder one level
up. This is, for lack of a better term, called the base folder. It is 
convenient to specify the signup folder as a subfolder of the base
folder  so that one can specify just the signup ("w00") and not the
whole  file path (which, as of this writing, would be something like
"/Users/Shared/Dropbox (AC_PubInfSys)/B/Actium/signups/w00").

The base folder, stored as an Actium::Storage::Folder object, is a
required attribute of this object.

=head1 METHODS

=head2 ensure_subfolder, existing_subfolder, ensure_subfolder

These are passed to the signup folder object. See L<subfolder in 
Actium::Storage::Folder|Actium::Storage::Folder/subfolder> for more 
information.

=head2 phylum_folder

This is a way of specifying subfolders based on their content.  It is 
envisioned that all signup data will be divided into several phyla:

=over

=item i

Data imported (from GTFS or other scheduling exports)

=item s

Full transit schedules

=item p

Scheduling data about a specific point (for, e.g., posting at bus
stops)

=item l

Lists of stops

=back

Within that, there may be collections of data, representing how
processed the data is:

=over

=item received

Data as received -- that is, coming directly from the imported data

=item exceptions

Data overridden, to replace data that was recived

=item final

The received data combined with the final data

=back

And, finally, there may be several different formats representing the
same  data, or perhaps a subset of the data. There might be plain text
schedules, JSON schedules, Excel format schedules, etc.

The specific folder can be identified with the phylum_folder method:

 $folder = $signup->phylum_folder(
    phylum => I<phylum>, collection => I<collection>, format => I<format>
 )

The "format" parameter is optional, since not all data comes in
different formats.

This is intended as an interim step, since ideally data should be
represented not just as files but as objects, contained in this object.

=head1 DEPENDENCIES

=over

=item Actium

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it
under  the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

