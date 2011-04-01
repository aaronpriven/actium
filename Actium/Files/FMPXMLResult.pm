# Actium/Files/FMPXMLResult.pm

# Class for reading and processing FileMaker Pro FMPXMLRESULT XML exports
# and storing in an SQLite database using Actium::Files::SQLite

# Subversion: $Id$

# Legacy stage 4

use warnings;
use 5.012;    # turns on features

package Actium::Files::FMPXMLResult 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
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
use XML::Twig;

Readonly my $EXTENSION => '.xml';

#requires(
#    qw/db_type key_of_table columns_of_table tables
#       _load _files_of_filetype _tables_of_filetype
#       _filetype_of_table is_a_table/
#);

sub db_type () {return 'FileMaker'}

# I think all the FileMaker exports will be the same database type

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
    return $self->_flat_filespec( $table . $EXTENSION );
}

has table_r {
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
};

sub _build_table_r {
    my $self         = shift;
    my $flats_folder = $self->flats_folder();

    emit 'Assembling list of filenames';

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

    emit_done;

    return \%tables;

} ## tidy end: sub _build_table_r

has '_table_obj_of_r' => (
    init_arg => undef,
    is       => 'ro',
    traits   => ['Hash'],
    isa      => 'HashRef[Actium::Files::SQLite::Table]',
    default  => sub { {} },
    handles  => {
        _table__obj_of    => 'get',
        _table_objs       => 'values',
        _set_table_obj_of => 'set',
    },
);

sub _key_of_table {
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

# _load required by SQLite role
sub _load {
    my $self     = shift;
    my $filetype = shift;
    my $table    = $filetype;
    my $file     = shift;
    my $dbh      = $self->dbh();

    emit "Reading FileMaker FMPXMLESULT $filetype";
    emit_over '0% ';

    my ($table_obj,      $records_to_import, $record_count,
        $emit_increment, $next_emit,         $insert_sth,
        $has_composite_key,
    );

    # These callback definitions are inside '_load_' so they have access
    # to lexical variables

    my $resultset_callback = sub {
        my $twig = shift;
        my $elt  = shift;
        $records_to_import = $elt->att('FOUND');
        $emit_increment    = POSIX::ceil( $records_to_import / 25 );
        $next_emit         = $emit_increment;
        return;
    };

    my $metadata_callback = sub {
        my $twig     = shift;
        my $metadata = shift;
        my %spec     = (
            id               => $table,
            filetype         => $filetype,
            key_components_r => [ split( m{/}s, $KEY_OF{$table} ) ],
        );

        my $idx = 0;

        foreach my $field ( $metadata->children('FIELD') ) {
            my $name = $field->att('NAME');
            push @{ $spec{column_r} }, $name;
            $spec{column_repetitions_of_r}{$name} = $field->att('MAXREPEAT');
            $spec{column_type_of_r}{$name}        = $field->att('TYPE');
        }

        $twig->purge;

        $table_obj = Actium::Files::SQLite::Table->new( \%spec );
        $self->_set_table_obj_of( $table, $table_obj );
        $has_composite_key = $table_obj->has_composite_key;

        $dbh->do( $table_obj->sql_createcmd );
        my $idxcmd = $table_obj->sql_idxcmd;
        $dbh->do($idxcmd) if $idxcmd;

        $insert_sth = $dbh->prepare( $table_obj->sql_insertcmd );

        return;
    };

    my $row_callback = sub {
        my $twig = shift;
        my $row  = shift;

        if ( $record_count >= $next_emit ) {
            $next_emit = $record_count + $emit_increment;
            emit( sprintf( '%2d%%', $record_count / $records_to_import * 100 ) );
        }

        my @values = $self->_row_parse( $row->children('COL') );

        if ( $table_obj->has_composite_key ) {
            push @values, jk( @values[ @{ $table_obj->key_components_idxs } ] );
        }

        $insert_sth->execute($record_count++ ,@values);

        $twig->purge;

    };

    my $twig = XML::Twig->new(
        twig_roots => { METADATA => 1, RESULTSET => 1 },
        start_tag_handlers => { RESULTSET => $resultset_callback },
        twig_handlers      => {
            METADATA => $metadata_callback,
            ROW      => $row_callback,
        }
    );

    $twig->parsefile($file);
    # all the actual stuff that happens is in the handlers

    emit_over '100% ';

    emit_done;
    return;

} ## tidy end: sub _load

sub _row_parse {
    my $self     = shift;
    my @col_elts = @_;

    my @values;
    foreach my $col (@col_elts) {
        my @data_elts = $col->children;
        push @values, jk( map { $_->text } @data_elts );
    }

    return @values;

}

with 'Actium::Files::SQLite';

1;