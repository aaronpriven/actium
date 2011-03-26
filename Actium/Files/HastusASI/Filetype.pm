# Actium/Files/HastusASI/Filetype.pm

# Class for Hastus ASI filetypes

# Subversion: $Id$

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI::Filetype 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

foreach my $attribute (qw[tables]) {
    has "${attribute}_r" => {
        is      => 'ro',
        traits  => ['Array'],
        isa     => 'ArrayRef[Str]',
        default => sub { [] },
        required => 1,
        handles => { $attribute => 'elements', },
    };
}

# my ( %children_of );
# my ( %columns_of, %column_order_of );
# my ( %key_columns_of,   %key_column_order_of );

1;