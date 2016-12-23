package Actium::Excel 0.013;

use Actium::Preamble;

use Excel::Writer::XLSX 0.95;               ## DEP ##
use Excel::Writer::XLSX::Worksheet 0.95;    ## DEP ##

# This exists purely as a way of monkeypatching Excel::Writer::XLSX.
# It allows write_col_string and write_row_string to write
# columns and rows specifically as strings.

# I am not sure this is a particularly good way of going about this...

const my $SHEET_CLASS => 'Excel::Writer::XLSX::Worksheet';

#foreach my $method (qw/write_row_string write_col_string/) {
#    die "$SHEET_CLASS Worksheet already has a method '$method'"
#      if $SHEET_CLASS->can($method);
#}

package Excel::Writer::XLSX::Worksheet;

###############################################################################
#
# write_row_string($row, $col, $array_ref, $format)
#
# Write a row of strings starting from ($row, $col).
# Call write_col_string() if any of
# the elements of the array ref are in turn array refs. This allows the writing
# of 1D or 2D arrays of data in one go.
#
# Returns: the first encountered error value or zero for no errors
#

sub write_row_string {

    my $self = shift;

    # Check for a cell reference in A1 notation and substitute row and column
    if ( $_[0] =~ /^\D/ ) {
        @_ = $self->_substitute_cellref(@_);
    }

    # Catch non array refs passed by user.
    if ( ref $_[2] ne 'ARRAY' ) {
        croak "Not an array ref in call to write_row_string()$!";
    }

    my $row     = shift;
    my $col     = shift;
    my $tokens  = shift;
    my @options = @_;
    my $error   = 0;
    my $ret;

    for my $token (@$tokens) {

        # Check for nested arrays
        if ( ref $token eq "ARRAY" ) {
            $ret = $self->write_col_string( $row, $col, $token, @options );
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
} ## tidy end: sub write_row_string

###############################################################################
#
# write_col_string ($row, $col, $array_ref, $format)
#
# Write a column of strings starting from ($row, $col).
# Call write_row_string() if any of
# the elements of the array ref are in turn array refs. This allows the writing
# of 1D or 2D arrays of data in one go.
#
# Returns: the first encountered error value or zero for no errors
#

sub write_col_string {

    my $self = shift;

    # Check for a cell reference in A1 notation and substitute row and column
    if ( $_[0] =~ /^\D/ ) {
        @_ = $self->_substitute_cellref(@_);
    }

    # Catch non array refs passed by user.
    if ( ref $_[2] ne 'ARRAY' ) {
        croak "Not an array ref in call to write_col_string()$!";
    }

    my $row     = shift;
    my $col     = shift;
    my $tokens  = shift;
    my @options = @_;
    my $error   = 0;
    my $ret;

    for my $token (@$tokens) {

        # Check for nested arrays
        if ( ref $token eq "ARRAY" ) {
            $ret = $self->write_row_string( $row, $col, $token, @options );
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
} ## tidy end: sub write_col_string

1;
