# Actium/Files/HastusASI.pm

# Class for reading and processing FileMaker Pro FMPXMLRESULT XML exports
# and storing in an SQLite database using Actium::Files::SQLite

# Subversion: $Id$

# Legacy stage 4

use warnings;
use 5.012;    # turns on features

package Actium::Files::FileMaker::XMLResult 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Readonly;
use File::Glob qw(:glob);
use Carp;
use English '-no_match_vars';

use Actium::Term;

Readonly my $EXTENSION => '.xml';

#requires(
#    qw/db_type key_of_table columns_of_table tables
#       _load _files_of_filetype _tables_of_filetype
#       _filetype_of_table is_a_table/
#);

sub db_type () { 'FileMaker' }

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

sub _key_of_table {
    my $self  = shift;
    my $table = shift;
    my $key   = $KEY_OF{$table};
    return unless $key;
    return $key;
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
        $table =~ s/$EXTENSION\z//;
        $tables{$table} = 1;
    }

    emit_done;

    return \%tables;

}    ## tidy end: sub _build_files_list

sub columns_of_table {

    # load table, then get columns

}

# _load required by SQLite role
sub _load {
    my $self     = shift;
    my $filetype = shift;
    my $file     = $filetype . $EXTENSION;
    my $dbh      = $self->dbh();

    emit "Reading HastusASI $filetype files";

    my $twig = XML::Twig->new(
        twig_handlers => {
            field => \&_handle_field,
            col   => \&_handle_col,
        },
    );

    emit_done;
    return;

}

