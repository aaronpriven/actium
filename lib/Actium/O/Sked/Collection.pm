# Actium/O/Sked/Collection.pm

# A collection of Sked objects (or similar objects such as Timetable objects)

# legacy status 4

package Actium::O::Sked::Collection 0.010;
use Actium::Moose;
use Actium::O::Sked;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    
    my %init_arg;
    
    if (u::is_plain_hashref($_[-1]) ) {
        my $init_arg_r = pop @_;
        %init_arg = %$init_arg_r;
    }
        
    my %sked_obj_of = map { $_->id, $_ } @_ ;
    
    $init_arg{sked_obj_of} = \%sked_obj_of;
    
};

has 'sked_obj_of' => (
    is      => 'bare',
    isa     => 'Skedlike',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        _set_sked_obj => 'set',
        sked_obj      => 'get',
        #all_skeds => 'values',
        #ids => 'keys',
    },
);

#sub add_sked {
#    my $self = shift;
#    my @objs = shift;
#    $self->_set_sked_obj( map { $_->id, $_ } @objs );
#}

sub load_json {
    my $class = shift;

    my $json_folder = shift;

    my @files = $json_folder->glob_plain_files;

    $class->new(map { Actium::O::Sked::->load($_) } @files);

}

u::immut;

__END__
