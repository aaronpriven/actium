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
    handles  => [qw(lines dircode daycode width id dimensions_for_display)],
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

has [qw<firstpage finalpage>] => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

has [qw<lower_bound upper_bound>] => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

sub height {

    my $self        = shift;
    my $upper_bound = $self->upper_bound;
    return $self->timetable_obj->height unless defined $upper_bound;

    return $upper_bound - $self->lower_bound;

}

my $height_adjustment = 1;
# number of lines that the "continued" at the bottom takes up

sub _multipage_clones {
    my $self          = shift;
    my @rows_on_pages = @_;
    my @clonespecs;
    my $start = 0;

    foreach my $page_rows (@rows_on_pages) {

        push @clonespecs,
          { lower_bound => $start,
            upper_bound => $start + $page_rows - 1,
            firstpage   => 0,
            finalpage   => 0,
          };

        $start = $start + $page_rows;
    }

    $clonespecs[0]{firstpage}  = 1;
    $clonespecs[-1]{finalpage} = 1;

    # see Class::MOP::Class for clone_object
    my @clones = map { $self->meta->clone_object( $self, %{$_} ) } @clonespecs;
    return \@clones;

} ## tidy end: sub _multipage_clones

sub expand_multipage {
    my $self         = shift;
    my @page_heights = @_;

    my @table_sets;
    my $table_height  = $self->height;
    my $table_lastrow = $table_height - 1;

    foreach my $page_height (@page_heights) {

        my @rows_on_pages;

        my $rest            = $table_height;
        my $adjusted_height = $page_height - $height_adjustment;

        while ( $rest > $page_height ) {
            push @rows_on_pages, $adjusted_height;
            $rest = $rest - $adjusted_height;
        }
        push @rows_on_pages, $rest;

        # so @rows_on_pages contains $adjusted_height for each page,
        # plus the remainder on the last page

        push @table_sets, $self->_multipage_clones(@rows_on_pages);
        push @table_sets, $self->_multipage_clones( reverse @rows_on_pages );

    } ## tidy end: foreach my $page_height (@page_heights)

    return @table_sets;

} ## tidy end: sub expand_multipage

sub as_indesign {
    my $self = shift;

    my %params = ref( $_[0] ) eq 'HASH' ? %{ $_[0] } : @_;

    $params{lower_bound} = $self->lower_bound;
    $params{upper_bound} = $self->upper_bound;
    $params{firstpage}   = $self->firstpage;
    $params{finalpage}   = $self->finalpage;

    return $self->timetable_obj->as_indesign( \%params );
}

__PACKAGE__->meta->make_immutable;

1;

__END__ 
