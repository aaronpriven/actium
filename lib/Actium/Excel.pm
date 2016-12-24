package Actium::Excel 0.013;

use Actium::Preamble;

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

    my $fh_or_fname;

    my $workbook = Excel::Writer::XLSX->new($fh_or_fname);
    if ( not defined $workbook ) {
        if ( u::is_io_ref($fh_or_fname) ) {
            croak "Couldn't create workbook";
        }
        else {
            croak "Couldn't create workbook at $fh_or_fname";
        }
    }

    $workbook->set_size( $xlsx_window_width, $xlsx_window_height );

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
    if ( ref $_[2] ne 'ARRAY' ) {
        croak "Not an array ref in call to actium_write_row_string()$!";
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
            $ret = $self->actium_write_col_string( $row, $col, $token, @options );
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

    # Catch non array refs passed by user.
    if ( ref $_[2] ne 'ARRAY' ) {
        croak "Not an array ref in call to actium_write_col_string()$!";
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
            $ret = $self->actium_write_row_string( $row, $col, $token, @options );
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
