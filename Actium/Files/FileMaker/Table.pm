# Actium/Files/FileMaker/Table.pm

# Class for FileMaker Pro tables

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

has 'id' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

#####################
### COLUMN ATTRIBUTES
#####################

has 'columns_r' => (
    is      => 'bare',
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        columns       => 'elements',
        column_number => 'get',
        add_column    => 'push',
    },
);

has 'column_repetitions_of_r' => (
    is      => 'bare',
    traits  => ['Hash'],
    isa     => 'HashRef[Int]',
    default => sub { {} },
    handles => {
        column_repetitions_of     => 'get',
        set_column_repetitions_of => 'set',
    },
);

has 'column_type_r' => (
    is      => 'bare',
    traits  => ['Hash'],
    isa     => 'HashRef[Str]',
    default => sub { {} },
    handles => {
        column_type_of     => 'get',
        set_column_type_of => 'set',
    },
);

has 'column_idx_of_r' => (
    is      => 'bare',
    traits  => ['Hash'],
    isa     => 'HashRef[Int]',
    default => sub { {} },
    handles => {
        column_idx_of     => 'get',
        set_column_idx_of => 'set',
    },
);

#########################
### KEY COLUMN ATTRIBUTES
#########################

sub set_key {
    my $self = shift;
    _set_key_components_r( split( m{/}, shift ) );
}

has 'key_components_r' => (
    writer  => '_set_key_components_r',
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        key_components       => 'elements',
        _key_components_count => 'count',
        _key_component_number => 'get',
    },
);

has 'has_composite_key' => (
    is       => 'ro',
    isa      => 'Bool',
    builder  => '_build_has_composite_key',
    lazy     => 1,
    init_arg => undef,
);

sub _build_has_composite_key {
    my $self = shift;
    return $self->_key_components_count > 1 ;
}

has 'key' => (
    is       => 'ro',
    init_arg => undef,
    builder  => '_build_key',
    lazy     => 1,
);

sub _build_key {
    my $self           = shift;
    return $self->id . '_key' if $self->has_composite_key;
    return $self->_key_component_number(0);
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
        is       => 'ro',
        init_arg => undef,
        isa      => 'Str',
        builder  => "_build_$attribute",
        lazy     => 1,
    );
}

has 'sql_idxcmd' => (
    is       => 'ro',
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
    my $key  = $self->key;
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
    my $key = $self->key;
    if ( $key and $self->has_composite_key ) {
        push @columns, $key;
    }

    my $id = $self->id;
    unshift @columns, "${id}_id INTEGER PRIMARY KEY";

    return \@columns;

}

1;

__END__

