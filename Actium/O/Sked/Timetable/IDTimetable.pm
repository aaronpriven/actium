# Actium/O/Sked/Timetable/IDTimetable.pm

# Object representing data in a timetable to be displayed to user,
# specific to InDesign timetables. Mostly to do with frame information.

# Subversion: $Id$

# legacy status: 4

package Actium::O::Sked::Timetable::IDTimetable 0.002;

use 5.016;
use warnings;

use Moose;
use MooseX::StrictConstructor;

use namespace::autoclean;

has timetable_obj => (
    isa      => 'Actium::O::Sked::Timetable',
    is       => 'ro',
    required => 1,
    handles =>
      [qw(lines dircode daycode height width id dimensions_for_display)],
);

has compression_level => (
    default => 0,
    is      => 'ro',
    isa     => 'Int',
);

has [qw<multipage failed>] => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has [qw<lower_bound upper_bound page_order>] => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

sub expand_multipage {
    my $self         = shift;
    my @page_heights = @_;

    my @table_sets;
    my $table_height  = $self->height;
    my $table_lastrow = $table_height - 1;

    foreach my $page_height (@page_heights) {

        my @newtables;

        my $start = 0;
        my $count = 0;
        while ( $start < $table_height ) {
            my $end = $start + $page_height - 1;
            $end = $table_lastrow if $end > $table_lastrow;
            push @{ $newtables[0] },
              $self->_clone_with_rows( $start, $end, $count );
            $count++;
            $start = $start + $page_height;
        }

        if ( $table_height % $page_height ) {
            # if the table height isn't an exact multiple of the page height,

            $count = 0;

            my $end = $table_lastrow;
            while ( $end > 0 ) {
                my $start = $end - $page_height + 1;
                $start = $0 if $start < 0;
                push @{ $newtables[1] },
                  $self->_clone_with_rows( $start, $end, $count );
                $end = $end - $page_height;
                $count++;
            }

        }

        push @table_sets, @newtables;

    } ## tidy end: foreach my $page_height (@page_heights)

    return @table_sets;

} ## tidy end: sub expand_multipage

sub _clone_with_rows {
    my $self       = shift;
    my $start      = shift;
    my $end        = shift;
    my $page_order = shift;

    my %params = ( lower_bound => $start, upper_bound => $end,
        page_order => $page_order );

    return $self->meta->clone_object( $self, %params );
    # see Class::MOP::Class

}

sub as_indesign {
    my $self = shift;

    my %params = ref( $_[0] ) eq 'HASH' ? %{ $_[0] } : @_;

    $params{lower_bound} = $self->lower_bound;
    $params{upper_bound} = $self->upper_bound;

    return $self->timetable_obj->as_indesign( \%params );

}

__PACKAGE__->meta->make_immutable;

1;

__END__ 
