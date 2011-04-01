# Actium/Files/HastusASI.pm

# Class for reading and processing Hastus Standard AVL files
# and storing in an SQLite database using Actium::Files::SQLite

# Subversion: $Id$

# Legacy stage 4

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Actium::Constants;
use Actium::Files;
use Actium::Term;
use Actium::Util qw(j jk);
use Carp;
use English '-no_match_vars';
use File::Glob qw(:glob);
use File::Spec;
use Readonly;

use Actium::Files::HastusASI::Definition;

# set some constants
Readonly my $DELIMITER                   => q{,};
Readonly my $DELIMITER_LENGTH            => length($DELIMITER);
Readonly my $DELIMITER_TEMPLATE_PAD      => 'x' x $DELIMITER_LENGTH;
Readonly my $EXTRA_FIELDS_WHEN_REPEATING => 49;
Readonly my $OCCASIONS_TO_DISPLAY        => 20;
Readonly my $AVERAGE_CHARS_PER_LINE      => 20;
Readonly my $DISPLAY_PERCENTAGE_FACTOR   => 100 / $OCCASIONS_TO_DISPLAY;

# Actium::Files::SQLite:
# requires(
#    qw/db_type key_of_table columns_of_table tables
#       _load _files_of_filetype _tables_of_filetype/
#);

#########################################
### DEFINITION
#########################################

# db_type required by SQLite role
sub db_type () { return 'HastusASI'}

has '_definition' => (
    is       => 'bare',
    init_arg => undef,
    isa      => 'Actium::Files::HastusASI::Definition',
    default  => sub { Actium::Files::HastusASI::Definition->instance },
    lazy     => 1,
    handles  => {
        columns_of_table            => 'columns_of_table',
        key_of_table                => 'key_of_table',
        tables                      => 'tables',
        is_a_table                  => 'is_a_table',
        _create_query_of_table      => 'create_query_of_table',
        _filetype_of_table          => 'filetype_of_table',
        _filetypes                  => 'filetypes',
        _has_composite_key          => 'has_composite_key',
        _has_repeating_final_column => 'has_repeating_final_column',
        _index_query_of_table       => 'index_query_of_table',
        _insert_query_of_table      => 'insert_query_of_table',
        _key_components_idxs        => 'key_components_idxs',
        parent_of_table            => 'parent_of_table',
        _tables_of_filetype         => 'tables_of_filetype',

    },
);

######################################
### FILES LIST
######################################

has '_files_of_filetype_hash' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]]',
    handles => { '_files_of_filetype_r' => 'get' },
    builder => '_build_files_list',
    lazy    => 1,
);

# _files_of_filetype required by SQLite role
sub _files_of_filetype {
    my $self     = shift;
    my $filetype = shift;
    my $files_r  = $self->_files_of_filetype_r($filetype);
    return @{$files_r};
}

sub _build_files_list {
    my $self         = shift;
    my $flats_folder = $self->flats_folder();

    emit 'Assembling lists of filenames';

    my @all_files
      = bsd_glob( $self->_flat_filespec(q<*>), GLOB_NOCASE | GLOB_NOSORT );

    if (File::Glob::GLOB_ERROR) {
        emit_error;
        croak 'Error reading list of filenames in Hastus AVL Standard '
          . "folder $flats_folder: $OS_ERROR";
    }

    if ( not scalar @all_files ) {
        emit_error;
        croak "No files found in Hastus AVL Standard folder $flats_folder";
    }

    @all_files = map { Actium::Files::filename($_) } @all_files;

    my %files_of;
    foreach my $filetype ( $self->_filetypes() ) {
        my @files = grep ( {/[.] $filetype /sx} @all_files );
        $files_of{$filetype} = \@files;
    }

    emit_done;

    return \%files_of;

} ## tidy end: sub _build_files_list

#########################################
### LOAD FLAT FILES (if necessary)
#########################################

# _load required by SQLite role
sub _load {
    my $self     = shift;
    my $filetype = shift;
    my @files    = @_;
    my $dbh      = $self->dbh();

    local $INPUT_RECORD_SEPARATOR = $CRLF;

    emit "Reading HastusASI $filetype files";

    my ( %sth_of, %parent_of, %key_components_idxs, %has_composite_key,
        %has_repeating_final_column );
    foreach my $table ( $self->_tables_of_filetype($filetype) ) {

        my @queries = (
            $self->_create_query_of_table($table),
            $self->_index_query_of_table($table),
        );

        foreach my $query (@queries) {
            $dbh->do($query) if $query;
        }

        $sth_of{$table}
          = $dbh->prepare( $self->_insert_query_of_table($table) );

        $parent_of{$table}         = $self->parent_of_table($table);
        $has_composite_key{$table} = $self->_has_composite_key($table);
        $has_repeating_final_column{$table}
          = $self->_has_repeating_final_column($table);
        $key_components_idxs{$table} = [ $self->_key_components_idxs($table) ];

    } ## tidy end: foreach my $table ( $self->_tables_of_filetype...)

    my $sequence = 0;
    $self->begin_transaction;

  FILE:
    foreach my $file (@files) {

        my $filespec = $self->_flat_filespec($file);

        my $size                = -s $filespec;
        my $display_after_lines = int(
            $size / ( 2 * $OCCASIONS_TO_DISPLAY * $AVERAGE_CHARS_PER_LINE ) );

        my $result = open my $fh, '<', $filespec;
        if ( not $result ) {
            emit_error;
            croak "Can't open $filespec for reading: $OS_ERROR";
        }

        my %template_of = $self->_build_templates( $fh, $filetype, $filespec );

        my $count    = 0;
        my $fraction = 0;
        my %previous_seq_of;

        emit_over "$file: 0%";

      ROW:
        while (<$fh>) {

            $count++;
            $sequence++;

            if ( not( $count % $display_after_lines ) ) {
                my $newfraction
                  = int( tell($fh) / $size * $OCCASIONS_TO_DISPLAY );
                if ( $fraction != $newfraction ) {
                    $fraction = $newfraction;

                    #emit_over "${fraction}0%";
                    emit_over( "$file: ",
                        $fraction * $DISPLAY_PERCENTAGE_FACTOR, '%' );
                }
            }

            my ( $table, $_ ) = split( /$DELIMITER/sx, $_, 2 );
            unless ( $self->is_a_table($table)
                and ( $self->_filetype_of_table($table) eq $filetype ) )
            {
                carp
                  "Incorrect table type $table in file $filespec, "
                  . "row $INPUT_LINE_NUMBER:\n$_\n";
                set_term_pos(0);
                next ROW;
            }

            $previous_seq_of{$table} = $sequence;

            my @columns = unpack( $template_of{$table}, $_ );
            s/\A\s+//s foreach @columns;

            if ( $has_repeating_final_column{$table} ) {
                my @finals = splice( @columns, scalar( columns($table) ) );
                push @columns, jk( grep { $_ ne $EMPTY_STR } @finals );
            }

            my $parent = $parent_of{$table};
            if ($parent) {
                unshift @columns, $previous_seq_of{$parent};
            }

            if ( $has_composite_key{$table} ) {
                push @columns,
                  jk( @columns[ @{ $key_components_idxs{$table} } ] );
            }

            $sth_of{$table}->execute( $sequence, @columns );

        }    # ROW
        if ( not close $fh ) {
            emit_error;
            croak "Can't close $filespec for reading: $OS_ERROR";
        }

        emit_over "$file: 100%";

    }    # FILE

    $self->end_transaction;

    emit_done;

    return;

} ## tidy end: sub _load

sub _build_templates {
    # builds the templates used to "unpack" the table row

=begin comment
    
    This requires a bit of explanation.  HSA rows are specified in the HSA
documentation as fixed-width records, with a delimiter -- practically
always a comma -- inserted between each pair of fields.  The comma is
not treated specially; it's just there to make the files easier to read.
There is no escaping mechanism where the comma, if found in real data,
is somehow marked as not being a real delimiter.  A program that naively
treats an HSA file as a typical comma-separated values file (CSV) will
yield incorrect results for each line where the data includes a comma.

Unfortunately, some people have written custom HSA export routines that
replace a standard field (such as the stop identifier) with another
field (a shorter stop identifier, intended for public use), with a
different length. So a program that uses the field lengths to determine
where each field is will break when provided with this custom HSA
export.

What is constant, however, is that the number of fields is the same, and
there will always be a comma between two fields. There will always be
I<at minimum> that number of commas, and no fewer. There may, however,
be more.

So what this program does is go through each HSA file and look for rows
that have the proper number of commas for the number of fields. If it
has more commas than that, then one of those commas is part of the data,
but if it has the right number for the number of fields, then we can use
the positions of each comma to determine the positions of the beginning
and end of each field.

=end

=cut

    my ( $self, $fh, $filetype, $filespec ) = @_;

    my %template_of;

    # determine number of columns
    foreach my $table ( $self->_tables_of_filetype($filetype) ) {
        my $numcolumns
          = scalar( $self->columns_of_table($table) ) + 1;   # add one for table
        $numcolumns += $EXTRA_FIELDS_WHEN_REPEATING
          if $self->_has_repeating_final_column($table);

        while ( not $template_of{$table} ) {
            my $line = <$fh>;
            last unless $line;
            chomp $line;
            my @columns = split( /$DELIMITER/sx, $line );
            if ( @columns == $numcolumns ) {
                $template_of{$table} = join( $DELIMITER_TEMPLATE_PAD,
                    map { 'A' . length } @columns[ 1 .. $#columns ] );
            }

        }
        if ( not $template_of{$table} ) {
            emit_error;
            croak "Unable to determine columns of $table in $filespec\n"
              . '(never found a line with the right number)';
        }

        if ( not seek $fh, 0, 0 ) {
            emit_error;
            croak
              "Couldn't return seek position to top of $filespec: $OS_ERROR";
        }

    } ## tidy end: foreach my $table ( $self->_tables_of_filetype...)

    return %template_of;

} ## tidy end: sub _build_templates

with 'Actium::Files::SQLite';

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

=head1 NAME

Actium::Files::HastusASI - Routines for SQLite storage of
Hastus AVL Standard Interface files

=head1 NOTE

This documentation is intended for maintainers of the Actium system, not
users of it. Run "perldoc Actium" for general information on the Actium system.

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Files::HastusASI;
 
 my $hasi_db = Actium::Files::HastusASI->new(
     flats_folder => $hasi_folder,
     db_folder    => $db_folder,
     db_filename  => $db_filename,
 );
      
 $stoprow_hr = $hasi_db->row('STP' , '51111');
 $description = $stoprow_hr->{Description};
 
=head1 DESCRIPTION

This is a series of routines that store Hastus AVL Standard Interface files
using the Actium::Files::SQLite role. This documentation describes the
specifics of the Hastus ASI routines; for general information about the
database access and structure, see
L<Actium::Files::SQLite|Actium::Files::SQLite>.

For more information about the Hastus AVL Standard Interface, see the document
"Hastus 2006 AVL Standard Interface, Last Update: July 26, 2005".

=head1 PUBLIC METHODS 

These are all required by the Actium::Files::SQLite role.

=over

=item B<db_type()>

Returns 'HastusASI'.  This distinguishes this type from other databases
using Actium::Files::SQLite.

=item B<columns_of_table>
=item B<key_of_table>
=item B<tables>
=item B<is_a_table>
=item B<parent_of_table>

These are delegated to 
L<Actium::Files::HastusASI::Definition|Actium::Files::HastusASI::Definition>
and information on them can be found there, or in other modules used by that 
module.

=back

=head1 PRIVATE METHODS

=item B<_create_query_of_table>
=item B<_filetype_of_table>
=item B<_filetypes>
=item B<_has_composite_key>
=item B<_has_repeating_final_column>
=item B<_index_query_of_table>
=item B<_insert_query_of_table>
=item B<_key_components_idxs>
=item B<_tables_of_filetype>

These are delegated to 
L<Actium::Files::HastusASI::Definition|Actium::Files::HastusASI::Definition>
and information on them can be found there, or in other modules used by that 
module. In that module, they do not have leading underscores.

Two (I<_tables_of_filetype> and I<_filetype_of_table>) are
required by Actium::Files::SQLite. The others are only used within this module.

=item B<_files_of_filetype(I<filetype>)>

This returns the list of files on disk associated with a particular filetype.
Usually, this will be just one file per filetype, but it's conceivable that
different sets of Hastus AVL files could be usefully combined, so that ability
is present.

This method is required by Actium::Files::SQLite. 

=item B<_load(I<filetype>,I<files...>)>

This reads the files specified, which are of the filetype specified, and 
saves the data into the database.

This method is required by Actium::Files::SQLite. 

=back

=head1 DIAGNOSTICS

=head2 FATAL ERRORS

=over

=item Error reading list of filenames in Hastus AVL Standard folder $flats_folder: $OS_ERROR

An error was found getting the list of files from C<glob>. 
See L<File::Glob diagnostics for more information.|File::Glob/DIAGNOSTICS>.

=item No files found in Hastus AVL Standard folder $flats_folder

No matching files were found in the folder specified. Perhaps the wrong
folder was specified?

=item Can't open $filespec for reading: $OS_ERROR
=item Can't close $filespec for reading: $OS_ERROR

An error occurred opening or closing the file $filespec. Possibly the file is
locked in another application, or there was some other operating system error.

=item Unable to determine columns of $table in $filespec (never found a line with the right number)

The program searched through the whole file and never found a line with
the right number of fields for that row. Each table has a fixed number of fields,
found in the HastusASI definition.  If no row has the proper number of 
fields, probably the file is corrupt or incorrectly specified. (It is also
possible that every row has data with a comma inside the data, but this
is unlikely.)

=item  Couldn't return seek position to top of $file

After searching through the file for a row with the right number of fields 
for each rowtype, the program received an input/ouptut error when trying to move
the next-line pointer back to the top of the file.

=back

=head2 WARNINGS

=over

=item Incorrect table type $rowtype in file $file, row $INPUT_LINE_NUMBER

An unrecognized table type was found in this file.  (It is probably not
an HSA file.) This row will be skipped.

=back

=head1 DEPENDENCIES

=over

=item perl 5.012

=item Moose

=item MooseX::SemiAffordanceAccessor

=item MooseX::StrictConstructor

=item Readonly

=item Actium::Constants

=item Actium::Files

=item Actium::Files::SQLite

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
