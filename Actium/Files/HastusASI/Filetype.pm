# Actium/Files/HastusASI/Filetype.pm

# Class for Hastus ASI filetypes

# Subversion: $Id$

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI::Filetype 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has 'tables_r' => (
    is       => 'ro',
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    required => 1,
    handles  => { tables => 'elements', },
);

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
