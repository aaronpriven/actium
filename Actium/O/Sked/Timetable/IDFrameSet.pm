# Actium/O/Sked/Timetable/IDFrameSet.pm

# Moose object representing the frame set (series of one or more frames
# used on a page) for an InDesign timetable

# Subversion: $Id$

# legacy status: 4

package Actium::O::Sked::Timetable::IDFrameSet 0.002;

use Moose;
use MooseX::StrictConstructor;
use Scalar::Util('reftype');
use Carp;

has 'description' => (
    isa => 'Str',
    is  => 'ro',
);

has framesets => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Actium::O:Sked::Timetable::IDFrame]',
    required => 1,
    init_arg => 'framesets',
    handles  => { framesets => 'elements', },
);

has compression_level => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %args = reftype( $_[0] ) eq 'HASH ' ? %{ $_[0] } : @_;
    # hash or hashref

    unless ( exists $args{framesets} and reftype( $args{framesets} ) eq 'ARRAY' ) {
        return $class->$orig(@_);
    }

};

1;

__END__
