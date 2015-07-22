# Actium/O/Sked/Collection.pm

# A collection of Sked objects (or similar objects such as Timetable objects)

# legacy status 4

package Actium::O::Sked::Collection 0.010;

use Actium::Moose;

has 'sked_obj_of' => (
    is      => 'bare',
    isa     => 'Skedlike',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        _set_sked_obj => 'set',
        sked_obj     => 'get',
        #all_skeds => 'values',
        #ids => 'keys',
    },
);

sub add_sked {
   my $self = shift;
   my @objs = shift;
   $self->_set_sked_obj(map { $_->id, $_} @objs );
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

__END__
