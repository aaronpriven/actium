# Actium/SkedNote.pm

# Subversion: $Id$

# legacy status 3

package Actium::SkedNote;

use 5.010;

use utf8;

use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose;

our $VERSION = '0.001';
$VERSION = eval $VERSION;


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
    
# sub dump {
#   my $self = shift;
#
#    my $dumpdata;
#    
#    open (my $dump , '>' , \$dumpdata);
#    
#    say $dump "origlinegroup\t" , $self->origlinegroup();
#    say $dump "noteletter\t" , $self->noteletter();
#    say $dump "days\t" , $self->days();
#    say $dump "note\t" , $self->note();
#    
#    close $dump;
#    
#    return $dumpdata;
    
#}


no Moose;
__PACKAGE__->meta->make_immutable; ## no critic (RequireExplicitInclusion)

1;