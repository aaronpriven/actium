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
use Actium::O::Sked::Timetable::IDTimetable;

use Params::Validate ':all';

use Scalar::Util 'reftype';

use Const::Fast;

const my $IDTABLE => 'Actium::O::Sked::Timetable::IDTimetable';

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

    return sort { $a <=> $b } $self->_unsorted_compression_levels;

    # my %seen_levels;

    # $seen_levels{ $_->compression_level } = 1 foreach $self->framesets;
    # return [ sort { $a <=> $b } keys %seen_levels ];
}

has framesets_of_compression_level_r => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Actium::O::Sked::Timetable::IDFrameSet]]',
    lazy    => 1,
    builder => '_build_framesets_of_compression_level_r',
    handles => {
        _framesets_of_compression_level_r => 'get',
        _unsorted_compression_levels      => 'keys',
    },
);

sub _build_framesets_of_compression_level_r {
    my $self = shift;
    my %framesets_of;
    foreach my $frameset ( $self->framesets ) {
        my $level = $frameset->compression_level;
        push @{ $framesets_of{$level} }, $frameset;
    }
    return \%framesets_of;
}

sub framesets_of_compression_level {
    my $self  = shift;
    my $level = shift;
    return @{ $self->_framesets_of_compression_level_r($level) };
}

has heights_of_compression_level_r => (
    traits  => ['Hash'],
    is      => 'ro',
    isa     => 'HashRef[ArrayRef[Int]]',
    lazy    => 1,
    builder => '_build_heights_of_compression_level_r',
    handles => { _heights_of_compression_level_r => 'get', },
);

sub _build_heights_of_compression_level_r {
    my $self = shift;
    my %heights_of;
    
    foreach my $frameset ( $self->framesets ) {
        my $level  = $frameset->compression_level;
        my $height = $frameset->height;
        push @{ $heights_of{$level} }, $height;
    }

    foreach my $level ( keys %heights_of ) {
        $heights_of{$level} = [ sort { $b <=> $a } @{ $heights_of{$level} } ];
    }
    
    return \%heights_of;
}

sub heights_of_compression_level {
    my $self  = shift;
    my $level = shift;
    return @{ $self->_heights_of_compression_level_r($level) };
}

#has all_frames_r => (
#    traits  => ['Array'],
#    is      => 'bare',
#    isa     => 'ArrayRef[Actium::O::Sked::Timetable::IDFrame]',
#    lazy    => 1,
#    builder => '_build_all_frames_r',
#    handles => { all_frames => 'elements', },
#);
#
#sub _build_all_frames_r {
#    my $self = shift;
#    return map { $_->frames } $self->framesets;
#}

sub make_idtables {

    my $self   = shift;
    my @tables = @_;
    my @idtables;
    my $seen_a_failure;
    my $any_multipage;

  TABLE:
    foreach my $table (@tables) {

        my $table_width  = $table->width_in_halfcols;
        my $table_height = $table->height;
        my $partial_level;

        foreach my $frameset ( $self->framesets ) {
            my $compression_level = $frameset->compression_level;

            # does it fit entirely? if so, push it to the list, and next table
            my $frame_height = $frameset->height;

            foreach my $frame ( $frameset->frames ) {
                my $frame_width = $frame->width;

                if (    $table_height <= $frame_height
                    and $table_width <= $frame_width )
                {
                    push @idtables,
                      $IDTABLE->new(
                        table             => $table,
                        compression_level => $compression_level,
                        multipage         => 0,
                      );

                    next TABLE;
                }

                # if not, and we haven't defined a partial level already,
                # save the level

                $partial_level = $compression_level
                  if ( not defined $partial_level
                    and $table_width <= $frame_width );

            } ## tidy end: foreach my $frame ( $frameset...)

        } ## tidy end: foreach my $frameset ( $self...)

        if ( defined $partial_level ) {
            # if there's a partial level, save it to the list

            push @idtables,
              $IDTABLE->new(
                table             => $table,
                compression_level => $partial_level,
                multipage         => 1
              );
            $any_multipage = 1;
            next TABLE;
        }

        # otherwise, save it as failed

        push @idtables, $IDTABLE->new( table => $table, failed => 1 );
        $seen_a_failure = 1;

    } ## tidy end: TABLE: foreach my $table (@tables)

    return $seen_a_failure, $any_multipage, @idtables;

} ## tidy end: sub make_idtables

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
