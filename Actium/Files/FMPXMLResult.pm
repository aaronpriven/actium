# Actium/Files/FMPXMLResult.pm

# Class for reading and processing FileMaker Pro FMPXMLRESULT XML exports
# and storing in an SQLite database using Actium::Files::SQLite

# Subversion: $Id$

# Legacy stage 4

use warnings;
use 5.012;    # turns on features

package Actium::Files::FMPXMLResult 0.001;

use Moose;
use MooseX::StrictConstructor;

use POSIX ();

use Actium::Constants;
use Actium::Files;
use Actium::Files::SQLite::Table;
use Actium::Term;
use Actium::Util('jk');
use Readonly;
use File::Glob qw(:glob);
use Carp;
use English '-no_match_vars';
use Storable;
use DBI (':sql_types');
use XML::Parser;

Readonly my $EXTENSION => '.xml';

#requires(
#    qw/db_type key_of_table columns_of_table tables
#       _load _files_of_filetype _tables_of_filetype
#       _filetype_of_table is_a_table/
#);

sub db_type { return 'FileMaker' }

# I think all the FileMaker exports will be the same database type

sub parent_of_table { return undef };  ## no critic (RequireFinalReturn)

# TODO: Move to a configuration file of some kind
Readonly my %KEY_OF => (
    Cities        => 'Code',
    Colors        => 'ColorID',
    Lines         => 'Line',
    Neighborhoods => 'Neighborhood',
    Projects      => 'Project',
    SignTypes     => 'SignType',
    Signs         => 'SignID',
    SkedAdds      => 'SkedId',
    Skedidx       => 'SkedId',
    Timepoints    => 'Abbrev4',
    Stops         => 'PhoneID',
);

# Fields separated by slashes (/) will treated as composite keys, e.g.,
# 'Days/Direction" treated as a composite key of Days and Direction
# I'm not sure this will be used, but just in case...

# Just one table per filetype, and file and filetype have the same name
sub _tables_of_filetype {
    my $self  = shift;
    my $table = shift;
    return $table;
}

sub _filetype_of_table {
    my $self  = shift;
    my $table = shift;
    return $table;
}

sub _files_of_filetype {
    my $self  = shift;
    my $table = shift;
    return $table . $EXTENSION;
}

has table_r => (
    is       => 'bare',
    builder  => '_build_table_r',
    lazy     => 1,
    init_arg => undef,
    traits   => ['Hash'],
    isa      => 'HashRef[Bool]',
    handles  => {
        tables     => 'keys',
        is_a_table => 'get',
    },
);

sub _build_table_r {
    my $self         = shift;
    my $flats_folder = $self->flats_folder();

    #emit 'Assembling list of filenames';

    my @all_files = bsd_glob( $self->_flat_filespec(qq<*$EXTENSION>),
        GLOB_NOCASE | GLOB_NOSORT );

    if (File::Glob::GLOB_ERROR) {
        emit_error;
        croak 'Error reading list of FileMaker Pro FMPXMLRESULT files in '
          . "folder $flats_folder: $OS_ERROR";
    }

    if ( not scalar @all_files ) {
        emit_error;
        croak
          "No FileMaker Pro FMPXMLRESULT files found in folder $flats_folder";
    }

    @all_files = map { Actium::Files::filename($_) } @all_files;

    my %tables;

    foreach my $file (@all_files) {
        my $table = $file;
        $table =~ s/$EXTENSION\z//sx;
        $tables{$table} = 1;
    }

    #emit_done;

    return \%tables;

} ## tidy end: sub _build_table_r

has '_table_obj_of_r' => (
    init_arg => undef,
    is       => 'ro',
    traits   => ['Hash'],
    isa      => 'HashRef[Actium::Files::SQLite::Table]',
    default  => sub { {} },
    handles  => {
        _table_obj_of     => 'get',
        _table_objs       => 'values',
        _set_table_obj_of => 'set',
    },
);

sub key_of_table {
    my $self  = shift;
    my $table = shift;
    $self->ensure_loaded($table);
    my $table_obj = $self->_table_obj_of($table);
    return $table_obj->key;
}

sub columns_of_table {
    my $self  = shift;
    my $table = shift;
    $self->ensure_loaded($table);
    my $table_obj = $self->_table_obj_of($table);
    return $table_obj->columns;
}

sub _stored_spec {
    my $self  = shift;
    my $table = shift;
    my $dbh   = $self->dbh;

    my ($spec) = (
        $dbh->selectrow_array( 'SELECT spec FROM tablespec WHERE tablename = ?',
            {}, $table )
          or $EMPTY_STR
    );

    return $spec;
}

# _load required by SQLite role
sub _load {
    my $self     = shift;
    my $filetype = shift;
    my $table    = $filetype;
    my $file     = $self->_flat_filespec(shift);
    my $dbh      = $self->dbh();

    $dbh->do(
        'CREATE TABLE IF NOT EXISTS tablespec ( tablename TEXT , spec TEXT )');
    my $storedspec = $self->_stored_spec($table);
    $dbh->do( 'DELETE FROM tablespec WHERE tablename = ?', {}, $table )
      if $storedspec;

    emit "Reading FileMaker FMPXMLESULT $filetype";
    emit_over '0% ';

    $self->_load_xml_parser( $filetype, $file );

    emit_over '100% ';
    emit_done;

    return;

} ## tidy end: sub _load

sub _insert_spec {
    my $self       = shift;
    my $table      = shift;
    my $serialized = shift;
    my $dbh        = $self->dbh;

    my $tablespec_sth = $dbh->prepare(
        'INSERT INTO tablespec (tablename, spec) VALUES ( ? , ? )');
    $tablespec_sth->bind_param( 1, $table );
    $tablespec_sth->bind_param( 2, $serialized, SQL_BLOB );
    $tablespec_sth->execute;
    $tablespec_sth->finish;
    return;
}

with 'Actium::Files::SQLite';

after 'ensure_loaded' => sub {
    my $self   = shift;
    my @tables = @_;

    foreach my $table (@tables) {
        my $spec_r    = Storable::thaw( $self->_stored_spec($table) );
        my $table_obj = Actium::Files::SQLite::Table->new($spec_r);
        $self->_set_table_obj_of( $table, $table_obj );
    }
    return;

};

sub _load_xml_parser {
    # I wrote an XML::Twig version... but it took 5 times  as long
    my $self     = shift;
    my $filetype = shift;
    my $file     = shift;
    my $table    = $filetype;
    my $dbh      = $self->dbh();

    my $data_buffer;
    my @row_buffer;
    my $first_data_in_col;    # don't add KEY_SEPARATOR to first column

    my ($table_obj, $records_to_import, $emit_increment,
        $next_emit, $insert_sth,        $has_composite_key,
    );

    my %spec = (
        id               => $table,
        filetype         => $filetype,
        key_components_r => [ split( m{/}s, $KEY_OF{$table} ) ],
    );

    my $record_count = 0;

=begin comment

Here is the list of events that are noted. Any tags that are completely
ignored are not shown. An ignored start or end tag is shown in (parens).

(Start of METADATA)
Start of FIELD - store attributes in column info
(End of FIELD)
End of METADATA - save column info (create SQL table, etc.)

START OF RESULTSET - store number of records returned
(START OF ROW)
Start of COL - set "beginning of COL" flag. Clear $data_buffer.

Start of DATA - unless if "beginning of COL" flag is set, add key separator to
                $data_buffer. Unset "beginning of COL" flag.
CHARS - Add chars to $data_buffer
(End of DATA)
End of COL - Push $data_buffer to @row_buffer, and clear $data_buffer
End of ROW - Save row_buffer into SQLite database
(End of RESULTSET)

=end comment

=cut

    ## no critic (ProhibitCascadingIfElse)
    # speed is of the essence

    my $start_of_tag_handler = sub {
        #my $expat   = shift;
        #my $element = shift;
        my $element = $_[1];

        if ( $element eq 'DATA' ) {
            if ($first_data_in_col) {
                $first_data_in_col = 0;
            }
            else {
                $data_buffer .= $KEY_SEPARATOR;
            }
        }
        elsif ( $element eq 'COL' ) {
            $first_data_in_col = 1;
            $data_buffer       = q{};
        }
        elsif ( $element eq 'FIELD' ) {
            my %attr = @_;

            my $name = $attr{NAME};
            push @{ $spec{columns_r} }, $name;
            $spec{column_repetitions_of_r}{$name} = $attr{MAXREPEAT};
            $spec{column_type_of_r}{$name}        = $attr{TYPE};
        }
        elsif ( $element eq 'RESULTSET' ) {
            my %attr = @_;

            $records_to_import = $attr{FOUND};
            ## no critic (ProhibitMagicNumbers)
            # display updated percentages this many times
            $emit_increment = POSIX::ceil( $records_to_import / 10 );
            ## use critic
            $next_emit = $emit_increment;

        }

        return;
    };

    my $end_of_tag_handler = sub {
        #my $expat   = shift;
        #my $element = shift;
        my $element = $_[1];
        return if $element eq 'DATA';

        if ( $element eq 'COL' ) {
            push @row_buffer, $data_buffer;
            $data_buffer = {};
        }
        elsif ( $element eq 'ROW' ) {

            if ($has_composite_key) {
                push @row_buffer,
                  jk( @row_buffer[ @{ $table_obj->key_components_idxs } ] );
            }

            $insert_sth->execute( ++$record_count, @row_buffer );

            if ( $record_count >= $next_emit ) {
                $next_emit = $record_count + $emit_increment;
                ## no critic (ProhibitMagicNumbers)
                # 100 is, of course, the conversion factor to percentages
                emit_over(
                    sprintf(
                        '%2d%%', $record_count / $records_to_import * 100
                    )
                );
                ## use critic

            }

            @row_buffer = ();
        } ## tidy end: elsif ( $element eq 'ROW')
        elsif ( $element eq 'METADATA' ) {
            $table_obj = Actium::Files::SQLite::Table->new( \%spec );
            $self->_set_table_obj_of( $table, $table_obj );
            $has_composite_key = $table_obj->has_composite_key;

            $dbh->do( $table_obj->sql_createcmd );
            my $idxcmd = $table_obj->sql_idxcmd;
            $dbh->do($idxcmd) if $idxcmd;

            my $serialized = Storable::freeze( \%spec );

            $self->_insert_spec( $table, $serialized );

            $insert_sth = $dbh->prepare( $table_obj->sql_insertcmd );

        }

        return;
    };

    my $char_handler = sub {
        #my $expat  = shift;
        #my $string = shift;
        $data_buffer = $data_buffer . $_[1];
        return;
    };

    ## use critic

    my $parser = XML::Parser->new(
        Handlers => {
            Start => $start_of_tag_handler,
            End   => $end_of_tag_handler,
            Char  => $char_handler,
        }
    );
    $self->begin_transaction;

    $parser->parsefile($file);

    $self->end_transaction;

    return;

} ## tidy end: sub _load_xml_parser

1;

__END__

=head1 NAME

Actium::Files::FMPXMLResult - Routines for SQLite storage of
FileMaker Pro "FMPXMLRESULT" files

=head1 NOTE

This documentation is intended for maintainers of the Actium system, not
users of it. Run "perldoc Actium" for general information on the Actium system.

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Files::FMPXMLResult;
 
 my $hasi_db = Actium::Files::FMPXMLResult->new(
     flats_folder => $xml_folder,
     db_folder    => $db_folder,
     db_filename  => $db_filename,
 );
      
 $stoprow_hr = $hasi_db->row('Stops' , '51111');
 $description = $stoprow_hr->{DescriptionF};
 
=head1 DESCRIPTION

This is a series of routines that store FileMaker Pro FMPXMLRESULT files
using the Actium::Files::SQLite role. This documentation describes the
specifics of the FMPXMLRESULT routines; for general information about the
database access and structure, see
L<Actium::Files::SQLite|Actium::Files::SQLite>.

For more information about the FMPXMLRESULT format, see 
L<FileMaker's help 
file|http://www.filemaker.com/11help/html/import_export.16.34.html> 
or the "fmpxmlresult_dtd.htm" file that comes with FileMaker Pro 10.

=head1 PUBLIC METHODS 

These are all required by the Actium::Files::SQLite role.

=over

=item B<db_type()>

Returns 'FileMaker'.  This distinguishes this type from other databases
using Actium::Files::SQLite.

=item B<columns_of_table>

Returns the columns of the table, from the 
L<Actium::Files::SQLite::Table|Actium::Files::SQLite::Table> object.
The columns of each table are not known until after the table is loaded into
SQLite, so asking for the columns will load the data.

=item B<key_of_table>

Returns the key column of the table, which are stored in 
L<Actium::Files::SQLite::Table|Actium::Files::SQLite::Table> objects. At the 
moment the keys of each column are hard coded into the program, but eventually
this will be moved to some sort of configuration system.

=item B<tables>

Returns the list of tables, which is to say, the list of "*.xml" files it found
in the 
L<Actium::Files::SQLite/flats_folder|Actium::Files::SQLite/flats_folder>.

=item B<is_a_table(I<table>)>

Returns 1 if the specified table exists in the list of tables.

=item B<parent_of_table>

Always returns undef, since FileMaker tables have no parents.

=back

=head1 PRIVATE METHODS

=over

=item B<_filetype_of_table(I<table>)>

=item B<_tables_of_filetype(I<filetype>)>

Always returns the table name, since filetypes and table names in FMPXMLResult
are identical. These are required by Actium::Files::SQLite.

=item B<_files_of_filetype(I<filetype>)>

Returns whatever is passed to it with ".xml" added to the end.
This method is required by Actium::Files::SQLite. 

=item B<_load(I<filetype>,I<file>)>

This reads the file specified and saves the data into the database.

This method is required by Actium::Files::SQLite. 

=back

=head1 DIAGNOSTICS

=head2 FATAL ERRORS

=over

=item Error reading list of FileMaker Pro FMPXMLRESULT files in folder $flats_folder: $OS_ERROR

An error was found getting the list of files from C<glob>. 
See L<File::Glob diagnostics for more information.|File::Glob/DIAGNOSTICS>.

=item No FileMaker Pro FMPXMLRESULT files found in folder $flats_folder

No matching files were found in the folder specified. Perhaps the wrong
folder was specified?

=back

=head1 DEPENDENCIES

=over

=item perl 5.012

=item DBI

=item Moose

=item MooseX::StrictConstructor

=item Readonly

=item XML::Parser

=item Actium::Constants

=item Actium::Files

=item Actium::Files::SQLite

=item Actium::Files::SQLite::Table

=item Actium::Term

=item Actium::Util

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 
