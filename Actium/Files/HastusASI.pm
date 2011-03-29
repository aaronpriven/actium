# Actium/Files/HastusASI.pm

# Class for reading and processing Hastus Standard AVL files
# and storing in an SQLite database using Actium::Files::SQLite

# Subversion: $Id$

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
use DBI;
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
#    qw/db_type keycolumn_of_table columns_of_table tables
#       _load _files_of_filetype _tables_of_filetype/
#);

#########################################
### DEFINITION
#########################################

# db_type required by SQLite role
sub db_type () {'HastusASI'}

has '_definition' => (
    is       => 'bare',
    init_arg => undef,
    isa      => 'Actium::Files::HastusASI::Definition',
    default  => Actium::Files::HastusASI::Definition->instance,
    handles  => {
        columns_of_table            => 'columns_of_table',
        keycolumn_of_table          => 'keycolumn_of_table',
        tables                      => 'tables',
        _create_query_of_table      => 'create_query_of_table',
        _filetype_of                => 'filetype_of',
        _filetype_of_table          => 'filetype_of_table',
        _filetypes                  => 'filetypes',
        _has_composite_key          => 'has_composite_key',
        _has_repeating_final_column => 'has_repeating_final_column',
        _index_query_of_table       => 'index_query_of_table',
        _insert_query_of_table => 'insert_query_of_table',
        _key_components_idxs   => 'key_components_idxs',
        _parent_of_table       => 'parent_of_table',
        _table_of              => 'table_of',
        _tables_of_filetype    => 'tables_of_filetype',

    },
);

######################################
### FILES LIST
######################################

has '_files_of_filetype_r' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]]',
    handles => { '_files_of_filetype_r' => 'get' },
    builder => '_build_files_list',
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
        my @files = grep ( {/\.$filetype/sx} @all_files );
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

    my ( %sth_of, %parent_of, %key_column_order_of, %has_composite_key,
        %has_repeating_final_column );
    foreach my $table ( $self->_tables_of_filetype($filetype) ) {

        my @queries = (
            $self->_create_query_of_table($table),
            $self->_index_query_of_table($table),
        );
        $dbh->do($_) foreach @queries;

        $sth_of{$table} = $dbh->prepare( $self->insert_query_of_table($table) );
        $parent_of{$table}         = $self->_parent_of_table($table);
        $has_composite_key{$table} = $self->_has_composite_key($table);
        $has_repeating_final_column{$table}
          = $self->_has_repeating_final_column($table);
        $key_column_order_of{$table}
          = $self->_key_column_order_of_table($table);

    }

    my $sequence = 0;
    $self->begin_transaction;

  FILE:
    foreach my $file (@files) {

        my $filespec = $self->flat_filespec($file);

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
            unless ( _filetype_of_table($table) eq $filetype ) {
                carp "Incorrect row type $table in file $filespec, "
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
                  jk( @columns[ @{ $key_column_order_of{$table} } ] );
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
    my ( $self, $fh, $filetype, $filespec ) = @_;

    my %template_of;

    # determine number of columns
    foreach my $table ( $self->_tables_of_filetype($filetype) ) {
        my $numcolumns = scalar( columns($table) ) + 1;    # add one for table
        $numcolumns += $EXTRA_FIELDS_WHEN_REPEATING
          if $self->has_repeating_final_column($table);

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
              . "(never found a line with the right number)";
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

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 OPTIONS

A complete list of every available command-line option with which
the application can be invoked, explaining what each does and listing
any restrictions or interactions.

If the application has no options, this section may be omitted.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

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
