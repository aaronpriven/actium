package Octium::Storage::TabDelimited 0.010;

use Actium;
use Octium;

use Params::Validate (':all');    ### DEP ###

use Sub::Exporter -setup => { exports => [qw(read_aoas read_tab_files)] };
# Sub::Exporter ### DEP ###

sub read_aoas {
    my %params = validate(
        @_,
        {   folder => {
                can => [
                    'make_filespec', 'glob_plain_files',
                    'open_read',     'display_path'
                ]
            },
            files            => { type => ARRAYREF, default => [] },
            globpatterns     => { type => ARRAYREF, default => [] },
            required_headers => { type => ARRAYREF, default => [] },
            progress_lines   => { type => SCALAR,   default => 5000 },
            trim             => { type => BOOLEAN,  default => 0 },
        },

    );

    my %headers_of;
    my %records_of;

    my $callback = sub {

        my ( $value_of_r, $values_r, $headers_r, $line, $file, $linenum ) = @_;

        unless ( exists $headers_of{$file} ) {
            $headers_of{$file} = \@{$headers_r};
        }

        push @{ $records_of{$file} }, $values_r;

    };

    $params{callback} = $callback;

    read_tab_files( \%params );

    return \%headers_of, \%records_of;

}    ## tidy end: sub read_aoas

sub read_tab_files {

    my %params = validate(
        @_,
        {   folder => {
                can => [
                    'make_filespec', 'glob_plain_files',
                    'open_read',     'display_path'
                ]
            },
            files            => { type => ARRAYREF, default => [] },
            globpatterns     => { type => ARRAYREF, default => [] },
            required_headers => { type => ARRAYREF, default => [] },
            callback         => { type => CODEREF },
            progress_lines   => { type => SCALAR,   default => 5000 },
            trim             => { type => BOOLEAN,  default => 0 },
        },

    );

    my $folder         = $params{folder};
    my $passed_files_r = $params{files};
    my $globpatterns_r = $params{globpatterns};
    my $trim           = $params{trim};

    unless ( $passed_files_r or $globpatterns_r ) {
        croak 'Must specify either files or globpatterns to read_tab_files';
    }

    my $required_headers_r = $params{required_headers};
    my $callback_r         = $params{callback};
    my $progress_lines     = $params{progress_lines};

    my @files = _expand_files( $passed_files_r, $globpatterns_r, $folder );

    foreach my $file (@files) {

        my $file_cry = cry("Loading $file");

        my $fh = $folder->open_read($file);

        my @headers = _verify_headers( $fh, $file, $required_headers_r );

        my $size = -s $fh;
        #my $size    = -s $folder->make_filespec($file);
        my $linenum = 0;

        $file_cry->over(' 0%');

        while ( my $line = <$fh> ) {

            $linenum++;
            if ( not $linenum % $progress_lines ) {
                $file_cry->over(
                    sprintf( ' %.0f%%', tell($fh) / $size * 100 ) );
            }

            my @values;
            if ($trim) {
                @values = ( split( "\t", $line ) );
                foreach (@values) {
                    s/\A\s+//;
                    s/\s+\z//;
                }
            }
            else {    # always remove final whitespace, for line endings
                $line =~ s/\s+\z//;
                @values = ( split( /\t/, $line ) );
            }

            push @values, (q{}) x ( scalar @headers - scalar @values );
            # pad out with empty strings...

            my %value_of;
            @value_of{@headers} = @values;

            #$callback_r->( \%value_of );
            $callback_r->(
                \%value_of, \@values, \@headers, $line, $file, $linenum
            );

        }    ## tidy end: while ( my $line = <$fh> )

        $file_cry->over(' 100%');

        close $fh;

        $file_cry->done;

    }    ## tidy end: foreach my $file (@files)

    return;

}    ## tidy end: sub read_tab_files

sub _expand_files {

    my ( $files_r, $globpatterns_r, $folder ) = @_;

    my @files = @{$files_r};

    foreach (@$globpatterns_r) {
        push @files, Octium::filename( $folder->glob_plain_files($_) );
    }

    if ( not scalar @files ) {
        my $path = $folder->display_path;
        croak("No files found in $path passed to read_tab_files ");
    }

    return @files;

}

sub _verify_headers {

    my $fh               = shift;
    my $file             = shift;
    my @required_headers = @{ +shift };

    my $headerline = ( scalar(<$fh>) );
    my @headers = split( "\t", $headerline );

    foreach (@headers) {
        s/\A\s+//;
        s/\s+\z//;
    }

    if ( scalar @required_headers ) {
        foreach my $required_header (@required_headers) {
            if ( not Octium::in( $required_header, @headers ) ) {
                croak
                  "Required header $required_header not found in file $file";
            }
        }
    }

    return @headers;

}    ## tidy end: sub _verify_headers

1;

__END__


=head1 NAME

Octium::Storage::TabDelimited - Read tab-delimited files into perl data

=head1 VERSION

This documentation refers to version 0.002

=head1 SYNOPSIS

 use Octium::Storage::TabDelimited ('read_tab_files');
 
 my %data;
 
 my $callback = sub {
     my $hashref = shift;
     foreach my $key (keys %{$hashref}) {
        $value = $hashref->{$key};
        push @{$data{$key}} , $value;
     }
 };
     
 read_tab_files(
    {   globfiles        => ['*.txt'],
        folder           => $folder_obj,
        required_headers => ['ID','Name'],
        callback         => $callback,
    }
 );
 
Or:

 use Octium::Storage::TabDelimited ('read_aoas');
 
 my ($headers_of_r, $values_of_r)  = read_aoas(
    {   globfiles        => ['*.txt'],
        folder           => $folder_obj,
        required_headers => ['ID','Name'],
    }
 );
 
 say ".txt headers: " , join(",", @{$headers_of{'stop.txt'}});
 my $count=0;
 foreach my $record_r (@{values_of{'stop.txt'}}) {
     say $count++, ": " , join("," , @{$record_r});
 }
 
   
=head1 DESCRIPTION

Octium::Storage::TabDelimited contains routines to read tab-delimited
files from a directory. I<read_tab_files> returns the data to the
caller via a  callback function. I<read_aoas> returns the data as
arrays of arrays.

It is designed to encapsulate some of the more tedious aspects of
reading tab-delimited files, such as determining the headers and
providing terminal feedback.

The program assumes that the first line of each file is a set of column
headings, and that values are separated by tabs.



=head1 SUBROUTINES

=head2 read_tab_files()

The read_tab_files takes a series of named parameters. Parameter
processing is performed using Params::Validate, so the parameters can
either be passed as a hash or as a hash reference.

The named parameters are:

=over

=item folder

This mandatory parameter is intended to be an Octium::O::Folder object
(or a subclass such as Octium::O::Folders::Signup). However, any object
representing a folder will work if it implements the methods
"make_filespec", "glob_plain_files", "open_read", and "display_path."
See L<Octium::O::Folder|Octium::O::Folder> for details of these
methods.

=item files

If present, this parameter must be a reference to an array of  one or
more names of files found in the folder given in the folder parameter.

If neither files nor globpatterns is specified, an exception will be
thrown.

=item globpatterns

If present, this parameter must be a reference to an array of one or
more patterns (to be passed to $folderobject->glob_plain_files ), which
will cause those files to be read.

If neither files nor globpatterns is specified, an exception will be
thrown.

=item required_headers

If present, this parameter must be a reference to an array of column
headers to be found in the tab file. If any header is not found, an
exception is thrown.

=item progress_lines

If present, this parameter specifies after how many lines the progress 
indicator (percentages) are updated. The default is 5000.

=item callback

This mandatory parameter must be a code reference. For each line read,
this code reference is invoked, as described below.

=item trim

If present and true, this will trim whitespace from the beginning and
end  of each field. This can be time-consuming in a large file.

=back

=head3 Callback 

The routine calls the callback on each line read. The callback is given
a series of arguments:

=over

=item * 

A reference to a hash whose keys are the column headers and whose
values are the values of each column.

=item *

A reference to an array of the values of each column.

=item *

A reference to an array of the column headers.

=item *

The line as read from the file.

=item * 

The file name of the current file.

=item *

The number of the current line being read in the file (beginning with
1).

=back

This allows the caller to save the data from the line in a variety of
ways.

=head2 read_aoas()

This routine simplifies reading simple files by simply returning the
data in two complex data structures. Each is a hash where the keys are
the names of  the files that was read.  The values of the first hash
are references to an  array containing the names of the headers.  The
values of the second hash are  references to an array of records, each
containing an array of data fields.

It accepts all the same parameters as read_tab_files (see above),
except "callback."

=head1 DIAGNOSTICS

=over

=item 'Must specify either files or globpatterns to read_tab_files'

read_tab_files was called, but the caller specified neither a list of
files nor a list of patterns that will be used to determine which files
should be called, so the routine didn't know which files to open.

=item "No files found in $path passed to read_tab_files "

No files were found, either from the files or globpatterns provided.

=item "Required header $required_header not found in file $file"

A header was passed via the "required_headers" parameter that was not
found in the file.

=back

=head1 DEPENDENCIES

=over

=item *

Perl 5.014

=item *

Params::Validate

=item *

Sub::Exporter

=back

=head1 LIMITATIONS

A more flexible routine would also allow other line terminators than
"\n".

Some of the same code could be used for CSV files, where it would use 
Text::CSV to do the CSV parsing but would have the same calling syntax
and other features.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2012

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

