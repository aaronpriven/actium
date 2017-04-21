package Actium::O::Sked::Timetable::IDTimetable 0.012;

# Object representing data in a timetable to be displayed to user,
# specific to InDesign timetables. Mostly to do with frame information.

use 5.016;
use warnings;

use Moose; ### DEP ###
use MooseX::StrictConstructor; ### DEP ###
use MooseX::SemiAffordanceAccessor; ### DEP ###
use Const::Fast; ### DEP ###

use List::Util(qw<max sum>); ### DEP ###

use MooseX::MarkAsMethods (autoclean => 1); ### DEP ###
#use overload '""'                   => sub {
#    my $self = shift;
#    $self->id . ":" . $self->lower_bound . '-' . $self->upper_bound;
#};

has timetable_obj => (
    isa      => 'Actium::O::Sked::Timetable',
    is       => 'ro',
    required => 1,
    handles =>
      [qw(lines dircode daycode width_in_halfcols id dimensions_for_display)]
    ,
);

has [qw(upper_bound lower_bound)] => (
    is      => 'rw',
    isa     => 'Int',
);

has [qw<overlong failed full_frame>] => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has [qw<firstpage finalpage>] => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

has [qw<compression_level page_order>] => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

const my $height_adjustment => 1;
# number of lines that the "continued" at the bottom takes up

sub height {
    my $self        = shift;
    my $upper_bound = $self->upper_bound;
    my $lower_bound = $self->lower_bound;
    return $self->timetable_obj->height 
       if not defined $upper_bound or not defined $lower_bound;
    my $height = $upper_bound - $lower_bound +1;
    $height += $height_adjustment if $upper_bound != ($self->timetable_obj->body_row_count -1);
    return $height;
}

sub _overlong_clones {
    my $self          = shift;
    my $final_frame_is_remainder = shift;
    my @rows_on_pages = @_;
    my @clonespecs;
    my $start      = 0;
    my $page_order = 0;

    foreach my $page_rows (@rows_on_pages) {

        push @clonespecs,
          { lower_bound => $start,
            upper_bound => $start + $page_rows - 1,
            firstpage   => 0,
            finalpage   => 0,
            full_frame => 1,
            page_order  => $page_order,
          };

        $start = $start + $page_rows;
        $page_order++;
    }

    $clonespecs[0]{firstpage}  = 1;
    $clonespecs[-1]{finalpage} = 1;
    
    if ($final_frame_is_remainder) {
       $clonespecs[-1]{full_frame} = 0;
    } else {
       $clonespecs[0]{full_frame} = 0;
    }

    # see Class::MOP::Class for clone_object
    my @clones = map { $self->meta->clone_object( $self, %{$_} ) } @clonespecs;
    return \@clones;

} ## tidy end: sub _overlong_clones

sub expand_overlong {
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

        push @table_sets, $self->_overlong_clones( 0, @rows_on_pages);
        push @table_sets, $self->_overlong_clones( 1, reverse @rows_on_pages );

    } ## tidy end: foreach my $page_height (@page_heights)

    return \@table_sets;

} ## tidy end: sub expand_overlong

sub as_indesign {
    my $self = shift;

    my %params = ref( $_[0] ) eq 'HASH' ? %{ $_[0] } : @_;
    
    foreach my $attribute (qw(lower_bound upper_bound firstpage finalpage)) {
        my $value = $self->$attribute;
        next unless defined $value;
        $params{$attribute} = $value;
    }
        
    return $self->timetable_obj->as_indesign( \%params );
}

#### CLASS METHOD

const my $EXTRA_TABLE_HEIGHT => 9;

sub get_stacked_measurements {

# add 9 for each additional table in a stack -- 1 for blank line,
# 4 for timepoints and 4 for the color bar. This is inexact and can mess up...
# not sure how to fix it at this point, I'd need to measure the headers

    my $class = shift;
    my @tables = @_;

    my @widths  = map { $_->width_in_halfcols } @tables;
    my @heights = map { $_->height } @tables;

    my $maxwidth = max(@widths);
    my $sumheight = sum(@heights) + ( $EXTRA_TABLE_HEIGHT * $#heights );

    return ( $sumheight, $maxwidth );
 
}

__PACKAGE__->meta->make_immutable;

1;

__END__ 

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
