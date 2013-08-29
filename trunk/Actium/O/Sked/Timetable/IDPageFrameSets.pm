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
use namespace::autoclean;
use Actium::O::Sked::Timetable::IDFrameSet;
use Params::Validate ':all';

use Scalar::Util 'reftype';

has frameset_r => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Actium::O::Sked::Timetable::IDFrameSet]',
    required => 1,
    init_arg => 'framesets',
    handles  => { framesets => 'elements', },
);

around BUILDARGS => sub {

    my $class = shift;
    my $orig  = shift;

    my @framesets = map { Actium::O::Sked::Timetable::IDFrameSet->new($_) } @_;

    return $class->$orig( framesets => \@framesets );

};

has compression_levels_r => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Int]',
    lazy    => 1,
    builder => '_build_compression_levels_r',
    handles => {
        compression_levels        => 'elements',
        highest_compression_level => [ get => -1 ],
    },

);

sub _build_compression_levels_r {
    my $self = shift;
    my %seen_levels;

    $seen_levels{ $_->compression_level } = 1 foreach $self->framesets;
    return sort { $a <=> $b } keys %seen_levels;
}

has all_frames_r => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Actium::O::Sked::Timetable::IDFrame]',
    lazy    => 1,
    builder => '_build_all_frames_r',
    handles => { all_frames => 'elements', },
);

sub _build_all_frames_r {
    my $self = shift;
    return map { $_->frames } $self->framesets;
}

sub no_frame_is_wide_enough {
    my $self  = shift;
    my $width = shift;

    foreach my $frame ( $self->all_frames ) {
        return 0 if $width <= $frame->width;
    }
    return 1;
}

sub level_that_fits_whole_table {
    my $self   = shift;
    my %params = validate(
        @_,
        {   height => 1,
            width  => 1,
        }
    );

    foreach my $frameset ( $self->framesets ) {
        my $compression_level = $frameset->compression_level;
        foreach my $frame ( $frameset->frames ) {
            return $compression_level
              if $params{height} <= $frame->height
              and $params{width} <= $frame->width;
        }

    }

    return;

} ## tidy end: sub level_that_fits_whole_table

sub level_that_fits_partial_table {
    my $self   = shift;
    my $width = shift;

    foreach my $frameset ( $self->framesets ) {

        next if $frameset->frame_count > 1;
        my $compression_level = $frameset->compression_level;

        return $compression_level
          if $width <= $frameset->frame(0)->width;

    }

    return;

} ## tidy end: sub level_that_fits_partial_table

__PACKAGE__->meta->make_immutable;

1;

__END__


my ( @heights, @compressed_heights );
my $widest            = 0;
my $widest_compressed = 0;

my %widest_frameset_of;
my %widest_compressed_frameset_of;

for my $frameset_r (@page_framesets) {

    my $height = $frameset_r->{height};
    my $width  = $frameset_r->{width};

    if ( not exists $widest_frameset_of{$height}
        or $width > $widest_frameset_of{$height}{width} )
    {
        $widest_frameset_of{$height} = $frameset_r;
    }

    $widest = max( $widest, $frameset_r->{width} );

}

for my $frameset_r (@compressed_framesets) {

    my $height = $frameset_r->{height};
    my $width  = $frameset_r->{width};

    if ( not exists $widest_compressed_frameset_of{$height}
        or $width > $widest_compressed_frameset_of{$height}{width} )
    {
        $widest_compressed_frameset_of{$height} = $frameset_r;
    }

    $widest_compressed = max( $widest, $frameset_r->{width} );

}

@heights            = keys %widest_frameset_of;
@compressed_heights = keys %widest_compressed_frameset_of;
