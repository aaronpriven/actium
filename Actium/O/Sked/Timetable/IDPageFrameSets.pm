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
use Actium::Combinatorics(':all');

use Params::Validate ':all';

use Scalar::Util 'reftype';
use List::MoreUtils ('uniq');
use List::Util(qw<max sum>);

use Const::Fast;

const my $IDTABLE => 'Actium::O::Sked::Timetable::IDTimetable';

const my $EXTRA_TABLE_HEIGHT => 9;
# add 9 for each additional table in a stack -- 1 for blank line,
# 4 for timepoints and 4 for the color bar. This is inexact and can mess up...
# not sure how to fix it at this point, I'd need to measure the headers

my $get_stacked_measurement_cr = sub {
    my @tables = @_;

    my @widths  = map { $_->width_in_halfcols } @tables;
    my @heights = map { $_->height } @tables;

    my $maxwidth = max(@widths);
    my $sumheight = sum(@heights) + ( $EXTRA_TABLE_HEIGHT * $#heights );

    return ( $sumheight, $maxwidth );

};

has frameset_r => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Actium::O::Sked::Timetable::IDFrameSet]',
    required => 1,
    init_arg => 'framesets',
    handles  => { framesets => 'elements', },
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;

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
        my @heights = uniq( sort { $b <=> $a } @{ $heights_of{$level} });
        $heights_of{$level} = \@heights;
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
                        timetable_obj             => $table,
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
                timetable_obj     => $table,
                compression_level => $partial_level,
                multipage         => 1
              );
            $any_multipage = 1;
            next TABLE;
        }

        # otherwise, save it as failed

        push @idtables, $IDTABLE->new( timetable_obj => $table, failed => 1 );
        $seen_a_failure = 1;

    } ## tidy end: TABLE: foreach my $table (@tables)

    return $seen_a_failure, $any_multipage, @idtables;

} ## tidy end: sub make_idtables

sub assign_page {

    my $self   = shift;
    my @tables = @{+shift};

    foreach my $frameset ( $self->framesets ) {
     
        my $frame_height = $frameset->height;

        my @frames = $frameset->frames;

        next if ( @frames > @tables );
        # If there are more frames than there are tables,
        # this cannot be the best fit

        # will this set of tables fit on this page?

        if ( @frames == 1 ) {
            my ( $height, $width ) = $get_stacked_measurement_cr->(@tables);
            if (not(    $height <= $frame_height 
                    and $width <= $frames[0]->width )
              )

            {
                next;

            }
            return { tables => [ \@tables ], frameset => $frameset };
        }

        if ( @frames == @tables ) {
            for my $i ( 0 .. $#frames ) {
                return
                  if $frame_height  < $tables[$i]->height
                  or $frames[$i]->width < $tables[$i]->width_in_halfcols;
                # doesn't fit if frame's height or width aren't big enough
            }
            return { tables => [ map { [$_] } @tables ], frameset => $frameset  };
            # all frames fit
        }

        # more tables than frames. Divide tables up into appropriate sets,
        # and then try them

        my @table_permutations
          = ordered_partitions( \@tables , scalar @frames);

      TABLE_PERMUTATION:
        foreach my $table_permutation (@table_permutations) {

            foreach my $i ( 0 .. $#frames ) {
                my @tables = @{ $table_permutation->[$i] };
                my ( $height, $width ) = $get_stacked_measurement_cr->(@tables);
                next TABLE_PERMUTATION
                  if $frame_height < $height
                  or $frames[$i]->width < $width;
                # doesn't fit if frame's height or width aren't big enough
            }

            # it got here, so the tables fit within the frames

            return { tables => $table_permutation, frameset => $frameset };

        }

        # finished all the permutations for this page, but nothing fit

    } ## tidy end: foreach my $frameset ( $self...)
    
    return;
    # finished all the permutations for this page set, but nothing fit

} ## tidy end: sub assign_page


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
