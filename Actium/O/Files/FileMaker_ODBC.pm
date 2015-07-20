# Actium/O/Files/FileMaker_ODBC.pm

# Role for reading and processing FileMaker Pro databases via ODBC

# Legacy stage 4

package Actium::O::Files::FileMaker_ODBC 0.010;

use Actium::MooseRole;

use Params::Validate(':all');    ### DEP ###

use Carp;
use DBI;                         ### DEP ###
# DBD::ODBC ### DEP ###

# Required methods in consuming classes:

requires(qw/db_name db_user db_password key_of_table/);

# db_name =>  ODBC database name,
# db_user => username,
# db_password => password

# key_of_table is the key column, if any, of a particular table.

const my $META_TABLES => 'FileMaker_Tables';
const my $META_FIELDS => 'FileMaker_Fields';

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

sub _connect {
    my $self = shift;

    my $db_name     = $self->db_name;
    my $db_user     = $self->db_user;
    my $db_password = $self->db_password;

    my $cry = cry("Connecting to database $db_name");

    my $dbh = DBI->connect( "dbi:ODBC:$db_name", $db_user, $db_password,
        { RaiseError => 1, PrintError => 1, AutoCommit => 0 } );

    $dbh->{odbc_utf8_on} = 1;
    # ODBC driver has to be set to return utf-8

    $cry->done;

    return $dbh;

} ## tidy end: sub _connect

has '_tables_r' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[Str]',
    builder => '_build_tables',
    handles => {
        tables     => 'keys',
        is_a_table => 'get',
    },
    lazy => 1,
);

sub _build_tables {
    my $self = shift;
    my $dbh  = $self->dbh;

    my $statement
      = "SELECT TableName from $META_TABLES WHERE TableName = BaseTableName";

    my $ary_ref    = $dbh->selectall_arrayref($statement);
    my @tables     = flatten $ary_ref;
    my %is_a_table = map { $_, 1 } @tables;

    return \%is_a_table;

}

has '_column_cache_r' => (
    traits => ['Hash'],
    is     => 'bare',
    isa    => 'HashRef[HashRef[Str]]',
    # { table => { column1 => 1, ...} , ... }
    handles => {
        _columns_loaded            => 'exists',
        _column_cache_of_table     => 'get',
        _set_column_cache_of_table => 'set',
    },

);

sub ensure_loaded {
    goto &_ensure_loaded;
}

sub _ensure_loaded {
    my ( $self, $table ) = @_;

    if ( $self->is_a_table($table) ) {

        if ( not $self->_columns_loaded($table) ) {
            $self->_load_column_cache($table);
        }

        return;
    }

    my $db_name = $self->db_name;
    croak "Invalid table $table for database $db_name";

}

sub _load_column_cache {
    my $self  = shift;
    my $table = shift;

    my $dbh = $self->dbh;

    my $query = "SELECT FieldName from $META_FIELDS WHERE TableName = '$table'";
    my $ary_ref = $dbh->selectall_arrayref($query);
    my @columns = flatten $ary_ref;

    my %is_a_column = map { $_, 1 } @columns;
    $self->_set_column_cache_of_table( $table, \%is_a_column );

    return;

}

sub columns_of_table {
    my $self  = shift;
    my $table = shift;

    $self->_ensure_loaded($table);

    my $cacheref = $self->_column_cache_of_table($table);

    return keys %{$cacheref};
}

sub is_a_column {
    my ( $self, $table, $column ) = @_;
    $self->_ensure_loaded($table);

    my $cacheref = $self->_column_cache_of_table($table);
    return exists $cacheref->{$column};
}

sub _check_columns {
    my ( $self, $table, @input_columns ) = @_;
    $self->_ensure_loaded($table);
    my $cacheref = $self->_column_cache_of_table($table);
    foreach my $input (@input_columns) {
        croak "Invalid column $input for table $table"
          if not exists $cacheref->{$input};
    }
    return;
}

#########################################
### SQL -- PROVIDE ROWS TO CALLERS, OTHER SQL
#########################################

# much of this should be farmed out to a new sql::common module

sub row {
    my ( $self, $table, $keyvalue ) = @_;
    my $key = $self->key_of_table($table);
    croak "Can't use row() on table $table with no key"
      unless $key;
    $self->_ensure_loaded($table);
    my $dbh   = $self->dbh();
    my $query = "SELECT * FROM $table WHERE $key = ?";
    return $dbh->selectrow_hashref( $query, {}, $keyvalue );
}

sub each_row {
    my ( $self, $table ) = @_;
    return $self->each_row_where($table);
}

sub each_row_like {
    my ( $self, $table, $column, $like ) = @_;
    $self->_check_columns( $table, $column );
    return $self->each_row_where( $table,
        "WHERE $column LIKE ? ORDER BY $column", $like );
}

sub each_row_eq {
    my ( $self, $table, $column, $value ) = @_;
    $self->_check_columns( $table, $column );
    return $self->each_row_where( $table, "WHERE $column = ?", $value );
}

sub each_row_where {
    my ( $self, $table, $where, @bind_values ) = @_;

    $self->_ensure_loaded($table);
    my $dbh   = $self->dbh();
    my $query = "SELECT * FROM $table ";
    if ($where) {
        $query .= $where;
    }

    my $sth = $dbh->prepare($query);
    $sth->execute(@bind_values);

    return sub {
        my $result = $sth->fetchrow_hashref;
        $sth->finish() if not $result;
        return $result;
    };
}

sub each_columns_in_row_where {

    my $self = shift;

    my %params = validate(
        @_,
        {   table   => 1,
            columns => { type => ARRAYREF, required => 1 },
            where       => { default => '' },
            bind_values => { type    => ARRAYREF, default => [] },
        }
    );

    my $table       = $params{table};
    my @columns     = @{ $params{columns} };
    my $where       = $params{where};
    my @bind_values = @{ $params{bind_values} };

    my $columns_list;
    if (@columns) {
        $self->_check_columns( $table, @columns );
        $columns_list = join( " , ", @columns );

    }
    else {
        $columns_list = ' * ';
    }

    $self->_ensure_loaded($table);
    my $dbh   = $self->dbh();
    my $query = "SELECT $columns_list FROM $table $where";

    my $sth = $dbh->prepare($query);
    $sth->execute(@bind_values);

    return sub {
        my $result = $sth->fetchrow_arrayref;
        $sth->finish() if not $result;
        return $result;
    };

} ## tidy end: sub each_columns_in_row_where

sub all_in_column_key {

    my $self     = shift;
    my $firstarg = shift;

    my ( $table, $column, $where, @bind_values );

    if ( ref($firstarg) eq 'HASH' ) {
        $table = $firstarg->{TABLE};

        $column = $firstarg->{COLUMN};

        $where = $firstarg->{WHERE};

        my $bindval_r = $firstarg->{BIND_VALUES};
        @bind_values = @{$bindval_r}
          if defined $bindval_r;

    }
    else {
        $table  = $firstarg;
        $column = shift;
    }

    $self->_ensure_loaded($table);
    $self->_check_columns( $table, $column );

    my $key = $self->key_of_table($table);

    my $dbh = $self->dbh;

    my $selection_cmd = "SELECT $key, $column FROM $table";
    $selection_cmd .= " WHERE $where" if defined $where;

    my $list_r
      = $dbh->selectcol_arrayref( $selection_cmd, { Columns => [ 1, 2 ] },
        @bind_values );

    my %value_of = @{$list_r};
    return \%value_of;

} ## tidy end: sub all_in_column_key

sub all_in_columns_key {
    my $self = shift;

    my $firstarg = shift;

    my ( $table, @columns, $where, @bind_values );

    if ( ref($firstarg) eq 'HASH' ) {
        $table = $firstarg->{TABLE};

        @columns = flatten( $firstarg->{COLUMNS} );

        $where = $firstarg->{WHERE};

        my $bindval_r = $firstarg->{BIND_VALUES};
        @bind_values = @{$bindval_r}
          if defined $bindval_r;

    }
    else {
        $table   = $firstarg;
        @columns = flatten(@_);
    }

    $self->_ensure_loaded($table);
    $self->_check_columns( $table, @columns );

    my $key = $self->key_of_table($table);
    unshift @columns, $key;
    @columns = uniq(@columns);

    my $dbh = $self->dbh;

    #my %column_index_of = map { $columns[$_] => $_ } ( 0 .. $#columns );

    my $selection_cmd = "SELECT " . join( q{ , }, @columns ) . " FROM $table";

    $selection_cmd .= " WHERE $where" if defined $where;

    my $rows_r
      = $dbh->selectall_hashref( $selection_cmd, $key, {}, @bind_values );
    return $rows_r;

} ## tidy end: sub all_in_columns_key

sub DEMOLISH { }

before DEMOLISH => sub {
    my $self = shift;
    return unless $self->has_connected;
    my $dbh = $self->dbh;
    $dbh->disconnect();
    return;
};

sub load_tables {
    my $self   = shift;
    my %params = @_;

    my %request_of = %{ $params{requests} };
    my $actium_dbh = $self->dbh;

    foreach my $table ( sort keys %request_of ) {

        my $tablecry = cry("Loading from $table");

        my $datacry = cry("Selecting data from table $table");

        my $fields;

        if ( exists( $request_of{$table}{fields} ) ) {
            $fields = join( ', ', @{ $request_of{$table}{fields} } );
            $datacry->text("Fields: $fields");
        }
        else {
            $fields = '*';
        }

        my $result_ref
          = $actium_dbh->selectall_arrayref( "SELECT $fields FROM $table",
            { Slice => {} } );

        $datacry->done;

        if ( exists $request_of{$table}{array} ) {

            my $arraycry = cry("Processing $table into array");
            @{ $request_of{$table}{array} } = @{$result_ref};
            # this is to make sure the same array that was passed in
            # gets the results
            $arraycry->done;
        }

        # process into hash

        if (    exists $request_of{$table}{index_field}
            and exists $request_of{$table}{hash} )
        {

            my $ignoredupe = $request_of{$table}{ignoredupe};
            $ignoredupe //= 1;
            my $process_dupe = not $ignoredupe;

            my $hashcry = cry("Processing $table into hash");

            my $hashref     = $request_of{$table}{hash};
            my $index_field = $request_of{$table}{index_field};

            if ($process_dupe) {

                my $dupecry
                  = cry(
"Determining whether duplicate index field ($index_field) entries"
                  );

                my @all_indexes = @{
                    $actium_dbh->selectcol_arrayref(
                        "SELECT $index_field from $table")
                };

                if ( ( uniq @all_indexes ) == @all_indexes ) {
                    # indexes are all unique
                    $process_dupe = 0;
                    $dupecry->d_no;
                }
                else {
                    $dupecry->d_yes;
                }
            } ## tidy end: if ($process_dupe)

            foreach my $row_hr ( @{$result_ref} ) {

                my $index_value = $row_hr->{$index_field};
                if ($process_dupe) {
                    push @{ $hashref->{$index_value} }, $row_hr;
                }
                else {
                    $hashref->{$index_value} = $row_hr;
                }

            }

            $hashcry->done;

        } ## tidy end: if ( exists $request_of...)

        $tablecry->done;

    } ## tidy end: foreach my $table ( sort keys...)

} ## tidy end: sub load_tables

1;

__END__

head1 NAME

Actium::O::Files::FileMaker_ODBC - role for reading from a FileMaker database
via ODBC drivers

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use Actium::O::Files::RoleComposer;
            
 my $db = Actium::O::Files::RoleComposer->new();
      
 $row_hr = $db->row('Column' , 'Keyvalue');
 $othervalue = $row_hr->{OtherValue};
   
=head1 DESCRIPTION

Actium::O::Files::FileMaker_ODBC is a role for reading data from a FileMaker database,
over the network using ODBC. It uses L<DBI|DBI> and L<DBD::ODBC|DBD::ODBC>.

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

This method returns the name of the key column, if any, associated
with he given table. It must be a regular column that comes from the data, 
although someday it may be allowed to provide multiple columns that are combined
to form the key.

This method, as defined in the consuming role, can assume that the database
has been connected first. This allows the keys to be defined in the database
itself rather than in the program or in other configuration files.

=back

=head2 Methods in Actium::O::Files::FileMaker_ODBC

=over

=item B<dbh()>

Provides the database handle associated with this database. See
L<DBI|DBI> for information on the database handle.

=item B<row(I<table>, I<keyvalue>)>

Fetches the row of the table where the value of the key column is the
specified value.  (DBI will be happy to provide the "first" row if there
is more than one row with that value, but which row is first is undefined.
It is recommended for use only on rows with unique values in the key.) 

The row is provided as a hash reference, where the keys are the
column names and the values are the values for this row.

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

The rows are provided as hash references, where the keys are the
column names and the values are the values for this row.

each_row provides every row in the table.

each_row_eq provides every row where the column specified is equal to the
value specified.

each_row_like provides every row where the column specified matches
the SQL LIKE pattern matching characters. ("%" matches a sequence
of zero or more characters, and "_" matches any single character.)

each_row_where is more flexible, allowing the user to specify any
WHERE clause.
It accepts multiple values for matching. It is necessary to specify the WHERE
keyword in the SQL.

=item B<each_columns_in_row_where(I<...>)>

Similar to the other I<each_> routines, I<each_columns_in_row_where> 
returns a subroutine referenceu allowing iteration through each row.

Unlike those routines, this allows the specification of specific columns, 
and returns an array reference
instead of a hash reference. (Note: the array reference is B<the same for each
row>, so to retain the data between calls you must copy the data and not merely
keep the a reference.)

It takes a hash or a hashref of named parameters:

=over

=item table

The required name of the SQL table.

=item where

An optional SQL "WHERE" clause. It accepts multiple values for matching. 
It is necessary to specify the WHERE keyword in the SQL.

=item columns

A (required) reference to an array of column names.

=item bind_values

Optional reference to array of values to be put into placeholders in the SQL
WHERE statement.

=back

=item B<all_in_column_key(I<table>, I<column> )>

=item B<all_in_column_key(I<hashref_of_arguments>)>

all_in_column_key provides a convenient way of getting data in a hash.
It is used where only one field is required from the database, and where the 
amount of data desired can be loaded into memory. It is normally used this way:

 my $hashref = $database->all_in_column_key(qw/table column/);
 $value = $hashref->{$row_value};

The method returns a hashref. The keys are the key value from the
column, and the values are the values of the column specified.

The results are undefined if there is no valid key for this table.

Normally, it is invoked with a flat list of arguments: the first argument is
the table and the remaining argument is a column from the table. 
Alternatively, it can be invoked with named arguments in a hash reference:

 my $hashref = $database->all_in_column_key( {
      TABLE => 'table' ,
      COLUMN => 'column' ,
      WHERE => 'COLUMN = ?',
      BIND_VALUES => [ $value ] ,
      });

TABLE is the name of the table. COLUMN is the column from the table.
WHERE is optional, and allows
specifying a subset of rows using an SQLite WHERE clause. BIND_VALUES
is also optional, but if present must be an array reference of one
or more values, which will be passed through to SQLite unchanged.
It is only useful if the WHERE clause will take advantage of the
bound values.

=item B<all_in_columns_key>(I<table>, I<column>, I<column> , ... )

=item B<all_in_columns_key>(I<hashref_of_arguments>)

all_in_columns_key provides a convenient way of getting data in a two-level
hash structure, and is commonly used where the amount of data desired 
can be loaded into memory. It is normally used this way:

 my $hashref = $database->all_in_columns_key(qw/table column_one column_two/);
 $column_one_value = $hashref->{$row_value}{'column_one'}

The method returns a hashref. The keys are the key value from the
column, and the values are themselves hashrefs. In that second layer hashref, 
the keys are the column names, and the values are the values. It can be
thought of as a two-dimensional hash, where the first dimension is the key
value of the row, and the second dimension the column name.

The results are undefined if there is no valid key for this table.

Normally, it is invoked with a flat list of arguments: the first argument is
the table and the remaining arguments are columns from the table. 
Alternatively, it can be invoked with named arguments in a hash reference:

 my $hashref = $database->all_in_columns_key( {
      TABLE => 'table' ,
      COLUMNS => [ qw/column_one column_two/ ] ,
      WHERE => 'COLUMN = ?',
      BIND_VALUES => [ $value ] ,
      });

TABLE is the name of the table. COLUMNS must be an array reference
with a list of columns from the table. WHERE is optional, and allows
specifying a subset of rows using an SQLite WHERE clause. BIND_VALUES
is also optional, but if present must be an array reference of one
or more values, which will be passed through to SQLite unchanged.
It is only useful if the WHERE clause will take advantage of the
bound values.

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

Another module called the B<row> method, specifying a table with 
no key. This is not valid.

=item Invalid column $column for table $table

A request specified a column that was not found in the specified table.

=item Invalid table $table for database $db_name

A request specified a table that was not found for the specified database type.

=back

=head1 DEPENDENCIES

=over 

=item perl 5.012

=item DBI

=item DBD::ODBC

=item Actium::MooseRole

=item FileMaker Pro or FileMaker Server Advanced. Tested with version 12.

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2014

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
