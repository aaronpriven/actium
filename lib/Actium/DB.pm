package Actium::DB 0.015;
# vimcolor: #300015

# role containing methods and attributes common to all types of database objects

use Actium ('role');

use DBI;    ### DEP ###

# Required methods in consuming classes:

requires(qw/_connect _fetch_table_names _make_table_obj/);

######################################
### CONNECT TO DATABASE
######################################

has 'dbh' => (
    init_arg  => undef,
    is        => 'ro',
    predicate => 'has_connected',
    isa       => 'DBI::db',
    builder   => '_connect',
    lazy      => 1,
);

# tables_r hash --
# keys to contain all tables
# values start off as undef, but then once somebody asks for a table,
# it's inflated into a table object

has '_tables_r' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[Maybe[Actium::DB::Table]]',
    builder => '_fetch_table_names',
    handles => {
        table_names => 'keys',
        is_a_table  => 'exists',
        _set_table  => 'set',
        _table      => 'get',
    },
);

method _add_table (Str :$table_name!, :$table? ) {
    croak "Can't add $table_name: Table by that name already exists"
      if $self->is_a_table($table_name);
    $self->_set_table( $table_name, $table );
}

method table (Str $table_name!) {
    my $table = $self->_table($table_name);
    return $table if defined $table;
    $table = $self->_make_table_obj($table_name);
    $self->_set_table($table);
    return $table;
}

method quote_identifiers (@identifiers) {
    return map { q{"} . $_ . q{"} } @identifiers;
}

1;

__END__

=encoding utf8

head1 NAME

Actium::DB - role for common database behaviors

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 # in a composing class

 package SomeDB 0.001;
 use Actium('class');
 with 'Actium::DB';

 sub _connect { 
    return DBI->connect('something');
 }

 # using the composed class
 
 use SomeDB;
 my $db = SomeDB->new();
 my @tables = $db->tables;

=head1 DESCRIPTION

Actium::DB is a role that covers behaviors common to all databases
using DBI: both SQLite and FileMaker.

=head1 REQUIRED METHODS

These are methods that must be provided by the consuming class.

=head2 _connect

This method must connect to the database and return a DBI database
handle.

=head2 _fetch_table_names 

This method must query the database and return all the table names.

=head2 _make_table_object

 my $table = $self->_make_table_object($table_name);

This method must return the table object that should be associated with
the specified table name.

=head1 PROVIDED PUBLIC METHODS AND ATTRIBUTES

=head2 dbh

This Moose attribute returns the DBI database handle.

=head2 is_a_table

 say "Is a table" if is_a_table('table_name');

This returns true if the passed parameter is a valid table in the
database.

=head2 table_names

This method returns the names of the tables known to be in the
database.

=head1 PROVIDED SEMI-PRIVATE METHODS AND ATTRIBUTES

These are intended to be used only within consuming classes.

=head2 _add_table

 _add_table (table_name => 'this_table', table => $some_table);

This method adds a table to the database. There are two named
parameters. 'table_name' is required and is the name of the table.
'table' is optional, and is the object representing the table. (If it
is not provided, then if it is requested the method '_make_table_obj'
will be invoked.)

This is intended to be used only by consuming classes, which are
responsible for actually creating the table in their databases using
the appropriate SQL via DBI.

=head1 DIAGNOSTICS

=head2 Can't add $table_name: Table by that name already exists"

An attempt was made to add a table whose name already exists in the
list of tables this database contains.

=head1 DEPENDENCIES

The Actium system, and L<DBI|DBI>.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https://github.com/aaronpriven/actium/issues|https://github.com/aaronpriven/actium/issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item *

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item *

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

