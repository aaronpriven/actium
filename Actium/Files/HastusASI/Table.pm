# Actium/Files/HastusASI/Table.pm

# Class for Hastus ASI tables

# Subversion: $Id$

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI::Table 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has [qw[parent filetype keycolumn sql_insertcmd sql_createcmd sql_idxcmd ]] => {
    is       => 'ro',
    isa      => 'Str',
    required => 1
};

has [qw[has_repeating_final_column has_multiple_keycolumns]] => {
    is       => 'ro',
    isa      => 'Bool',
    default => 0,
};

has 'column_length' => {
    is  => 'ro',
    isa => 'Int',
};

foreach my $attribute (qw[columns key_columns children]) {
    has "${attribute}_r" => {
        is       => 'ro',
        traits   => ['Array'],
        isa      => 'ArrayRef[Str]',
        required => 1,
        handles  => { $attribute => 'elements', },
    };
}

has 'key_column_order_r' => {
    is       => 'ro',
    traits   => ['Array'],
    isa      => 'ArrayRef[Int]',
    required => 1,
    handles  => { key_column_order => 'elements', },
};

has 'column_order_r' => {
    is       => 'ro',
    traits   => ['Hash'],
    isa      => 'HashRef[Int]',
    required => 1,
    handles  => { column_order_of => 'get', },
};

# my ( %children_of );
# my ( %columns_of, %column_order_of );
# my ( %key_columns_of,   %key_column_order_of );

1;
