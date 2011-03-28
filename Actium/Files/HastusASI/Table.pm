# Actium/Files/HastusASI/Table.pm

# Class for Hastus ASI tables

# Subversion: $Id$

# Legacy stage 4

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI::Table 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

#########################
### GENERAL ATTRIBUTES
#########################

has [qw[ id filetype ]] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'parent' => (
    is      => 'ro',
    isa     => 'Str',
    default => undef,
);

has 'children_r' => (
    is      => 'bare',
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { children => 'elements' },
);

#####################
### COLUMN ATTRIBUTES
#####################

has 'columns_r' => (
    is       => 'bare',
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    required => 1,
    handles  => {
        columns       => 'elements',
        column_number => 'get',
    },
);

has 'column_idx_of_r' => (
    is       => 'bare',
    init_arg => undef,
    traits   => ['Hash'],
    isa      => 'HashRef[Int]',
    builder  => '_build_column_idx_of',
    lazy     => 1,
    handles  => {
        column_idx_of   => 'get',
        column_idx_hash => 'elements',
    },
);

sub _build_column_idx_of {
    my $self = shift;
    my %index_of;
    my @columns = $self->columns;
    foreach my $idx ( 0 .. $#columns ) {
        $index_of{ $columns[$idx] } = $idx;
    }
    return \%index_of;
}

has 'column_length_of_r' => (
    is       => 'bare',
    traits   => ['Hash'],
    isa      => 'HashRef[Int]',
    required => 1,
    handles  => {
        column_length_of   => 'get',
        column_length_hash => 'elements',
    },
);

has 'has_repeating_final_column' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

#########################
### KEY COLUMN ATTRIBUTES
#########################

has 'key_column' => (
    is       => 'bare',
    init_arg => undef,
    isa      => 'Str',
    builder  => '_build_key_column',
    lazy     => 1,
);

sub _build_key_column {
    my $self           = shift;
    my @key_components = $self->key_components;
    given ( scalar @key_components ) {
        when (0) {
            return;
        }
        when (1) {
            return $key_components[0];
        }
    }
    
    my $id = $self->id;
    return "${id}_key";
}

has 'key_components_r' => (
    is      => 'bare',
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { key_components => 'elements' },
);

has 'has_composite_key' => (
    is       => 'bare',
    isa      => 'Bool',
    builder  => '_build_has_composite_key',
    lazy     => 1,
    init_arg => undef,
);

sub _build_has_composite_key {
    my $self           = shift;
    my @key_components = $self->key_components;
    return 1 if ( scalar @key_components > 1 );
    return;
}

has 'key_components_idxs_r' => (
    is      => 'bare',
    traits  => ['Array'],
    isa     => 'ArrayRef[Int]',
    builder => '_build_key_components_idxs',
    lazy    => 1,
    handles => { key_components_idxs => 'elements', },
);

sub _build_key_components_idxs {
    my $self = shift;

    my @key_components_idxs;
    foreach my $column ( $self->key_components ) {
        push @key_components_idxs, $self->column_idx_of($column);
    }

    return \@key_components_idxs;

}

#######################
### SQL COMMMANDS
#######################

foreach my $attribute (qw[ sql_createcmd sql_insertcmd ]) {
    has $attribute => (
        is       => 'bare',
        init_arg => undef,
        isa      => 'Str',
        builder  => "_build_$attribute",
        lazy     => 1,
    );
}

has 'sql_idxcmd' => (
        is       => 'bare',
        init_arg => undef,
        isa      => 'Maybe[Str]',
        builder  => "_build_sql_idxcmd",
        lazy     => 1,
);

sub _build_sql_createcmd {
    my $self    = shift;
    my @columns = $self->_sql_columns;
    my $id      = $self->id;
    return "CREATE TABLE $id (" . join( q{,}, @columns ) . q{)};

}

sub _build_sql_insertcmd {
    my $self    = shift;
    my @columns = $self->_sql_columns;
    my $id      = $self->id;
    return "INSERT INTO $id VALUES (" . join( q{,}, ('?') x @columns ) . ')';
}

sub _build_sql_idxcmd {
    my $self = shift;
    my $key  = $self->key_column();
    return unless $key;
    my $id = $self->id();
    return "CREATE INDEX idx_${id}_key ON $id ($key)";
}

has '_sql_columns_r' => (
    is       => 'ro',
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_sql_columns_r',
    handles  => { _sql_columns => 'elements' },
);

sub _build_sql_columns_r {
    my $self    = shift;
    my @columns = $self->columns;
    my $parent  = $self->parent;
    if ($parent) {
        unshift @columns, "${parent}_id INTEGER";
    }
    my $key = $self->keycolumn;
    if ( $key and $self->has_composite_key ) {
        push @columns, $key;
    }

    my $id = $self->id;
    unshift @columns, "${id}_id INTEGER PRIMARY KEY";

    return \@columns;

}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__


=head1 NAME

Actium::Files::HastusASI::Table - Class representing tables in 
Hastus AVL Standard Interface

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Files::HastusASI::Table;
 
 my $table_obj = 
     Actium::Files::HastusASI::Table->new(
         id => 'SHA',
         filetype => 'NET' ,
         parent => 'DIS',
         columns_r => [ qw/XCoordinate YCoordinate/ ] ,
         column_length_r => { XCoordinate => 10 , YCoordinate => 10 },
     );
 
 # (in another scope)
 
 my $table = $filetype_obj->id;
 my @columns = $filetype_obj->columns;

=head1 DESCRIPTION

Actium::Files::HastusASI::Table is a class holding information
on the tables in a Hastus AVL Standard Interface export. All objects
are read-only and are expected to be set during object construction.

It is intended to be used only from Actium::Files::HastusASI::Definition. All 
attributes and methods should be considered private to that module.

=head1 ATTRIBUTES and METHODS

=head2 General

=over

=item B<id>

Identifier for the table. This should be the same as the file's "Record"
('PAT' for the trip pattern description record, 'TPS' for the trip pattern
detail record, etc.). 

=item B<parent>

The parent table for this table, or undef if the table has no parent.
For example, "TPS" tables each have a parent "PAT" record.

=item B<children>

The names of the children tables of this table, if any. (The
constructor should specify children_r and provide a reference to
the list of names.) 

=item B<filetype>

The file type identifier for this table. For example, "DIS" and
"SHA" tables are found in the "NET" (itinerary) file.  

=back

=head2 Columns

=over

=item B<columns>

The names of the columns of the table, in order. 

=item B<column_number(I<idx>)>

Given an index n, returns the column name of the nth column.

=item B<column_idx_of(I<column>)>

Given a column name, returns the index of that column 
(what its position in order is).

=item B<column_idx_hash>

Returns a flattened hash. The column names are the keys, and the
values are each column's place in the order: the first column's
value is 0, the second's is 1, etc.

=item B<column_length_hash>

Returns a flattened hash. The the column names are the keys, and
the values are each column's length in bytes. Using this value is
deprecated since not all Hastus ASI data in the world actually fits
the specified lengths.

=item B<has_repeating_final_column>

This boolean flag indicates whether the last column in the field
definition is the first of 50 repeated entries. (I'm not sure why
the PPAT table is defined like this instead of using a subsidiary
table.) 

=back

=head2 Key columns

=over

=item B<key_column>

The column used as the key for this table, or undef if no key is
present.  For a composite key, the column will be a new column not
found in the original data, combining the various key columns.

=item B<has_composite_key>

This boolean flag indicates whether the key_column, if any, is a composite
key. (If false, either there is no key or the key is a single column from the
Hastus ASI data.) Defaults to 0.

=item B<key_components>

Returns a list of names of the columns of the component(s) of the key, if any. 
If the table has a single key column, it will have a single entry. 

=item B<key_components_idxs>

Returns a list of which places in the list of columns the component(s) of the 
key, if any, have. That is, if the second, fifth, and eighth columns are the 
components of the key, key_components_idx will be ( 1, 4, 7 ) .

=back

=head2 SQL commands

=over

=item B<sql_createcmd>

Returns a string containing an SQL command for creating this table in an 
SQLite database.

=item B<sql_insertcmd>

Returns a string containing an SQL command for inserting an entire row of data 
of this table into an SQLite database.

=item B<sql_createcmd>

Returns a string containing an SQL command for creating an index on the key 
column of this table. The index will be called "idx_<table name>_key". (This 
is true no matter what the key column actually is.) If there is no key for this 
table, the value is undef.

=back

=head1 OBJECT CONSTRUCTION

The following attributes should be specified in object construction:

=over

=item B<id> (required)

=item B<filetype> (required)

=item B<parent> (optional)

See L<the entries above under ATTRIBUTES and METHODS|/"ATTRIBUTES and METHODS">.

=item B<children_r> (optional)

A reference to a list of the names of the children tables of this table.
Defaults to an empty array.

=item B<columns_r> (required)

A reference to a list of the names of the columns.

=item B<column_length_of_r> (required)

A reference to a hash: the keys are the column names and the lengths are the 
length in bytes of each column. Currently required, although usage of these
values is deprecated.

=item B<has_repeating_final_column> (optional)

See L<the entry above under ATTRIBUTES and METHODS|/"ATTRIBUTES and METHODS">.
Defaults to false (0).

=item B<key_components_r> (optional)

A reference to a list of the names of the component(s) of the key, if any.
Defaults to the empty list.

=back

=head1 DEPENDENCIES

=over

=item * Moose

=item * MooseX::SemiAffordanceAccessor

=item * MooseX::StrictConstructor

=item * Perl 5.012

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