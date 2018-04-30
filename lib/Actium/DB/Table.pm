package Actium::DB::Table 0.015;
# vimcolor: #300015

# class representing a table in a SQL database

use Actium ('class');

###################
### Attributes
###################

# Parent database
has db => (
    required => 1,
    weak_ref => 1,
    is       => 'ro',
    does     => 'Actium::DB',
    handles  => [qw /dbh quote_identifiers/],
);

has name => (
    isa      => 'Str',
    required => 1,
    is       => 'ro',
);

method name_quoted {
    return $self->quote_identifiers( $self->name );
}

has _columns_r => (
    is       => 'ro',
    init_arg => 'columns',
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    required => 1,
    handles  => { columns => 'elements', },
);

has keycolumn => ( is => 'ro', );

has _cache_columns_r => (
    is       => 'ro',
    init_arg => 'cache_columns',
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    default  => sub { [] },
    handles  => { _cache_columns => 'elements', },
);

has _cache_r => (
    traits   => ['Hash'],
    is       => 'ro',
    init_arg => undef,
    isa      => 'HashRef[HashRef]',
    handles  => {
        "cache_row_r"   => 'get',
        "cache_has_row" => 'exists',
        "cache_keys"    => 'keys',
    },
    builder => "_build_cache",
    lazy    => 1,
);

method _build_cache ($item) {
    return $self->selectall_hoh( columns => $self->_cache_columns_r );
}

###################################
### Methods returning all records
###################################

method selectall_hoh (
    :$keycolumn? , :\@columns = [] , :$where = $EMPTY, \:@bind_values = []
    ) {

    if ( defined $keycolumn ) {
        $self->_check_columns($keycolumn);
    }
    else {
        $keycolumn = $self->keycolumn;
        if ( not defined $keycolumn ) {
            croak "Can't use selectall_hoh on table "
              . $self->name
              . ' without specifying a key column';
        }
    }

    my $columns = $self->columns_for_sql(@columns);
    my $selection_cmd
      = "SELECT $columns FROM " . $self->name_quoted . " $where";

    return $self->dbh->selectall_hashref( $selection_cmd, $keycolumn, {},
        @bind_values );

}

method selectall_hash (
     :$keycolumn? , :$column!, :$where = $EMPTY, :\@bind_values = []
     ) {

    if ( defined $keycolumn ) {
        $self->_check_columns($keycolumn);
    }
    else {
        $keycolumn = $self->keycolumn;
    }

    my $columns = $self->columns_for_sql( $keycolumn, $column );

    my $selection_cmd
      = "SELECT $columns FROM " . $self->name_quoted . " $where";

    my $list_r
      = $self->dbh->selectcol_arrayref( $selection_cmd,
        { Columns => [ 1, 2 ] }, @bind_values );

    my %value_of = @{$list_r};
    return \%value_of;

}

##############################################
### Method for constructing "where" clauses
##############################################

method where ($column!, :$like, :$eq) {
    croak "Must specify exactly one of 'like' or 'eq' to the 'where' method"
      if ( not defined $like and not defined $eq )
      or ( defined $like and defined $eq );

    my $quoted_column = $self->columns_for_sql($column);

    if ( defined $eq ) {
        my $where       = "WHERE $quoted_column = ?";
        my @bind_values = $eq;
        return where => $where, bind_values => \@bind_values;
    }

    my $where       = "WHERE $quoted_column LIKE ? ORDER BY $quoted_column";
    my @bind_values = $like;
    return where => $where, bind_values => \@bind_values;

}

##############################################
#### Method for looping over returned records
##############################################

method each_row (\:@columns = [] , :$where = $EMPTY, \:@bind_values = [] ) {
    my $table = $self->quoted_name;

    my $columns = $self->colummns_for_sql(@columns);

    my $query = "SELECT $columns FROM $table $where";

    my $sth = $self->dbh->prepare($query);
    $sth->execute(@bind_values);

    return sub {
        my $result = $sth->fetchrow_hashref;
        $sth->finish() if not $result;
        return $result;
    };
}

###############################################################
### Methods for checking & manipulating columns and their names
###############################################################

method columns_for_sql (@columns) {
    return '*' unless @columns;
    $self->_check_columns(@columns);
    return join( ' , ', $self->quote_identifiers(@columns) );
}

method _check_columns (@input_columns!) {
    my %is_a_column = map { $_, 1 } $self->columns;
    foreach my $input (@input_columns) {
        croak "Invalid column $input for table " . $self->name
          if not $is_a_column{$input};
    }
    return;
}

Actium::immut;

1;

__END__

=encoding utf8

head1 NAME

Actium::DB::Table - class representing a database table

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 package SomeDB 0.001;
 use Actium('class');
 with 'Actium::DB';

 use Actium::DB::Table;

 method a_new_table ($tablename, @columns) {
    my $table = Actium::DB::Table->new(name => $tablename, db => $self, 
        columns => \@columns);
    $self->_add_table($table);
 }

=head1 DESCRIPTION

Actium::DB::Table is a class that represents a simple table in a DBI
database.

Although it can be instantiated for tables with only common needs, for
many tables it will be useful to subclass it, to provide methods
specific to the content of that table.

=head1 ATTRIBUTES

=head2 db

This required attribute is a weak reference to the database to which
this table belongs.

=head2 name

This required attribute is the name of the table.

=head2 columns

This required attribute is the list of names of columns in the table.
It must be specified as a reference to an array. The method returns a
flat list of names.

=head2 keycolumn

This optional attribute is the column to be used as the keycolumn for
methods, below, that require a keycolumn.  (It doesn't have anything to
do with SQL indexes.)

=head1 DEPENDENCIES

The Actium system.

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

