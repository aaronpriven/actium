# Actium/Files/HastusASI/Table.pm

# Class for Hastus ASI tables

# Subversion: $Id$

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI::Table 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has [qw[id parent filetype keycolumn sql_insertcmd sql_createcmd ]] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has 'sql_insertcmd' => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_sql_insertcmd',
    lazy    => 1,
);

has 'sql_createcmd' => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_sql_createcmd',
    lazy    => 1,
);

has 'sql_idxcmd' => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_sql_idxcmd',
    lazy    => 1,
);

has [qw[has_repeating_final_column has_multiple_keycolumns]] => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

foreach my $attribute (qw[columns children]) {
    has "${attribute}_r" => (
        is       => 'ro',
        traits   => ['Array'],
        isa      => 'ArrayRef[Str]',
        required => 1,
        handles  => { $attribute => 'elements', },
    );
}

has '_create_columns_r' => (
    is      => 'ro',
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    lazy    => 1,
    builder => '_build_create_columns_r',
    handles => { _create_columns => 'elements' },
);

foreach my $attribute (qw[key_columns]) {
    has "${attribute}_r" => (
        is      => 'ro',
        traits  => ['Array'],
        isa     => 'ArrayRef[Str]',
        default => sub { [] },
        handles => { $attribute => 'elements', },
    );
}

has 'key_column_order_r' => (
    is      => 'ro',
    traits  => ['Array'],
    isa     => 'ArrayRef[Int]',
    default => sub { [] },
    handles => { key_column_order => 'elements', },
);

foreach my $attribute (qw(column_order column_length)) {
    has "${attribute}_r" => (
        is       => 'ro',
        traits   => ['Hash'],
        isa      => 'HashRef[Int]',
        required => 1,
        handles  => { "${attribute}_of" => 'get', },
    );
}

sub _build_sql_idxcmd {
    my $self = shift;
    my $key  = $self->keycolumn();
    return unless $key;

    my $id = $self->id();
    return "CREATE INDEX idx_${id}_key ON $id ($key)";
}

sub _build_sql_createcmd {
    my $self    = shift;
    my @columns = $self->_create_columns;
    my $id      = $self->id;
    return "CREATE TABLE $id (" . join( q{,}, @columns ) . q{)};

}

sub _build_sql_insertcmd {

    my $self    = shift;
    my @columns = $self->_create_columns;
    my $id      = $self->id;
    return "INSERT INTO $id VALUES (" . join( q{,}, ('?') x @columns ) . ')';
}

sub _build_create_columns_r {
    my $self    = shift;
    my @columns = $self->columns;
    my $parent  = $self->parent;
    if ($parent) {
        unshift @columns, "${parent}_id INTEGER";
    }
    my $key = $self->keycolumn;
    if ( $key and $self->has_multiple_keycolumns ) {
        push @columns, $key;
    }

    my $id = $self->id;
    unshift @columns, "${id}_id INTEGER PRIMARY KEY";

    return \@columns;

}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
