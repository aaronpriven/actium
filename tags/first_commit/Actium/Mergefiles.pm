# Actium/Mergefiles.pm
# Reads files in "merge" format exported by FileMaker Pro.

# Subversion: $Id$

use strict;
use warnings;

package Actium::Mergefiles;

use 5.010;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

use Actium::Constants;
use Actium::Term;
use Actium::Files;
use Text::CSV;
use Carp;

use Readonly;

Readonly my $TELL_INCREMENT => 100_000;

sub mergeread {    # constructor
    my $class = shift;
    my $file  = shift;
    my $self  = {};

    emit "Loading ", Actium::Files::filename($file);

    local $/ = "\r";

    my $size = -s $file;

    open my $handle, '<', $file
      or croak( __PACKAGE__ . " can't open file $file: $!" );
    my $csv = Text::CSV->new( { binary => 1 } );

    my $line = <$handle>;
    chomp $line;
    $csv->parse($line);
    my $column_names_r = [ $csv->fields() ];

    my $column_order_r = {};
    @{$column_order_r}{ @{$column_names_r} } = ( 0 .. $#{$column_names_r} );

    $self->{COLUMN_ORDER} = $column_order_r;

    my $oldtell = $TELL_INCREMENT;
    my @array;

    emit_over('0%');

    # It turns out the version using $csv->getline is really, really
    # slow, I think because it's scanning the entire file ahead
    # for line endings. Since merge files don't have embedded newlines,
    # there's really no point.

    while (<$handle>) {

        my $tell = tell($handle);
        if ( $tell > $oldtell ) {
            $oldtell += $TELL_INCREMENT until $oldtell > $tell;
            emit_over( sprintf( '%2i%%', $tell / $size * 100 ) );
        }

        chomp;
        $csv->parse($_);
        my @columns = $csv->fields();

        foreach (@columns) {
            s/$VERTICALTAB/\n/sx;
        }
        push @array, \@columns;

        # FileMaker stores embedded newlines as vertical tab characters
    }

    emit_over( '100% ... ', scalar @array, " records" );
    emit_done;

    close $handle
      or croak( __PACKAGE__ . " can't close file $file: $!" );

    $self->{COLUMNNAMES} = $column_names_r;

    $self->{ARRAY} = \@array;

    #    $self->{ITERATORVALUE} = 0;
    $self->{HASH} = {};

    bless( $self, $class );
    return $self;

} ## tidy end: sub mergeread

sub column_names {
    my $self = shift;
    return wantarray ? @{ $self->{COLUMNNAMES} } : $self->{COLUMNNAMES};
}

#sub column_order_of {
#    my $self = shift;
#    my $column = shift;
#    return $self->{COLUMN_ORDER}{$column};
#}

sub column_order_of {
    my $self    = shift;
    my @columns = @_;
    return wantarray
      ? map { $self->{COLUMN_ORDER}{$_} } @columns
      : $self->{COLUMN_ORDER}{ $columns[0] };
}

sub hashrow {
    my $self  = shift;
    my $row_r = shift;

    my %hash;

    @hash{ $self->column_names() } = @{$row_r};

    return \%hash;

}

sub _makehash {
    my $self        = shift;
    my $indexcolumn = shift;

    my $multiple_index = 0;
    my %hash;

    my $idx_col_idx = $self->column_order_of($indexcolumn);

    foreach my $record_ar ( @{ $self->{ARRAY} } ) {

        my $indexvalue = $record_ar->[$idx_col_idx];

        if ( $multiple_index or exists $hash{$indexvalue} ) {

            # if we've seen this one before or we know indexes aren't unique,

            if ( not $multiple_index ) {

                # then this is the first we've learned about non-unique indexes.

                $hash{$_} = [ $hash{$_} ] foreach ( keys %hash );

                # go through the whole hash and set the value of each
                # indexcolumn to be a reference to an anonymous array that
                # contains one entry, the old value

               # This changes the structure from $hash{$indexcolumn}{$column}...
               # to $hash{$indexcolumn}[0..n]{$column}...

                $multiple_index = 1;

                # never do this again

            }

            push @{ $hash{$indexvalue} }, $record_ar;

        } ## tidy end: if ( $multiple_index or...)
        else {

            # unique indexes
            $hash{$indexvalue} = $record_ar;
        }

        $self->{HASH_MULTIPLEINDEX}{$indexcolumn} = 1 if $multiple_index;
        $self->{HASH}{$indexcolumn} = \%hash;
    } ## tidy end: foreach my $record_ar ( @{ ...})

    return;

} ## tidy end: sub _makehash

sub hash {
    my $self        = shift;
    my $indexcolumn = shift;
    if ( not exists( $self->{HASH}{$indexcolumn} ) ) {
        $self->_makehash($indexcolumn);
    }

    return $self->{HASH}{$indexcolumn};
}

sub rows_where {

    my $self        = shift;
    my $indexcolumn = shift;
    #my $idx_col_idx = $self->column_order_of($indexcolumn);
    my $indexvalue = shift;

    if ( not exists( $self->{HASH}{$indexcolumn} ) ) {
        $self->_makehash($indexcolumn);
    }

    my $value = $self->{HASH}{$indexcolumn}{$indexvalue};

    if ( exists $self->{HASH_MULTIPLEINDEX}{$indexcolumn} ) {
        return @{$value};    # more than one row with this value
    }

    # just one row with this value
    return $value;

} ## tidy end: sub rows_where

sub array {
    my $self = shift;
    return $self->{ARRAY};
}

1;
__END__


=head1 NAME

Actium::Mergefiles - data from "Merge" (CSV) files 
saved by FileMaker Pro

=head1 VERSION

This documentation refers to Actium::Mergefiles version 0.001

=head1 SYNOPSIS

 use Actium::Mergefiles;

 $mergeobj = Actium::Mergefiles->new("filename.csv");
 @rows = $mergeobj->array();

 %hash = $mergeobj->hash('Fieldname');

 @somerows = $mergeobj->rows_where('Fieldname' , 'value');
  
=head1 DESCRIPTION

This module reads "merge" files (CSV files in a specific format) saved by
FileMaker Pro, and allows rows to be accessed through an object.

=head1 METHODS

=over

=item B<$obj = Actium::Mergefiles-E<gt>mergeread( F<filename> )>

Constructs an object containing the data in F<filename>, reading the data
from disk.

=item B<$obj-E<gt>array()>

Returns a reference to an array. Each element is an arrayref with the column
values, in the order returned by I<column_names()>.

=item B<$obj-E<gt>column_names()>

Returns the column names of the merge file. Returns a list in list context, or 
an array reference in scalar context.

=item B<$obj-E<gt>hashrow($row_r)>

Takes a reference to an array of columns. Returns a hash reference, where the 
keys are the column names and the values are the column values.

=item B<$obj-E<gt>hash( I<keycolumn> )>

You can use B<hash()> to easily get rows of a particular column. Returns a
reference to a hash whose keys are the possible values of I<keycolumn>.

The values of that hash are usually array refs
whose values are the column values: the same rows as returned by B<array()>.

However, if I<keycolumn> is not unique -- if there is more than one row where
I<keycolumn> has the same value -- then the values of the hash are arrayrefs, 
and the elements of those arrays are the rows, the same rows as returned
by B<array()>.

=item B<$obj-E<gt>rows_where( I<keycolumn>, I<value> )>

Returns a list of rows where the key column has the particular value given.
Each row is an arrayref where the the values are the column values.

=back

=head1 DIAGNOSTICS

=over

=item Actium::Mergefiles can't open file F<filename>

=item Actium::Mergefiles can't close file F<filename>

An input/output error occurred while opening or closing F<filename>.

=item Actium::Mergefiles can't read column names in F<filename>

=item Actium::Mergefiles can't read line I<n> in F<filename>

An error was received reading column names, or a line. In other words, 
Text::CSV returned an undefined value. This is followed by a 
Text::CSV error diagnostic. See L<Text::CSV/DIAGNOSTICS>.

=back

=head1 DEPENDENCIES

=over

=item *

Perl 5.010 and the standard distribution.

=item *

Text::CSV (which in turn requires Text::CSV_XS or Text::CSV_PP)

=item *

Actium::Constants

=back

=head1 BUGS AND LIMITATIONS

The references returned by array(), hash(), and column_names() are references
to the data in memory. There is no attempt to make sure that this data cannot
be changed, even though changes in the data won't be reflected on disk.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.

=cut
