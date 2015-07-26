# Actium::Moose

# The preamble to Moose Actium perl modules
# Imports things that are common to (many) modules.
# inspired by
# http://blogs.perl.org/users/ovid/2013/09/building-your-own-moose.html

# legacy status: 4

use 5.016;

package Actium::Moose 0.010;

use Moose();                             ### DEP ###
use MooseX::StrictConstructor();         ### DEP ###
use MooseX::SemiAffordanceAccessor();    ### DEP ###
use MooseX::MarkAsMethods();             ### DEP ###
use Moose::Util::TypeConstraints();      ### DEP ###
use Actium::Preamble();
#use Actium::Types;
# not included because not useful without importing specific types
use Import::Into;    ### DEP ###

use Moose::Exporter; ### DEP ###
Moose::Exporter->setup_import_methods( also => ['Moose'] );

sub init_meta {
    my $class     = shift;
    my %params    = @_;
    my $for_class = $params{for_class};
    Moose->init_meta(@_);
    #    Actium::Types->import::into($for_class);
    MooseX::MarkAsMethods->import( { into => $for_class }, autoclean => 1 );
    MooseX::StrictConstructor->import( { into => $for_class } );
    MooseX::SemiAffordanceAccessor->import( { into => $for_class } );
    Moose::Util::TypeConstraints->import( { into => $for_class } );
    Actium::Preamble->import::into($for_class);
    # must be at the end so "no warnings" in preamble overrides warnings 
    # turned on by Moose, etc.
}

1;

__END__

