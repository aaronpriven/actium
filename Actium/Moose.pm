# Actium/Preamble.pm

# The preamble to Moose Actium perl modules 
# Imports things that are common to (many) modules.
# inspired by
# http://blogs.perl.org/users/ovid/2013/09/building-your-own-moose.html

# Subversion: $Id$

# legacy status: 4

use 5.016;

package Actium::Moose 0.003;

use Moose();
use MooseX::StrictConstructor();
use MooseX::SemiAffordanceAccessor();
use MooseX::MarkAsMethods();
use Actium::Preamble();
use Actium::Types;
use Import::Into;

use Moose::Exporter;
Moose::Exporter->setup_import_methods( also => ['Moose'] ); 

sub init_meta {
    my $class     = shift;
    my %params    = @_;
    my $for_class = $params{for_class};
    Moose->init_meta(@_);
    Actium::Preamble->import::into($for_class);
    MooseX::MarkAsMethods->import( {into => $for_class } , autoclean => 1);
    MooseX::StrictConstructor->import( { into => $for_class } );
    MooseX::SemiAffordanceAccessor->import( { into => $for_class } );
}
