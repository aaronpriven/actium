package Actium::Excel 0.013;

use Actium;

use Ref::Util;
use Excel::Writer::XLSX 0.95;               ## DEP ##
use Excel::Writer::XLSX::Worksheet 0.95;    ## DEP ##

use Sub::Exporter -setup => { exports => [qw(new_workbook)] };

# This exists mostly as a way of monkeypatching Excel::Writer::XLSX.
# It allows actium_write_col_string and actium_write_row_string to write
# columns and rows specifically as strings.

# I am not sure this is a particularly good way of going about this...

const my $SHEET_CLASS => 'Excel::Writer::XLSX::Worksheet';

const my $xlsx_window_height => 950;
const my $xlsx_window_width  => 1200;

sub new_workbook {

    my $fh_or_fname = shift;

    my $workbook = Excel::Writer::XLSX->new($fh_or_fname);
    if ( not defined $workbook ) {
        if ( u::is_ioref($fh_or_fname) ) {
            croak "Couldn't create workbook";
        }
        else {
            croak "Couldn't create workbook at $fh_or_fname";
        }
    }

    $workbook->set_size( $xlsx_window_width, $xlsx_window_height );
    return $workbook;

}

###############################################################################
### Monkey patching methods

package Excel::Writer::XLSX;

sub actium_text_format {
    my $workbook = shift;
    return $workbook->add_format( num_format => 0x31 );    # text only
}

package Excel::Writer::XLSX::Worksheet;

###############################################################################
#
# actium_write_row_string($row, $col, $array_ref, $format)
#
# Write a row of strings starting from ($row, $col).
# Call actium_write_col_string() if any of
# the elements of the array ref are in turn array refs. This allows the writing
# of 1D or 2D arrays of data in one go.
#
# Returns: the first encountered error value or zero for no errors
#

sub actium_write_row_string {

    my $self = shift;

    # Check for a cell reference in A1 notation and substitute row and column
    if ( $_[0] =~ /^\D/ ) {
        @_ = $self->_substitute_cellref(@_);
    }

    # Catch non array refs passed by user.

    my $row    = shift;
    my $col    = shift;
    my $tokens = shift;

    if ( Ref::Util::is_blessed_arrayref($tokens) and $tokens->can('unblessed') )
    {
        $tokens = $tokens->unblessed;
    }
    elsif ( not u::is_arrayref($tokens) ) {
        croak "Not an array ref in call to actium_write_row_string()";
    }

    my @options = @_;
    my $error   = 0;
    my $ret;

    for my $token (@$tokens) {

        # Check for nested arrays
        if ( u::is_arrayref($token) ) {
            $ret
              = $self->actium_write_col_string( $row, $col, $token, @options );
        }
        else {
            $token //= '';
            $ret = $self->write_string( $row, $col, $token, @options );
        }

        # Return only the first error encountered, if any.
        $error ||= $ret;
        $col++;
    }

    return $error;
} ## tidy end: sub actium_write_row_string

###############################################################################
#
# actium_write_col_string ($row, $col, $array_ref, $format)
#
# Write a column of strings starting from ($row, $col).
# Call actium_write_row_string() if any of
# the elements of the array ref are in turn array refs. This allows the writing
# of 1D or 2D arrays of data in one go.
#
# Returns: the first encountered error value or zero for no errors
#

sub actium_write_col_string {

    my $self = shift;

    # Check for a cell reference in A1 notation and substitute row and column
    if ( $_[0] =~ /^\D/ ) {
        @_ = $self->_substitute_cellref(@_);
    }

    my $row    = shift;
    my $col    = shift;
    my $tokens = shift;

    # Catch non array refs passed by user.
    if ( Ref::Util::is_blessed_arrayref($tokens) and $tokens->can('unblessed') )
    {
        $tokens = $tokens->unblessed;
    }
    elsif ( not is_arrayref($tokens) ) {
        croak "Not an array ref in call to actium_write_col_string()$!";
    }

    my @options = @_;
    my $error   = 0;
    my $ret;

    for my $token (@$tokens) {

        # Check for nested arrays
        if ( u::is_arrayref($token) ) {
            $ret
              = $self->actium_write_row_string( $row, $col, $token, @options );
        }
        else {
            $token //= '';
            $ret = $self->write_string( $row, $col, $token, @options );
        }

        # Return only the first error encountered, if any.
        $error ||= $ret;
        $row++;
    }

    return $error;
} ## tidy end: sub actium_write_col_string

1;

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
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

