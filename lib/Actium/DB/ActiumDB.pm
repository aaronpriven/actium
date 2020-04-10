package Actium::DB::ActiumDB 0.015;

# FileMaker database read via ODBC
# Specific databases will (usually) be subclasses of this one

use Actium ('class');

extends 'Actium::DB::FileMaker_ODBC';

const my $KEYFIELD_TABLE          => 'FMTableKeys';
const my $KEY_OF_KEYFIELD_TABLE   => 'FMTableKey';
const my $TABLE_OF_KEYFIELD_TABLE => 'FMTable';

has '_keys_of_r' => (
    traits   => ['Hash'],
    is       => 'rw',
    init_arg => undef,
    isa      => 'HashRef[Str]',
    default  => sub { {} },
    handles  => { key_of_table => 'get', },
);

method _build_keys_of {
    my $dbh = $self->dbh;

    my $query
      = "SELECT $TABLE_OF_KEYFIELD_TABLE, $KEY_OF_KEYFIELD_TABLE FROM $KEYFIELD_TABLE";
    my $rows_r  = $dbh->selectall_arrayref($query);
    my %keys_of = Actium::flatten($rows_r);

    _set_keys_of_r( \%keys_of );
    return;

}

after _connect {
    $self->_build_keys_of();
}

Actium::immut;

__END__

=encoding utf8

=head1 NAME

Actium::DB::ActiumDB - class for the Actium database

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
  
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS or ATTRIBUTES

=head2 subroutine

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
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

The Actium system, and...

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https://github.com/aaronpriven/actium/issues|https://github.com/aaronpriven/actium/issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2018

This program is free software; you can redistribute it and/or modify it under
the terms of either:

=over 4

=item *

the GNU General Public License as published by the Free Software Foundation;
either version 1, or (at your option) any later version, or

=item *

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.





head1 NAME

Actium::Files::FileMaker_ODBC - role for reading from a FileMaker database
via ODBC drivers

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use Actium::Files::RoleComposer;
            
 my $db = Actium::Files::RoleComposer->new();
      
 $row_hr = $db->row('Column' , 'Keyvalue');
 $othervalue = $row_hr->{OtherValue};
   
=head1 DESCRIPTION

Actium::Files::FileMaker_ODBC is a role for reading data from a
FileMaker database, over the network using ODBC. It uses L<DBI|DBI> and
L<DBD::ODBC|DBD::ODBC>.

=head1 METHODS

=head2 Methods that must be provided by the consuming class

=over

=item B<db_name>

The name used in the ODBC driver.

=item B<db_user>

The user name passed to the ODBC driver.

=item B<db_password>

The password passed to the ODBC driver.

=item B<key_of_table(I<table>)>

This method returns the name of the key column, if any, associated with
he given table. It must be a regular column that comes from the data, 
although someday it may be allowed to provide multiple columns that are
combined to form the key.

This method, as defined in the consuming role, can assume that the
database has been connected first. This allows the keys to be defined
in the database itself rather than in the program or in other
configuration files.

=back

=head2 Methods in Actium::Files::FileMaker_ODBC

=over

=item B<dbh()>

Provides the database handle associated with this database. See
L<DBI|DBI> for information on the database handle.

=item B<row(I<table>, I<keyvalue>)>

Fetches the row of the table where the value of the key column is the
specified value.  (DBI will be happy to provide the "first" row if
there is more than one row with that value, but which row is first is
undefined. It is recommended for use only on rows with unique values in
the key.)

The row is provided as a hash reference, where the keys are the column
names and the values are the values for this row.

=item B<each_row(I<table>)>

=item B<each_row_eq(I<table>, I<column>, I<value>)>

=item B<each_row_like(I<table>, I<column>, I<match>)>

=item B<each_row_where(I<table>, I<where>, I<match> ...)>

The each_row routines return an subroutine reference allowing iteration
 through each row. Intended for use in C<while> loops:

 my $eachtable = $database->each_row("table");
 while (my $row_hr = $eachtable->() ) {
    do_something_with_value($row_hr->{SomeColumn});
 }

The rows are provided as hash references, where the keys are the column
names and the values are the values for this row.

each_row provides every row in the table.

each_row_eq provides every row where the column specified is equal to
the value specified.

each_row_like provides every row where the column specified matches the
SQL LIKE pattern matching characters. ("%" matches a sequence of zero
or more characters, and "_" matches any single character.)

each_row_where is more flexible, allowing the user to specify any WHERE
clause. It accepts multiple values for matching. It is necessary to
specify the WHERE keyword in the SQL.

=item B<each_columns_in_row_where(I<...>)>

Similar to the other I<each_> routines, I<each_columns_in_row_where> 
returns a subroutine reference allowing iteration through each row.

Unlike those routines, this allows the specification of specific
columns,  and returns an array reference instead of a hash reference.
(Note: the array reference is B<the same for each row>, so to retain
the data between calls you must copy the data and not merely keep the a
reference.)

It takes a hash or a hashref of named parameters:

=over

=item table

The required name of the SQL table.

=item where

An optional SQL "WHERE" clause. It accepts multiple values for
matching.  It is necessary to specify the WHERE keyword in the SQL.

=item columns

A (required) reference to an array of column names.

=item bind_values

Optional reference to array of values to be put into placeholders in
the SQL WHERE statement.

=back

=item B<all_in_column_key(I<table>, I<column> )>

=item B<all_in_column_key(I<hashref_of_arguments>)>

all_in_column_key provides a convenient way of getting data in a hash.
It is used where only one field is required from the database, and
where the  amount of data desired can be loaded into memory. It is
normally used this way:

 my $hashref = $database->all_in_column_key(qw/table column/);
 $value = $hashref->{$row_value};

The method returns a hashref. The keys are the key value from the
column, and the values are the values of the column specified.

The results are undefined if there is no valid key for this table.

Normally, it is invoked with a flat list of arguments: the first
argument is the table and the remaining argument is a column from the
table.  Alternatively, it can be invoked with named arguments in a hash
reference:

 my $hashref = $database->all_in_column_key( {
      TABLE => 'table' ,
      COLUMN => 'column' ,
      WHERE => 'COLUMN = ?',
      BIND_VALUES => [ $value ] ,
      });

TABLE is the name of the table. COLUMN is the column from the table.
WHERE is optional, and allows specifying a subset of rows using an
SQLite WHERE clause. BIND_VALUES is also optional, but if present must
be an array reference of one or more values, which will be passed
through to SQLite unchanged. It is only useful if the WHERE clause will
take advantage of the bound values.

=item B<all_in_columns_key>(I<table>, I<column>, I<column> , ... )

=item B<all_in_columns_key>(I<hashref_of_arguments>)

all_in_columns_key provides a convenient way of getting data in a
two-level hash structure, and is commonly used where the amount of data
desired  can be loaded into memory. It is normally used this way:

 my $hashref = $database->all_in_columns_key(qw/table column_one column_two/);
 $column_one_value = $hashref->{$row_value}{'column_one'}

The method returns a hashref. The keys are the key value from the
column, and the values are themselves hashrefs. In that second layer
hashref,  the keys are the column names, and the values are the values.
It can be thought of as a two-dimensional hash, where the first
dimension is the key value of the row, and the second dimension the
column name.

The results are undefined if there is no valid key for this table.

Normally, it is invoked with a flat list of arguments: the first
argument is the table and the remaining arguments are columns from the
table.  Alternatively, it can be invoked with named arguments in a hash
reference:

 my $hashref = $database->all_in_columns_key( {
      TABLE => 'table' ,
      COLUMNS => [ qw/column_one column_two/ ] ,
      WHERE => 'COLUMN = ?',
      BIND_VALUES => [ $value ] ,
      });

TABLE is the name of the table. COLUMNS must be an array reference with
a list of columns from the table. WHERE is optional, and allows
specifying a subset of rows using an SQLite WHERE clause. BIND_VALUES
is also optional, but if present must be an array reference of one or
more values, which will be passed through to SQLite unchanged. It is
only useful if the WHERE clause will take advantage of the bound
values.

=item load_tables

Documentation to be done...

Call with

 load_tables (
   requests => {
      table1 => { 
           index_field => 'index_field',
           array => \@array,
           hash => \%hash,
           ignoredupe => 0, # or 1
      },
      table2 => { etc. },
   },
 )


=back

=head1 DIAGNOSTICS

=over

=item Can't use row() on table $table with no key

Another module called the B<row> method, specifying a table with  no
key. This is not valid.

=item Invalid column $column for table $table

A request specified a column that was not found in the specified table.

=item Invalid table $table for database $db_name

A request specified a table that was not found for the specified
database type.

=back

=head1 DEPENDENCIES

=over 

=item perl 5.012

=item DBI

=item DBD::ODBC

=item Actium

=item Moose and Moose::Role

=item FileMaker Pro or FileMaker Server Advanced. Tested with version 12.

=back

