package Actium::Moose 0.012;

use 5.016;

# Actium::Moose

# The preamble to Moose Actium perl modules
# Imports things that are common to (many) modules.
# inspired by
# http://blogs.perl.org/users/ovid/2013/09/building-your-own-moose.html

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

# here because, why bother putting it in util?

sub u::immut {
    my $package = caller;
    $package->meta->make_immutable;
}

1;

__END__

=item B<< immut() >>

A function that makes a Moose class immutable. It is recommended that Moose
classes be made immutable once they are defined because because 
they are much faster that way. Normally one does this by putting

 __PACKAGE__->meta->make_immutable

at the end of the class. This function allows replacement of that unwieldy 
code with something that's easier to type.
    


