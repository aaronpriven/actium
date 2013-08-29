# Actium/O/Sked/Timetable/IDPageFrameSets.pm

# Moose object representing all the frame sets (series of one or more frames
# used on a page) for an InDesign timetable

# Subversion: $Id$

# legacy status: 4

package Actium::O::Sked::Timetable::IDPageFrameSets 0.002;

use warnings;
use 5.016;

use Moose;
use MooseX::StrictConstructor;
use Carp;
use Scalar::Util('reftype');

use namespace::autoclean;


sub BUILDARGS {
    my $class = shift;

    my @framesets = @_;

    foreach my $frameset ( 0 .. $#framesets ) {

        croak 'Frame set passed to '
          . __PACKAGE__
          . '->new must be reference to array of frames'
          unless reftype($frameset) eq 'ARRAY';

        foreach my $i ( 0 .. $#{$frameset} ) {
            next if blessed( $frameset->[$i] );
            
            croak 'Frame passed to '
              . __PACKAGE__
              . '->new must be reference to hash of attribute specifications'
              unless reftype( $frameset->[$i] ) eq 'HASH';

            $frameset->[$i]
              = Actium::O::Sked::Timetable::IDFrame->new( $framesets[$i] );

        }

    } ## tidy end: foreach my $frameset ( 0 .....)

} ## tidy end: sub BUILDARGS

1;

__END__



=item B<description>

An optional text description of this frame (usually something like 
"Portrait halves" for two frames representing two halves of a portrait page).
