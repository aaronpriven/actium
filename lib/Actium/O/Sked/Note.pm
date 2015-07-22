# Actium/Sked/Note.pm

# legacy status 3

package Actium::O::Sked::Note 0.010;

use 5.010;

use utf8;

use Moose; ### DEP ###
use MooseX::SemiAffordanceAccessor; ### DEP ###
use MooseX::StrictConstructor; ### DEP ###

use namespace::autoclean; ### DEP ###

has [ qw<origlinegroup noteletter note days> ] => (
   is => 'rw' ,
   isa => 'Str' ,
);

sub noteid {
    my $self = shift;
    return join ('_' , $self->origlinegroup , $self->days, $self->noteletter );
}

sub id {
	my $self = shift;
	return $self->noteid;
}

sub dump {
    my $self = shift;
    require Data::Dumper;
    return Data::Dumper::Dumper ($self);
}
    
__PACKAGE__->meta->make_immutable; ## no critic (RequireExplicitInclusion)

1;
