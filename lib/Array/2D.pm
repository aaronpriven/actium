## no critic (ProhibitExcessMainComplexity)
# it thinks all the code in $x = sub {...} is in the main module
package Array::2D;
use 5.008001;
use strict;
use warnings;

our $VERSION = '0.001_005';
$VERSION = eval $VERSION;   ## no critic (BuiltinFunctions::ProhibitStringyEval)

## no critic (RequirePodAtEnd)

=encoding utf8

=head1 NAME

Array::2D - Methods for simple array-of-arrays data structures

=head1 VERSION

This documentation refers to version 0.001_005

=head2 NOTICE

This is alpha software.  Method names and behaviors are subject to change.
The test suite has significant omissions.

=head1 SYNOPSIS

 use Array::2D;
 my $array2d = Array::2D->new( [ qw/a b c/ ] , [ qw/w x y/ ] );

 # $array2d contains

 #     a  b  c
 #     w  x  y

 $array2d->push_col (qw/d z/);

 #     a  b  c  d
 #     w  x  y  z

 say $array2d->[0][1];
 # prints "b"

=head1 DESCRIPTION

Array::2D is a module that adds useful methods to Perl's
standard array of arrays ("AoA") data structure, as described in 
L<Perl's perldsc documentation|perldsc> and 
L<Perl's perllol documentation|perllol>.  That is, an array that
contains other arrays:

 [ 
   [ 1, 2, 3 ] , 
   [ 4, 5, 6 ] ,
 ]

This module provides methods for using that standard construction.

Most of the time, it's good practice to avoid having programs that
use a module know about the internal construction of an object.
However, this module is not like that.  It assumes that the data
structure I<is> accessible outside the module's code, and may be
altered by other code.  The module will never change the data
structure to include anything else. Therefore, it is perfectly
reasonable to use the normal reference syntax to access items inside
the array. A construction like C<< $array2d->[0][1] >>  for accessing
a single element, or C<< @{$array2d} >> to get the list of rows,
is perfectly appropriate. This module exists because the reference-based
implementation of multidimensional arrays in Perl makes it difficult
to access, for example, a single column, or a two-dimensional slice,
without writing lots of extra code.

Array::2D uses "row" for the first dimension, and "column" or
"col"  for the second dimension. This does mean that the order
of (row, column) is the opposite of the usual (x,y) algebraic order.

Because this object is just an array of arrays, most of the methods
referring to rows are here mainly for completeness, and aren't 
much more useful than the native Perl construction (e.g., C<<
$array2d->last_row() >> is just a slower way of doing C<< $#{$array2d}
>>.) They will also typically be much slower. 

On the other hand, most of the methods referring to columns are useful,
since there's no simple way of fetching a column or columns in Perl.  

=head2 PADDING

Because it is intended that the structure can be altered by standard
Perl constructions, there is no guarantee that the object is either
completely padded out so that every value within the structure's
height and width has a value (undefined or not), alternatively
completely pruned so that there are as few undefined values as
possible.  The only padding that must exist is padding to ensure that
the row and column indexes are correct for all defined values.

Other Perl code could change the padding state at any time, or leave
it in an intermediate state (where some padding exists, but the
padding is not complete).

For example, the following would be valid:

 $array2d = [
  [ undef, 1, 2 ],
       3  ],
  [    4,  6, ],
 ];

The columns would be returned as (undef, 3, 4), (1, undef, 6), and (2). 

There are methods to set padding -- the C<prune()> method
will eliminate padding, and the C<pad> method will pad out
the array to the highest row and column with a defined value.

Methods that retrieve data will prune the data before returning it.

Methods that delete rows or columns (del_*, shift_*, pop_*, and in void
context, slice) will prune not only the returned data but also the 
array itself.

=cut

# core modules
use Carp;
use List::Util(qw/max min/);
use POSIX (qw/floor ceil/);
use Scalar::Util(qw/blessed reftype/);

# non-core modules
use List::MoreUtils 0.28 (qw/natatime any all none/);
use Params::Validate(qw/validate ARRAYREF HASHREF/);

### Test for Ref::Util and if present, use it
BEGIN {
    my $impl = $ENV{PERL_ARRAY_2D_NO_REF_UTIL}
      || our $NO_REF_UTIL;

    if ( !$impl && eval { require Ref::Util; 1 } ) {
        Ref::Util->import(qw/is_arrayref is_plain_arrayref/);
        # There is a possibility that Ref::Util will change the meaning
        # of is_arrayref to "is_plain_arrayref" and create a new
        # is_any_arrayref that means what is_arrayref means now.
        # Changes will have to be made in that event.
    }
    else {
        *is_plain_arrayref = sub { ref( $_[0] ) eq 'ARRAY' };
        *is_arrayref       = sub { reftype( $_[0] ) eq 'ARRAY' };
    }
}

### Test for Unicode::GCString and if present, use it

### First, the variable $text_columns_cr is declared.
### Then, it is set to a reference to code that
###    a) determines what the future text_columns code should be,
###    b) sets the variable $text_column_cr to point to that new code, and
###    c) then jumps to that new code.

### Thus the first time it's run, it basically redefines itself
### to be the proper routine (either one with or without Unicode::GCString).

my $text_columns_cr;
$text_columns_cr = sub {

    my $impl = $ENV{PERL_ARRAY_2D_NO_GCSTRING}
      || our $NO_GCSTRING;

    if ( !$impl && eval { require Unicode::GCString; 1 } ) {
        $text_columns_cr = sub {

            return 0 unless defined $_[0];
            my $cols = Unicode::GCString->new("$_[0]")->columns;
            return $cols;

            # explicit stringification is necessary
            # since Unicode::GCString doesn't automatically
            # stringify numbers
        };
    }
    else {
        $text_columns_cr = sub {
            return 0 unless defined $_[0];
            return length( $_[0] );
        };
    }
    goto $text_columns_cr;

};

=head1 METHODS

Some general notes:

=over 

=item *

Except for constructor methods, all methods can be called as an object 
method on a blessed Array::2D object:

  $array_obj->clone();

Or as a class method, if one supplies the array of arrays as the first
argument:

  Array::2D->clone($array);

In the latter case, the array of arrays need not be blessed (and will not 
be blessed by Array::2D).

=item *

In all cases where an array of arrays is specified as an argument 
(I<aoa_ref>), this can be either an Array::2D object or a regular  
array of arrays data structure that is not an object. 

=item *

Where rows are columns are removed from the array (as with any of the 
C<pop_*>, C<shift_*>, C<del_*> methods), time-consuming assemblage of
return values is ommitted in void context.

=item *

Some care is taken to ensure that rows are not autovivified.  Normally, if the 
highest row in an arrayref-of-arrayrefs is 2, and a program
attempts to read the value of $aoa->[3]->[$anything], Perl will create 
an empty third row.  This module avoids autovification from just reading data.
This is the only advantage of methods like C<element>, C<row>, etc. compared
to regular Perl constructions.

=item *

It is assumed that row and column indexes passed to the methods are integers.
If they are negative, they will count from the end instead of
the beginning, as in regular Perl array subscripts.  Specifying a negative
index that is off the beginning of the array (e.g., specifying column -6 
on an array whose width is 5) will cause an exception to be thrown.
This is different than specifying an index is off the end of the array -- 
reading column #5 of a three-column array will return an empty column,
and trying to write to tha column will pad out the intervening columns 
with undefined values.

The behavior of the module when anything other than an integer is
passed in (strings, undef, floats, NaN, objects, etc.) is unspecified.
Don't do that.

=back

=head2 BASIC CONSTRUCTOR METHODS

=over

=item B<new( I<row_ref, row_ref...>)>

=item B<new( I<aoa_ref> )>

Returns a new Array::2D object.  It accepts a list of array 
references as arguments, which become the rows of the object.

If it receives only one argument, and that argument is an array of
arrays -- that is, a reference to an unblessed array, and in turn
that array only contains references to unblessed arrays -- then the
arrayrefs contained in that structure are made into the rows of a new
Array::2D object.

If you want it to bless an existing arrayref-of-arrayrefs, use
C<bless()>.  If you don't want to reuse the existing arrayrefs as
the rows inside the object, use C<clone()>.

If you think it's possible that the detect-an-AoA-structure could
give a false positive (you want a new object that might have only one row,
where each entry in that row is an reference to an unblessed array),
use C<< Array::2D->bless ( [ @your_rows ] ) >>.

=cut

sub new {

    if (    2 == @_
        and is_plain_arrayref( $_[1] )
        and all { is_plain_arrayref($_) } @{ $_[1] } )
    {
        my $class = shift;
        my $aoa   = shift;

        my $self = [ @{$aoa} ];
        CORE::bless $self, $class;
        return $self;
    }

    goto &bless;

}

=item B<bless(I<row_ref, row_ref...>)>

=item B<bless(I<aoa_ref>)>

Just like new(), except that if passed a single arrayref which contains
only other arrayrefs, it will bless the outer arrayref and return it. 
This saves the time and memory needed to copy the rows.

Note that this blesses the original array, so any other references to
this data structure will become a reference to the object, too.

=cut

## no critic (RequireTrailingCommaAtNewline)
# eliminates a PPI false positive -- it thinks bless { ... } is a hashref

sub bless {    ## no critic (Subroutines::ProhibitBuiltInHomonyms)

    my $class = shift;

    my @rows = @_;

    if ( 0 == @rows ) {    # if no arguments, new anonymous AoA
        return $class->empty;
    }

    if ( 1 == @rows ) {
        my $blessing = blessed( $rows[0] );
        if ( defined($blessing) and $blessing eq $class ) {
            # already an object
            return $rows[0];
        }

        if ( is_plain_arrayref( $rows[0] )
            and all { is_plain_arrayref($_) } @{ $rows[0] } )
        {
            return CORE::bless $rows[0], $class;
        }
    }

    if ( any { not is_plain_arrayref($_) } @rows ) {
        croak "Arguments to $class->new or $class->blessed "
          . 'must be unblessed arrayrefs (rows)';
    }

    return CORE::bless [@rows], $class;

}

## use critic

=item B<empty>

Returns a new, empty Array::2D object.

=cut

sub empty {
    my $class = shift;
    return CORE::bless [], $class;
}

=item B<new_across(I<chunksize, element, element, ...>)>

Takes a flat list and returns it as an Array::2D object, 
where each row has the number of elements specified. So, for example,

 Array::2D->new_across (3, qw/a b c d e f g h i j/)

returns

  [ 
    [ a, b, c] ,
    [ d, e, f] ,
    [ g, h, i] ,
    [ j ],
  ]

=cut

sub new_across {
    my $class = shift;

    my $quantity = shift;
    my @values   = @_;

    my $self;
    my $it = natatime( $quantity, @values );
    while ( my @vals = $it->() ) {
        push @{$self}, [@vals];
    }

    CORE::bless $self, $class;
    return $self;

}

=item B<new_down(I<chunksize, element, element, ...>)>

Takes a flat list and returns it as an Array::2D object, 
where each column has the number of elements specified. So, for
example,

 Array::2D->new_down (3, qw/a b c d e f g h i j/)

returns

  [ 
    [ a, d, g, j ] ,
    [ b, e, h ] ,
    [ c, f, i ] ,
  ]

=cut

sub new_down {
    my $class = shift;

    my $quantity = shift;
    my @values   = @_;

    my $self;
    my $it = natatime( $quantity, @values );

    while ( my @vals = $it->() ) {
        for my $i ( 0 .. $#vals ) {
            push @{ $self->[$i] }, $vals[$i];
        }
    }

    CORE::bless $self, $class;
    return $self;

}

=item B<new_to_term_width (...)>

A combination of C<new_down()> and C<tabulate_equal_width()>.  Takes three named
arguments:

=over

=item array => I<arrayref>

A one-dimensional list of scalars.

=item separator => I<separator>

A scalar to be passed to ->tabulate_equal_width(). The default is
a single space.

=item width => I<width>

The width of the terminal. If not specified, defaults to 80.

=back

The method determines the number of text columns required, creates an
Array::2D object of that number of text columns using new_down, and then
returns first the object and then the results of ->tabulate_equal_width()
on that object.

See L<Tabulating into Columnar Output|/TABULATING INTO COLUMNAR OUTPUT> 
below for information on how the widths of text in text columns 
are determined.

=cut

sub new_to_term_width {

    my $class  = shift;
    my %params = validate(
        @_,
        {   array     => { type    => ARRAYREF },
            width     => { default => 80 },
            separator => { default => q[ ] },
        },
    );

    my $array = $params{array};

    my $separator = $params{separator};
    my $sepwidth  = $text_columns_cr->($separator);
    my $colwidth  = $sepwidth + max( map { $text_columns_cr->($_) } @$array );
    my $cols      = floor( ( $params{width} + $sepwidth ) / ($colwidth) ) || 1;

    # add sepwidth there to compensate for the fact that we don't actually
    # print the separator at the end of the line

    my $rows = ceil( @$array / $cols );

    my $array2d = $class->new_down( $rows, @$array );

    my $tabulated = $array2d->tabulate_equal_width($separator);

    return $array2d, $tabulated;

}

=item B<<< new_from_tsv(I<tsv_string, tsv_string...>) >>>

Returns a new object from a string containing tab-separated values. 
The string is first split into lines and then split into values by tabs.


Lines can be separated by by carriage returns, line feeds, a CR/LF pair, or
other characters matching Perl's \R (see L<perlrebackslash|perlrebackslash>).

If multiple strings are provided, they will be considered additional lines. So,
if one has already read a TSV file, one can pass the entire contents, the
series of lines in the TSV file, or a combination of two.

Note that this is not a routine that reads TSV I<files>, just TSV
I<strings>, which may or may not have been read from a file. See
C<L<new_from_file|new_from_file>()> for a method that reads TSV
files (and other kinds).

=cut

sub new_from_tsv {
    my $class = shift;
    my @lines = map { split(/\R/) } @_;

    my $self = [ map { [ split(/\t/) ] } @lines ];

    CORE::bless $self, $class;
    return $self;
}

=back

=head2 CONSTRUCTOR METHODS THAT READ FILES

=over

=item B<<< new_from_xlsx(I<xlsx_filespec, sheet_requested>) >>>

This method requires that L<Spreadsheet::ParseXLSX|Spreadsheet::ParseXLSX>
be installed on the local system.

Returns a new object from a worksheet in an Excel XLSX file, consisting
of the rows and columns of that sheet. The I<sheet_requested> parameter
is passed directly to the C<< ->worksheet >> method of 
C<Spreadsheet::ParseXLSX>, which accepts a name or an index. If nothing
is passed, it requests sheet 0 (the first sheet).

=cut

sub new_from_xlsx {
    my $class           = shift;
    my $xlsx_filespec   = shift;
    my $sheet_requested = shift || 0;

    # || handles empty strings

    croak 'No file specified in ' . __PACKAGE__ . '->new_from_xlsx'
      unless $xlsx_filespec;

    require Spreadsheet::ParseXLSX;    ### DEP ###

    my $parser   = Spreadsheet::ParseXLSX->new;
    my $workbook = $parser->parse($xlsx_filespec);

    if ( !defined $workbook ) {
        croak $parser->error();
    }

    my ( $error, $obj )
      = $class->_new_from_xlsx_sheet( $workbook, $sheet_requested );
    return $obj unless $error;

    croak( "$error in $xlsx_filespec in " . __PACKAGE__ . '->new_from_xlsx' );

}

=item B<<< new_from_xlsx_sheet(I<workbook, sheet_requested>) >>>

This method is used to fetch data from an Excel spreadsheet that has already
been loaded via the Spreadsheet::ParseXLSX module.

      my $parser = Spreadsheet::ParseXLSX->new;
      my $workbook = $parser->parse("file.xlsx");
      my $array2d = Array::2D->new($workbook, 'Sheet2');

This method will actually accept any object that uses the same interface as
C<Spreadsheet::ParseXLSX>, including C<Spreadsheet::ParseExcel>.

Returns a new object from one of worksheets in a workbook, consisting of the
rows and columns of that sheet. The I<sheet_requested> parameter is passed
directly to the C<< ->worksheet >> method of the workbook object.
C<Spreadsheet::ParseXLSX> accepts a name or an index. If nothing is passed, it
requests sheet 0 (the first sheet).

=cut

sub new_from_xlsx_sheet {
    my $class           = shift;
    my $workbook        = shift;
    my $sheet_requested = shift || 0;

    my ( $error, $obj )
      = $class->_new_from_xlsx_sheet( $workbook, $sheet_requested );
    return $obj unless $error;

    my $file = $workbook->get_filename();
    if ( not defined $file ) {
        $file = '';
    }
    else {
        $file = " in $file";
    }
    croak "$error $file in " . __PACKAGE__ . '->new_from_xlsx_sheet';

}

sub _new_from_xlsx_sheet {
    my $class           = shift;
    my $workbook        = shift;
    my $sheet_requested = shift;
    my $error;

    my $sheet = $workbook->worksheet($sheet_requested);
    if ( !defined $sheet ) {
        return ( "Sheet $sheet_requested not found", undef );
    }

    my ( $minrow, $maxrow ) = $sheet->row_range();
    my ( $mincol, $maxcol ) = $sheet->col_range();

    my @rows;

    foreach my $row ( $minrow .. $maxrow ) {

        my @cells = map { $sheet->get_cell( $row, $_ ) } ( $mincol .. $maxcol );

        foreach (@cells) {
            if ( defined $_ ) {
                $_ = $_->value;
            }
            else {
                $_ = q[];
            }
        }

        push @rows, \@cells;

    }
    return ($error, $class->bless( \@rows ));

}

=item B<<< new_from_file(I<filespec>, I<filetype>) >>>

Returns a new object from a file on disk, specified as I<filespec>.

If I<filetype> is present, then it must be either 'xlsx' or 'tsv', and it
will read the file assuming it is of that type.

If no I<filetype> is present, it will attempt to use the file's 
extension to determine the proper filetype. Any file whose extension is
'.xlsx' will be treated as type 'xlsx', and any file whose extension is
either '.tab' or '.tsv' will be treated as type 'tsv'.

For the moment, it will also assume that a file whose extension is '.txt'
is of type 'tsv'. It should be assumed that future versions
may attempt to determine whether the file is more likely to be a comma-separated
values file instead. To ensure that the file will be treated as tab-separated,
pass in a filetype explicitly.

If the file type is 'xlsx', this method
passes that file on to C<new_from_xlsx()> and requests the first worksheet. 

If the file type is 'tsv', 
it slurps the file in memory and passes the result to C<new_from_tsv>.
This uses L<File::Slurper|File::Slurper>, which mus be installed on the system.

=cut

my $filetype_from_ext_r = sub {
    my $filespec = shift;
    return unless $filespec;

    my ($ext) = $filespec =~ m[
                      [.]     # a dot
                      ([^.]+) # one or more non-dot characters
                      \z      # end of the string
                      ]x;

    my $lext = lc($ext);

    if ( $lext eq lc('xlsx') ) {
        return 'xlsx';
    }

    if ( any { $lext eq lc($_) } qw/tsv tab txt/ ) {
        return 'tsv';
    }

    return;

};

sub new_from_file {
    my $class    = shift;
    my $filespec = shift;
    my $filetype = shift || $filetype_from_ext_r->($filespec);

    croak "Cannot determine type of $filespec in "
      . __PACKAGE__
      . '->new_from_file'
      unless $filetype;

    if ( $filetype eq 'xlsx' ) {
        return $class->new_from_xlsx($filespec);
    }

    if ( $filetype eq 'tsv' ) {
        require File::Slurper;    ### DEP ###
        my $tsv = File::Slurper::read_text($filespec);
        return $class->new_from_tsv($tsv);
    }

    croak "File type $filetype unrecognized in "
      . __PACKAGE__
      . '->new_from_file';

}

################################################################
### shim allowing being called as either class or object method

my $invocant_cr = sub {
    my $invocant = shift;
    my $blessing = blessed $invocant;

    return ( $blessing, $invocant ) if defined $blessing;
    # invocant is an object blessed into the $blessing class

    my $array2d = shift;
    return ( $invocant, $array2d ) if is_arrayref($array2d);
    # invocant is a class

    ## no critic (ProhibitMagicNumbers)
    croak 'No array passed to ' . ( caller(1) )[3];

};

=back

=head2 COPYING AND REARRANGING ARRAYS

=over

=item B<clone()>

Returns new object which has copies of the data in the 2D array object.
The 2D array will be different, but if any of the elements of the 2D
array are themselves references, they will refer to the same things as
in the original 2D array.

=cut

sub clone {
    my ( $class, $self ) = &$invocant_cr;
    my $new = [ map { [ @{$_} ] } @{$self} ];
    CORE::bless $new, $class;
    return $new;
}

=item B<unblessed()>

Returns an unblessed array containing the same rows as the 2D
array object. If called as a class method and given an argument that is
already unblessed, will return the argument. Otherwise will create
a new, unblessed array.

This is usually pointless, as Perl lets you ignore the object-ness of
any object and access the data inside, but sometimes certain modules
don't like to break object encapsulation, and this will allow getting
around that .

Note that while modifying the elements inside the rows will modify the 
original 2D array, modifying the outer arrayref will not (unless
that arrayref was not blessed in the first place). So:

 my $unblessed = $array2d->unblessed;

 $unblessed->[0][0] = 'Up in the corner'; 
     # modifies original object

 $unblessed->[0] = [ 'Up in the corner ' , 'Yup']; 
    # does not modify original object

This can be confusing, so it's best to avoid modifying the result of
C<unblessed>. Use C<clone_unblessed> instead.

=cut

sub unblessed {
    my ( $class, $self ) = &$invocant_cr;
    return $self if not blessed $self;
    my $new = [ @{$self} ];
    return $new;
}

=item B<clone_unblessed()>

Returns a new, unblessed, array of arrays containing copies of the data
in the 2D array object.

The array of arrays will be different, but if any of the elements of
the  2D array are themselves references, they will refer to the same
things as in the original 2D array.

=cut

sub clone_unblessed {
    my ( $class, $self ) = &$invocant_cr;
    my $new = [ map { [ @{$_} ] } @{$self} ];
    return $new;
}

=item B<transpose()>

Transposes the array: the elements that used to be
in rows are now in columns, and vice versa.

In void context, alters the original. Otherwise, creates a new
Array::2D object and returns that.

The result of transpose() is pruned.

=cut

sub transpose {
    my ( $class, $self ) = &$invocant_cr;

    unless ( @{$self} ) {
        return $class->empty if defined wantarray;
        return $self;
    }

    my $new = [];

    foreach my $col ( 0 .. $class->last_col($self) ) {
        push @{$new}, [ map { $_->[$col] } @{$self} ];
    }

    $class->prune($new);

    # non-void context: return new object
    if ( defined wantarray ) {
        CORE::bless $new, $class;
        return $new;
    }

    # void context: alter existing array
    @{$self} = @{$new};
    return;

}

=item B<flattened()>

Returns the array as a single, one-dimensional flat list of all the defined
values. Note that it does not flatten any arrayrefs that are deep inside 
the 2D structure -- just the rows and columns of the structure itself.

=cut

sub flattened {
    my ( $class, $self ) = &$invocant_cr;
    my @flattened = map { @{$_} } @$self;
    return grep { defined $_ } @flattened;
}

=back

=head2 DIMENSIONS OF THE ARRAY

=over

=item B<is_empty()>

Returns a true value if the array is empty, false otherwise.

=cut

sub is_empty {
    my ( $class, $self ) = &$invocant_cr;
    return not( scalar @$self );
}

=item B<height()>

Returns the number of rows in the array.  The same as C<scalar @$array>.

=cut

sub height {
    my ( $class, $self ) = &$invocant_cr;
    return scalar @$self;
}

=item B<width()>

Returns the number of columns in the array. (The number of elements in
the longest row.)

=cut

sub width {
    my ( $class, $self ) = &$invocant_cr;
    return 0 unless @{$self};
    return max( map { scalar @{$_} } @{$self} );
}

=item B<last_row()>

Returns the index of the last row of the array.  If the array is
empty, returns -1. The same as C<$#{$array}>.

=cut

sub last_row {
    my ( $class, $self ) = &$invocant_cr;
    return $#{$self};
}

=item B<last_col()>

Returns the index of the last column of the array. (The index of the
last element in the longest row.) If the array is
empty, returns -1.

=cut

sub last_col {
    my ( $class, $self ) = &$invocant_cr;
    return -1 unless @{$self};
    return max( map { $#{$_} } @{$self} );
}

=back

=head2 READING ELEMENTS, ROWS, COLUMNS, SLICES

=over

=item B<element(I<row_idx, col_idx>)>

Returns the element in the given row and column. A slower way of
saying C<< $array2d->[I<row_idx>][I<col_idx>] >>, except that it avoids
autovivification.  Like that construct, it will return undef if the element
does not already exist.

=cut

sub element {
    ## no critic (ProhibitExplicitReturnUndef)
    my ( $class, $self ) = &$invocant_cr;

    my $row_idx = shift;
    return undef
      unless -@$self <= $row_idx and $row_idx <= $#{$self};
    my $col_idx = shift;
    return undef
      unless -@{ $self->[$row_idx] } <= $col_idx
      and $col_idx <= $#{ $self->[$row_idx] };
    return $self->[$row_idx][$col_idx];
}

=item B<row(I<row_idx>)>

Returns the elements in the given row.  A slower way of saying  C<<
@{$array2d->[I<row_idx>]} >>, except that it avoids autovivification.

=cut

sub row {
    my ( $class, $self ) = &$invocant_cr;
    my $row_idx = shift;
    return ()
      unless -@$self <= $row_idx
      and $row_idx <= $#{$self};
  # if empty, will test (0 <= $col_idx and $col_idx <= -1) which is always false
    my @row = @{ $self->[$row_idx] };
    pop @row while @row and not defined $row[-1];    # prune
    return @row;
}

=item B<col(I<col_idx>)>

Returns the elements in the given column.

=cut

sub col {
    my ( $class, $self ) = &$invocant_cr;

    my $col_idx = shift;
    my $width   = $class->width($self);
    return ()
      unless -$width <= $col_idx
      and $col_idx < $width;
    # if empty, will test (0 <= $col_idx and $col_idx < 0) which is always false

    $col_idx += $width if $col_idx < 0;
    # make into offset from beginning, not the end
    # Must do this because otherwise, counts from end of *this row*, not end of
    # whole array

    my @col
      = map { ( 0 <= $col_idx && $col_idx <= $#{$_} ) ? $_->[$col_idx] : undef }
      @{$self};
    # the element if it's valid in that row, otherwise undef
    pop @col while @col and not defined $col[-1];    # prune
    return @col;
}

=item B<< rows(I<row_idx, row_idx...>) >>

Returns a new Array::2D object with all the columns of the 
specified rows.

Note that duplicates are not de-duplicated, so the result of
$obj->rows(1,1,1) will be three copies of the same row.

=cut

sub rows {
    my ( $class, $self ) = &$invocant_cr;
    my @row_indices = @_;

    my $rows
      = $class->new(
        map { ( -@$self <= $_ && $_ <= $#{$self} ) ? $self->[$_] : [] }
          @row_indices );
    # the row if it's a valid row idx, othewise an empty ref
    $rows->prune();
    return $rows;
}

=item B<cols(I<col_idx>, <col_idx>...)>

Returns a new Array::2D object with the specified columns. This is transposed
from the original array's order, so each column requested will be in its own
row.

 $array = [ 
            [ qw/ a b c d / ],
            [ qw/ j k l m / ],
            [ qw/ w x y z / ],
          ];
 my $cols = Array::2D->cols($array, 1, 2);
 # $cols = bless [ [ qw/ b k x / ] , [ qw/ c l y / ] ], 'Array::2D';

Note that duplicates are not de-duplicated, so the result of
$obj->cols(1,1,1) will retrieve three copies of the same column.

=cut

sub cols {
    my ( $class, $self ) = &$invocant_cr;
    my @col_indices = @_;

    my $cols = [ map { [ $class->col( $self, $_ ) ] } @col_indices ];

    CORE::bless $cols, $class;
    $cols->prune;
    return $cols;
}

=item B<slice_cols(I<col_idx>, <col_idx>...)>

Returns a new Array::2D object with the specified columns of each row.
Unlike C<cols()>, the result of this method is not transposed.

 $array = [ 
            [ qw/ a b c d / ],
            [ qw/ j k l m / ],
            [ qw/ w x y z / ],
          ];
 my $sliced_cols = Array::2D->slice_cols($array, 1, 2);
 # $sliced_cols = bless [ 
 #                  [ qw/ b c / ] , 
 #                  [ qw/ k l / ] , 
 #                  [ qw/ x y / ] , 
 #                ], 'Array::2D';

Note that duplicates are not de-duplicated, so the result of
$obj->slice_cols(1,1,1) will retrieve three copies of the same column.

=cut

sub slice_cols {
    my ( $class, $self ) = &$invocant_cr;
    my @col_indices = @_;
    my $width       = $class->width($self);
    for my $col_idx (@col_indices) {
        $col_idx += $width if $col_idx < 0;
    }
    # must adjust this to whole array width, not just row width

    my $return = [];

    foreach my $row_r (@$self) {
        my @new_row;
        foreach my $col_idx (@col_indices) {
            if ( -$width <= $col_idx and $col_idx < $width ) {
                push @new_row, $row_r->[$col_idx];
            }
            else {
                push @new_row, undef;
            }
        }
        push @$return, \@new_row;
    }

    CORE::bless $return, $class;
    $return->prune;
    return $return;
}

=item B<slice(I<row_index_from, row_index_to, col_index_from, col_index_to>)>

Takes a two-dimensional slice of the array; like cutting a rectangle
out of the array.

In void context, alters the original array, which then will contain
only the area specified; otherwise, creates a new Array::2D 
object and returns the object.

Negative indicies are treated as though they mean that many from the end:
the last item is -1, the second-to-last is -2, and so on. 

Slices are always returned in the order of the original array, so 
$obj->slice(0,1,0,1) is the same as $obj->slice(1,0,1,0).

=cut

sub slice {
    my ( $class, $self ) = &$invocant_cr;

    my ( $firstrow, $lastrow, $firstcol, $lastcol, ) = @_;

    ### adjust row indices

    my $self_lastrow = $class->last_row($self);

    foreach my $row_idx ( $firstrow, $lastrow ) {
        next unless $row_idx < 0;
        $row_idx += $self_lastrow + 1;
    }

    ### adjust col indices

    my $self_lastcol = $class->last_col($self);

    foreach my $col ( $firstcol, $lastcol ) {
        next unless $col < 0;
        $col += $self_lastcol + 1;
    }

    ### sort indices

    ( $firstrow, $lastrow ) = ( $lastrow, $firstrow )
      if $lastrow < $firstrow;

    ( $firstcol, $lastcol ) = ( $lastcol, $firstcol )
      if $lastcol < $firstcol;

    # if it's specifying an area entirely off the beginning or end
    # of the array, return empty
    if (   $lastrow < 0
        or $self_lastrow < $firstrow
        or $lastcol < 0
        or $self_lastcol < $firstcol )
    {
        return $class->empty() if defined wantarray;
        @{$self} = ();
        return;
    }

    # otherwise, since it's at least partially in the array, set the rows
    # to be within the array.
    $lastrow  = $self_lastrow if $self_lastrow < $lastrow;
    $firstrow = 0             if $firstrow < 0;

    my $rows = $class->rows( $self, $firstrow .. $lastrow );

    # set the bounds to be within the column of these rows
    $firstcol = 0 if $firstcol < 0;
    my $rows_lastcol = $class->last_col($rows);
    $lastcol = $rows_lastcol if $rows_lastcol < $lastcol;

    my $new = $class->slice_cols( $rows, $firstcol .. $lastcol );
    return $new if defined wantarray;
    @{$self} = @{$new};
    return;
}

=back

=head2 SETTING ELEMENTS, ROWS, COLUMNS, SLICES

None of these methods return anything. At some point it might
be worthwhile to have them return the old values of whatever they changed
(when not called in void context), but they don't do that yet.

=over

=item B<set_element(I<row_idx, col_idx, value>)>

Sets the element in the given row and column to the given value. 
Just a slower way of saying 
C<< $array2d->[I<row_idx>][I<col_idx>] = I<value> >>.

=cut

sub set_element {
    my ( $class, $self ) = &$invocant_cr;
    my $row_idx = shift;
    my $col_idx = shift;
    $self->[$row_idx][$col_idx] = shift;
    return;
}

=item B<set_row(I<row_idx , value, value...>)>

Sets the given row to the given set of values.
A slower way of saying  C<< {$array2d->[I<row_idx>] = [ @values ] >>.

=cut

sub set_row {
    my ( $class, $self ) = &$invocant_cr;
    my $row_idx = shift || 0;
    my @elements = @_;
    return $#{$self} unless @elements;
    $self->[$row_idx] = \@elements;
    return;
}

=item B<set_col(I<col_idx, value, value...>)>

Sets the given column to the given set of values.  If more values are given than
there are rows, will add rows; if fewer values than there are rows, will set the 
entries in the remaining rows to C<undef>.

=cut

sub set_col {
    my ( $class, $self ) = &$invocant_cr;
    my $col_idx  = shift;
    my @elements = @_;

    # handle negative col_idx

    my $width = $class->width($self);
    return $width unless @elements;

    if ( $col_idx < -$width ) {
        croak("$class->set_col: negative index off the beginning of the array");
    }
    $col_idx += $width if $col_idx < 0;

    for my $row_idx ( 0 .. max( $class->last_row($self), $#elements ) ) {
        $self->[$row_idx][$col_idx] = $elements[$row_idx];
    }
    return;

}

=item B<< set_rows(I<start_row_idx, array_of_arrays>) >>

=item B<< set_rows(I<start_row_idx, row_ref, row_ref ...>) >>

Sets the rows starting at the given start row index to the rows given.
So, for example, $obj->set_rows(1, $row_ref_a, $row_ref_b) will set 
row 1 of the object to be the elements of $row_ref_a and row 2 to be the 
elements of $row_ref_b.

The arguments after I<start_row_idx> are passed to C<new()>, so it accepts
any of the arguments that C<new()> accepts.

Returns the height of the array.

=cut

sub set_rows {
    my ( $class, $self ) = &$invocant_cr;
    my $self_start_row_idx = shift;
    my $given              = $class->new(@_);
    my @given_rows         = @{$given};
    for my $given_row_idx ( 0 .. $#given_rows ) {
        my @elements = @{ $given_rows[$given_row_idx] };
        $self->[ $self_start_row_idx + $given_row_idx ] = \@elements;
    }
    return;
}

=item B<set_cols(I<start_col_idx, col_ref, col_ref>...)>

Sets the columns starting at the given start column index to the columns given.
So, for example, $obj->set_cols(1, $col_ref_a, $col_ref_b) will set 
column 1 of the object to be the elemnents of $col_ref_a and column 2 to be the
elements of $col_ref_b.

=cut

sub set_cols {
    my ( $class, $self ) = &$invocant_cr;
    my $self_start_col_idx = shift;
    my @given_cols         = @_;
    my $width;

    foreach my $given_col_idx ( 0 .. $#given_cols ) {
        my @given_elements = @{ $given_cols[$given_col_idx] };
        $width = $class->set_col( $self, $self_start_col_idx + $given_col_idx,
            @given_elements );
    }
    return;
}

=item B<set_slice(I<first_row, first_col, array_of_arrays>)>

=item B<set_slice(I<first_row, first_col, row_ref, row_ref...>)>

Sets a rectangular segment of the object to have the values of the supplied
rows or array of arrays, beginning at the supplied first row and first column.
The arguments after the row and columns are passed to C<new()>, so it accepts
any of the arguments that C<new()> accepts.

=cut

sub set_slice {
    my ( $class, $self ) = &$invocant_cr;

    my $class_firstrow = shift;
    my $class_firstcol = shift;

    my $slice          = $class->new(@_);
    my $slice_last_row = $slice->last_row;
    my $slice_last_col = $slice->last_col;

    for my $row_idx ( 0 .. $slice_last_row ) {
        for my $col_idx ( 0 .. $slice_last_col ) {
            $self->[ $class_firstrow + $row_idx ][ $class_firstcol + $col_idx ]
              = $slice->[$row_idx][$col_idx];
        }
    }

    return;

}

=back

=head2 INSERTING ROWS AND COLUMNS

All these methods return the new number of either rows or columns.

=over

=item B<ins_row(I<row_idx, element, element...>)>

Adds the specified elements as a new row at the given index. 

=cut

sub ins_row {
    my ( $class, $self ) = &$invocant_cr;
    my $row_idx = shift;
    my @row     = @_;

    if ( $#{$self} < $row_idx ) {
        $self->[$row_idx] = [@row];
    }
    else {
        splice( @{$self}, $row_idx, 0, [@row] );
    }

    return scalar @{$self};
}

=item B<ins_col(I<col_idx, element, element...>)>

Adds the specified elements as a new column at the given index. 

=cut

sub ins_col {
    my ( $class, $self ) = &$invocant_cr;
    my $col_idx = shift;
    my @col     = @_;

    # handle negative col_idx
    my $width = $class->width($self);
    return $width unless @col;

    if ( $col_idx < -$width ) {
        croak("$class->ins_col: negative index off the beginning of the array");
    }
    $col_idx += $width if $col_idx < 0;

    my $last_row = max( $class->last_row($self), $#col );
    # if this is below the array, extend the array so it is longer
    $#{$self} = $last_row;

    for my $row_idx ( 0 .. $last_row ) {
        # if this is off to the right of this row,
        if ( $#{ $self->[$row_idx] } < $col_idx ) {
            # just set the element
            $self->[$row_idx][$col_idx] = $col[$row_idx];
        }
        else {
            # otherwise, insert it in using splice
            splice( @{ $self->[$row_idx] }, $col_idx, 0, $col[$row_idx] );
        }
    }

    return $class->width($self) if defined wantarray;
    return;
}

=item B<ins_rows(I<row_idx, aoa_ref>)>

Takes the specified array of arrays and inserts them as new rows at the
given index.  

The arguments after the row index are passed to C<new()>, so it accepts
any of the arguments that C<new()> accepts.

=cut

sub ins_rows {
    my ( $class, $self ) = &$invocant_cr;
    my $row_idx = shift;
    my $given   = $class->new(@_);

    splice( @{$self}, $row_idx, 0, @$given );
    return scalar @{$self};
}

=item B<ins_cols(I<col_idx, col_ref, col_ref...>)>

Takes the specified array of arrays and inserts them as new columns at
the given index.  

=cut

sub ins_cols {
    my ( $class, $self ) = &$invocant_cr;
    my $col_idx = shift;
    my @cols    = @_;

    my $last_row = max( $class->last_row($self), map { $#{$_} } @cols );

    for my $row_idx ( 0 .. $last_row ) {
        for my $col (@cols) {
            splice( @{ $self->[$row_idx] }, $col_idx, 0, $col->[$row_idx] );
        }
    }
    return $class->width($self) if defined wantarray;
    return;
}

=item B<unshift_row(I<element, element...>)>

Adds the specified elements as the new first row. 

=cut

sub unshift_row {
    my ( $class, $self ) = &$invocant_cr;
    my @col_values = @_;
    return unshift @{$self}, \@col_values;
}

=item B<unshift_col(I<element, element...>)>

Adds the specified elements as the new first column. 

=cut

sub unshift_col {
    my ( $class, $self ) = &$invocant_cr;
    my @col_values = @_;
    return $class->ins_col( $self, 0, @col_values );
}

=item B<unshift_rows(I<aoa_ref>)>

=item B<unshift_rows(I<row_ref, row_ref...>)>

Takes the specified array of arrays and adds them as new rows before
the beginning of the existing rows. Returns the new number of rows.

The arguments are passed to C<new()>, so it accepts
any of the arguments that C<new()> accepts.

=cut

sub unshift_rows {
    my ( $class, $self ) = &$invocant_cr;
    my $given = $class->new(@_);
    return unshift @{$self}, @$given;
}

=item B<unshift_cols(I<col_ref, col_ref...>)>

Takes the specified array of arrays and adds them as new columns,
before the beginning of the existing columns. Returns the new number of
columns.

=cut

sub unshift_cols {
    my ( $class, $self ) = &$invocant_cr;
    my @cols = @_;
    return $class->ins_cols( $self, 0, @cols );
}

=item B<push_row(I<element, element...>)>

Adds the specified elements as the new final row. Returns the new 
number of rows.

=cut

sub push_row {
    my ( $class, $self ) = &$invocant_cr;
    my @col_values = @_;
    return push @{$self}, \@col_values;
}

=item B<push_col(I<element, element...>)>

Adds the specified elements as the new final column. Returns the new 
number of columns.

=cut

sub push_col {
    my ( $class, $self ) = &$invocant_cr;
    my @col   = @_;
    my $width = $class->width($self);
    return $width unless @col;

    for my $row_idx ( 0 .. max( $class->last_row($self), $#col ) ) {
        $self->[$row_idx][$width] = $col[$row_idx];
    }

    return $width + 1;    # new width
}

=item B<push_rows(I<aoa_ref>)>

=item B<push_rows(I<row_ref, row_ref...>)>

Takes the specified array of arrays and adds them as new rows after the
end of the existing rows. Returns the new number of rows.

The arguments are passed to C<new()>, so it accepts
any of the arguments that C<new()> accepts.

=cut

sub push_rows {
    my ( $class, $self ) = &$invocant_cr;
    my $rows = $class->new(@_);
    return push @{$self}, @$rows;
}

=item B<push_cols(I<col_ref, col_ref...>)>

Takes the specified array of arrays and adds them as new columns, after
the end of the existing columns. Returns the new number of columns.

=cut

sub push_cols {
    my ( $class, $self ) = &$invocant_cr;
    my @cols    = @_;
    my $col_idx = $class->last_col($self);

    if ( -1 == $col_idx ) {
        @{$self} = map { [ @{$_} ] } @{$self};
        return $class->width($self) if defined wantarray;
        return;
    }

    my $last_row = max( $class->last_row($self), $#cols );
    my $last_col = $class->last_col($self);

    for my $row_index ( 0 .. $last_row ) {
        my $row_r = $self->[$row_index];
        if ( not defined $row_r ) {
            $row_r = $self->[$row_index] = [];
        }
        $#{$row_r} = $last_col;    # pad out
        push @{$row_r}, @{ $cols[$row_index] };
    }

    return $class->width($self) if defined wantarray;
    return;

}

=back

=head2 RETRIEVING AND DELETING ROWS AND COLUMNS

=over

=item B<del_row(I<row_idx>)>

Removes the row of the object specified by the index and returns a list
of the elements of that row.

=cut

sub del_row {
    my ( $class, $self ) = &$invocant_cr;
    my $row_idx = shift;

    return () unless @{$self};
    return () if $class->last_row($self) < $row_idx;

    if ( defined wantarray ) {
        my @deleted = $class->row( $self, $row_idx );
        splice( @{$self}, $row_idx, 1 );
        $class->prune($self);
        pop @deleted while @deleted and not defined $deleted[-1];    # prune
        return @deleted;
    }

    splice( @{$self}, $row_idx, 1 );
    $class->prune($self);
    return;
}

=item B<del_col(I<col_idx>)>

Removes the column of the object specified by the index and returns a
list of the elements of that column.

=cut

sub del_col {
    my ( $class, $self ) = &$invocant_cr;
    my $col_idx = shift;

    # handle negative col_idx
    my $width = $class->width($self);
    return () if $width <= $col_idx;

    if ( $col_idx < -$width ) {
        croak("$class->del_col: negative index off the beginning of the array");
    }
    $col_idx += $width if $col_idx < 0;

    my @deleted;
    if ( defined wantarray ) {
        @deleted = $class->col( $self, $col_idx );
        pop @deleted while @deleted and not defined $deleted[-1];    # prune
    }

    foreach my $row ( @{$self} ) {
        splice( @{$row}, $col_idx, 1 );
    }
    $class->prune($self);

    return @deleted if defined wantarray;
    return;
}

=item B<del_rows(I<row_idx>, I<row_idx>...)>

Removes the rows of the object specified by the indices. Returns an
Array::2D object of those rows.

=cut

sub del_rows {
    my ( $class, $self ) = &$invocant_cr;
    my @row_idxs = @_;

    unless (@$self) {
        return $class->empty if defined wantarray;
        return;
    }

    my $deleted;
    if ( defined wantarray ) {
        $deleted = $class->rows( $self, @row_idxs );
    }

    foreach my $row_idx (@row_idxs) {
        splice( @{$self}, $row_idx, 1 );
    }

    $class->prune($self);
    return $deleted if defined wantarray;
    return;
}

=item B<del_cols(I<col_idx>, I<col_idx>...)>

Removes the columns of the object specified by the indices. Returns an
Array::2D object of those columns.

=cut

sub del_cols {
    my ( $class, $self ) = &$invocant_cr;
    my @col_idxs = @_;

    unless (@$self) {
        return $class->empty if defined wantarray;
        return;
    }

    my $deleted;
    if ( defined wantarray ) {
        $deleted = $class->cols( $self, @col_idxs );
    }

    foreach my $col_idx ( reverse sort @_ ) {
        $self->del_col($col_idx);
    }

    $class->prune($self);
    return $deleted if defined wantarray;
    return;
}

=item B<shift_row()>

Removes the first row of the object and returns a list  of the elements
of that row.

=cut

sub shift_row {
    my ( $class, $self ) = &$invocant_cr;
    return () unless @{$self};
    my @row = @{ shift @{$self} };
    pop @row while @row and not defined $row[-1];
    $class->prune($self);
    return @row;
}

=item B<shift_col()>

Removes the first column of the object and returns a list of the
elements of that column.

=cut

sub shift_col {
    my ( $class, $self ) = &$invocant_cr;
    my @col = map { shift @{$_} } @{$self};
    pop @col while @col and not defined $col[-1];    # prune
    $class->prune($self);
    return @col;
}

=item B<pop_row()>

Removes the last row of the object and returns a list of the elements
of that row.

=cut

sub pop_row {
    my ( $class, $self ) = &$invocant_cr;
    return () unless @{$self};
    my @row = @{ pop @{$self} };
    pop @row while @row and not defined $row[-1];    # prune
    $class->prune($self);
    return @row;
}

=item B<pop_col()>

Removes the last column of the object and returns  a list of the
elements of that column.

=cut

sub pop_col {
    my ( $class, $self ) = &$invocant_cr;
    return () unless @{$self};
    my $last_col = $class->last_col($self);
    return () if -1 == $last_col;
    $class->prune($self);
    return $class->del_col( $self, $last_col );
}

=back

=head2 ADDING OR REMOVING PADDING

Padding, here, means empty values beyond
the last defined value of each column or row. What counts as "empty"
depends on the method being used.

=over

=item B<prune()>

Occasionally an array of arrays can end up with final rows or columns
that are entirely undefined. For example:

 my $obj = Array::2D->new ( [ qw/a b c/]  , [ qw/f g h/ ]);
 $obj->[0][4] = 'e';
 $obj->[3][0] = 'k';

 # a b c undef e
 # f g h
 # (empty)
 # k

 $obj->pop_row();
 $obj->pop_col();

 # a b c undef
 # f g h
 # (empty)

That would yield an object with four columns, but in which the last
column  and last row (each with index 3) consists of only undefined
values.

The C<prune> method eliminates these entirely undefined or empty
columns and rows at the end of the object.

In void context, alters the original object. Otherwise, creates a new
Array::2D object and returns the object.

=cut

sub prune {
    my ( $class, $self ) = &$invocant_cr;
    my $callback = sub { !defined $_ };
    return $class->prune_callback( $self, $callback );
}

=item B<prune_empty()>

Like C<prune>, but treats not only undefined values as blank, but also 
empty strings.

=cut

sub prune_empty {
    my ( $class, $self ) = &$invocant_cr;
    my $callback = sub { not defined $_ or $_ eq q[] };
    return $class->prune_callback( $self, $callback );
}

=item B<prune_space()>

Like C<prune>, but treats not only undefined values as blank, but also 
strings that are empty or that consist solely of white space.

=cut

sub prune_space {
    my ( $class, $self ) = &$invocant_cr;
    my $callback = sub { not defined $_ or m[\A \s* \z]x };
    return $class->prune_callback( $self, $callback );
}

=item B<prune_callback(I<code_ref>)>

Like C<prune>, but calls the <code_ref> for each element, setting $_ to
each element. If the callback code returns true, the value is
considered padding, and is removed if it's beyond the last non-padding
value at the end of a column or row.

For example, this would prune values that were undefined,  the empty
string, or zero:

 my $callback = sub { 
     ! defined $_ or $_ eq q[] or $_ == 0;
 }
 $obj->prune_callback($callback);

In void context, alters the original object. Otherwise, creates a new
Array::2D object and returns the object.

Completely empty rows cannot be sent to the callback function,
so those are always removed.

=cut

sub prune_callback {
    my ( $class, $orig ) = &$invocant_cr;
    my $callback = shift;
    my $self;

    if ( defined wantarray ) {
        $self = $class->clone($orig);
    }
    else {
        $self = $orig;
    }

    # remove final blank rows
    while (
        @{$self}
        and (  not defined $self->[-1]
            or 0 == @{ $self->[-1] }
            or all { $callback->() } @{ $self->[-1] } )
      )
    {
        pop @{$self};
    }

    # return if it's all blank
    return $self unless ( @{$self} );

    # remove final blank columns

    foreach my $row_r ( @{$self} ) {
        while ( @{$row_r} ) {
            local $_ = $row_r->[-1];
            last if not $callback->();
            pop @$row_r;
        }
    }

    return $self;
}

=item B<pad(I<value>)>

The opposite of C<prune()>, this pads out the array so every column
has the same number of elements.  If provided, the added elements are
given the value provided; otherwise, they are set to undef.

=cut

sub pad {
    my ( $class, $orig ) = &$invocant_cr;
    my $padding = shift;
    my $self;
    if ( defined wantarray ) {
        $self = $class->clone($orig);
    }
    else {
        $self = $orig;
    }
    my $last_col = $class->last_col($self);

    if ( not defined $padding ) {
        foreach (@$self) {
            $#{$_} = $last_col;
        }
    }
    else {
        foreach (@$self) {
            push @$_, $padding while $#{$_} < $last_col;
        }
    }

    return $self;

}

=back

=head2 MODIFYING EACH ELEMENT

Each of these methods alters the original array in void context.
If not in void context, creates a new Array::2D object and returns
the object.

=over

=item B<apply(I<coderef>)>

Calls the C<$code_ref> for each element, aliasing $_ to each element in
turn. This allows an operation to be performed on every element.

For example, this would lowercase every element in the array (assuming
all values are defined):

 $obj->apply(sub {lc});

If an entry in the array is undefined, it will still be passed to the
callback.

For each invocation of the callback, @_ is set to the row and column
indexes (0-based).

=cut

sub apply {
    my ( $class, $orig ) = &$invocant_cr;
    my $callback = shift;
    my $self;

    if ( defined wantarray ) {
        $self = $class->clone($orig);
    }
    else {
        $self = $orig;
    }

    for my $row ( @{$self} ) {
        for my $idx ( 0 .. $#{$row} ) {
            for ( $row->[$idx] ) {
                # localize $_ to $row->[$idx]. Autovivifies the row.
                $callback->( $row, $idx );
            }
        }
    }
    return $self;
}

=item B<trim()>

Removes white space, if present, from the beginning and end  of each
element in the array.

=cut

sub trim {
    my ( $class, $self ) = &$invocant_cr;

    my $callback = sub {
        return unless defined;
        s/\A\s+//;
        s/\s+\z//;
        return;
    };

    return $class->apply( $self, $callback );
}

=item B<trim_right()>

Removes white space from the end of each element in the array.

In void context, alters the original object. Otherwise, creates a new
Array::2D object and returns the object.

=cut

sub trim_right {
    my ( $class, $self ) = &$invocant_cr;

    my $callback = sub {
        return unless defined;
        s/\s+\z//;
        return;
    };

    return $class->apply( $self, $callback );
}

=item B<define()>

Replaces undefined values with the empty string.

=cut

sub define {
    my ( $class, $self ) = &$invocant_cr;

    my $callback = sub {
        $_ //= q[];
    };
    return $class->apply( $self, $callback );
}

=back

=head2 TRANSFORMING ARRAYS INTO OTHER STRUCTURES

=over

=item B<hash_of_rows(I<col_idx>)>

Returns a hash reference.  The values of the specified
column of the array become the keys of the hash. The values of the hash
are arrayrefs containing the elements
of the rows of the array, with the value in the key column removed.

If the key column is not specified, the first column is used for the
keys.

So:

 $obj = Array::2D->new([qw/a 1 2/],[qw/b 3 4/]);
 $hashref = $obj->hash_of_rows(0);
 # $hashref = { a => [ '1' , '2' ]  , b => [ '3' , '4' ] }

=cut

sub hash_of_rows {
    my ( $class, $self ) = &$invocant_cr;
    my $col = shift;

    my %hash;

    if ($col) {
        for my $row_r ( @{$self} ) {
            my @row = @{$row_r};
            my $key = splice( @row, $col, 1 );
            $hash{$key} = \@row;
        }
    }
    else {

        for my $row_r ( @{$self} ) {
            my @row = @{$row_r};
            my $key = shift @row;
            $hash{$key} = \@row;
        }

    }

    return \%hash;
}

=item B<hash_of_row_elements(I<key_column_idx, value_column_idx>)>

Like C<hash_of_rows>, but accepts a key column and a value column, and
the values are not whole rows but only single elements.

So:

 $obj = Array::2D->new([qw/a 1 2/],[qw/b 3 4/]);
 $hashref = $obj->hash_of_row_elements(0, 1);
 # $hashref = { a => '1' , b => '3' }

If neither key column nor value column are specified, column 0 will be
used for the key and the column 1 will be used for the value.

If the key column is specified but the value column is not, then the
first column that is not the key column will be used as the value
column. (In other words, if the key column is column 0, then column 1
will be used as the value; otherwise column 0 will be used as the
value.)

=cut

sub hash_of_row_elements {
    my ( $class, $self ) = &$invocant_cr;

    my ( $keycol, $valuecol );
    if (@_) {
        $keycol = shift;
        $valuecol = shift // ( 0 == $keycol ? 1 : 0 );

        # $valuecol defaults to first column that is not the same as $keycol
    }
    else {
        $keycol   = 0;
        $valuecol = 1;
    }

    my %hash;
    for my $row_r ( @{$self} ) {
        $hash{ $row_r->[$keycol] } = $row_r->[$valuecol];
    }

    return \%hash;
}

=back

=head2 TABULATING INTO COLUMNAR OUTPUT

If the L<Unicode::GCString|Unicode::GCString> module can be loaded,
its C<columns> method will be used to determine the width of each
character. This will treat composed accented characters and
double-width Asian characters correctly.

Otherwise, Array::2D will use Perl's C<length> function.

=over

=item B<tabulate(I<separator>)>

Returns an arrayref of strings, where each string consists of the
elements of each row, padded with enough spaces to ensure that each
column has a consistent width.

The columns will be separated by whatever string is passed to
C<tabulate()>.  If nothing is passed, a single space will be used.

So, for example,

 $obj = Array::2D->new([qw/a bbb cc/],[qw/dddd e f/]);
 $arrayref = $obj->tabulate();

 # $arrayref = [ 'a    bbb cc' ,
 #               'dddd e   f'
 #             ];

Completely empty columns and rows will be removed.

=item B<tabulate_equal_width(I<separator>)>

Like C<tabulate()>, but instead of each column having its own width,
all columns have the same width.

=cut

my $prune_space_list_cr = sub {
    my @cells = @_;

    pop @cells
      while @cells
      and (not defined $cells[-1]
        or $cells[-1] eq q[]
        or $cells[-1] =~ m/\A\s*\z/ );

    return @cells;
};

{
    my $equal_width;

    my $tabulate_cr = sub {
        my ( $class, $orig ) = &$invocant_cr;
        my $self = $class->define($orig);

        my $separator = shift // q[ ];
        my @length_of_col;
        my $maxwidths = 0;

        foreach my $row ( @{$self} ) {
            my @cells = @{$row};
            for my $this_col ( 0 .. $#cells ) {
                my $thislength = $text_columns_cr->( $cells[$this_col] );

                $maxwidths = max( $maxwidths, $thislength ) if $equal_width;
                $length_of_col[$this_col] = $thislength
                  if ( not $length_of_col[$this_col]
                    or $length_of_col[$this_col] < $thislength );
            }
        }

        my @lines;

        foreach my $record_r ( @{$self} ) {
            my @cells = $prune_space_list_cr->( @{$record_r} );

            # prune trailing cells

            next unless @cells;    # skip blank rows

            for my $this_col ( reverse( 0 .. ( $#cells - 1 ) ) ) {
                if ( 0 == $length_of_col[$this_col] ) {
                    splice @cells, $this_col, 1;
                    next;
                }
                # delete blank columns so it doesn't add the separator

                my $width
                  = $equal_width ? $maxwidths : $length_of_col[$this_col];

                #$cells[$this_col]
                #  = sprintf( '%-*s', $width, $cells[$this_col] );

                my $spaces = $width - $text_columns_cr->( $cells[$this_col] );
                $cells[$this_col] .= ( ' ' x $spaces ) if $spaces > 0;
            }
            push @lines, join( $separator, @cells );

        }

        return \@lines;

    };

    sub tabulate {
        $equal_width = 0;
        goto $tabulate_cr;
    }

    sub tabulate_equal_width {
        $equal_width = 1;
        goto $tabulate_cr;
    }

}

=item B<tabulated(I<separator>)>

Like C<tabulate()>, but returns the data as a single string, using
line feeds as separators of rows, suitable for sending to a terminal.

=cut

sub tabulated {
    my ( $class, $self ) = &$invocant_cr;
    my $lines_r = $class->tabulate( $self, @_ );
    return join( "\n", @$lines_r ) . "\n";
}

=back

=head2 SERIALIZING AND OUTPUT TO FILES

=over

=item B<< tsv_lines(I<headers>) >>

Returns a list of strings in list context, or an arrayref of strings in
scalar context. The elements of each row are present in the string,
separated by tab characters.

If there are any arguments, they will be used first as the first
row of text. The idea is that these will be the headers of the
columns. It's not really any different than putting the column
headers as the first element of the data, but frequently these are
stored separately. If there is only one element and it is a reference
to an array, that array will be used as the first row of text.

If tabs are present in any element,
they will be replaced by the Unicode Replacement Character, U+FFFD.

=cut

=item B<< tsv(I<headers>) >>

Returns a single string with the elements of each row delimited by
tabs, and rows delimited by line feeds.

If there are any arguments, they will be used first as the first
row of text. The idea is that these will be the headers of the
columns. It's not really any different than putting the column
headers as the first element of the data, but frequently these are
stored separately. If there is only one element and it is a reference
to an array, that array will be used as the first row of text.

If tabs or line feeds are present in any element,
they will be replaced by the Unicode Replacement Character, U+FFFD.

=cut

sub tsv_lines {

    my ( $class, $self ) = &$invocant_cr;
    my @rows = @$self;

    my @lines;

    my @headers = @_;
    if (@headers) {
        if ( 1 == @headers and is_plain_arrayref( $headers[0] ) ) {
            unshift @rows, $headers[0];
        }
        else {
            unshift @rows, \@headers;
        }
    }

    my $carped;
    foreach my $row (@rows) {
        my @cells = @{$row};
        foreach (@cells) {
            $_ //= q[];
            my $substitutions = s/\t/\x{FFFD}/g;
            if ( $substitutions and not $carped ) {
                carp 'Tab character found converting to tab-separated values. '
                  . 'Replaced with REPLACEMENT CHARACTER';
                $carped = 1;
            }
        }

        @cells = $prune_space_list_cr->(@cells);

        my $line = join( "\t", @cells );
        push @lines, $line;
    }

    return wantarray ? @lines : \@lines;

}

sub tsv {

    # tab-separated-values,
    # suitable for something like File::Slurper::write_text

    # converts line feeds, tabs, and carriage returns to the Replacement
    # Character.

    my ( $class, $self ) = &$invocant_cr;

    my $lines_r = $class->tsv_lines( $self, @_ );

    my $carped;
    foreach my $line (@$lines_r) {
        my $substitutions = $line =~ s/\n/\x{FFFD}/g;
        if ( $substitutions and not $carped ) {
            carp 'Line feed character found assembling tab-separated values. '
              . 'Replaced with REPLACEMENT CHARACTER';
            $carped = 1;
        }
    }
    return join( "\n", @$lines_r ) . "\n";

}

=item B<< file(...) >>

Accepts a file specification and creates a new file at that  location
containing the data in the 2D array.

This method uses named parameters.

=over

=item type

This parameter is the file's type. Currently, the types recognized are
'tsv' for tab-separated values, and 'xlsx' for Excel XLSX. If the type
is not given, it attempts to determine the type from the file
extension, which can be (case-insensitively) 'xlsx' for Excel XLSX
files  or 'tab', 'tsv' or 'txt' for tab-separated value files.

(If other text file formats are someday added, either they will have
to have different extensions, or an explicit type must be passed
to force that type to have a ".txt" extension.

=item output_file

This mandatory parameter contains the file specification.

=item headers

This parameter is optional. If present, it contains an array reference
to be used as the first row in the ouptut file.

The idea is that these will be the headers of the columns. It's not
really any different than putting the column headers as the first
element of the data, but frequently these are stored separately.

=back

=cut

sub file {
    my ( $class, $self ) = &$invocant_cr;

    my %params = validate(
        @_,
        {   headers     => { type => ARRAYREF, optional => 1 },
            output_file => 1,
            type        => 0,
        },
    );
    my $output_file = $params{output_file};
    my $type = $params{type} || $filetype_from_ext_r->($output_file);

    croak "Cannot determine type of $output_file in " . __PACKAGE__ . '->file'
      unless $type;

    if ( $type eq 'xlsx' ) {
        $class->xlsx( $self, \%params );
        return;
    }
    if ( $type eq 'tsv' ) {
        my $text = $class->tsv($self);

        if ( $params{headers} ) {
            $text = join( "\t", @{ $params{headers} } ) . "\n" . $text;
        }

        require File::Slurper;
        File::Slurper::write_text( $output_file, $text );
        return;
    }
    croak "Unrecognized type $type in " . __PACKAGE__ . '->file';
}

=item B<< xlsx(...) >>

Accepts a file specification and creates a new Excel XLSX file at that 
location, with one sheet, containing the data in the 2D array.

This method uses named parameters.

=over

=item output_file

This mandatory parameter contains the file specification.

=item headers

This parameter is optional. If present, it contains an array reference
to be used as the first row in the Excel file.

The idea is that these will be the headers of the columns. It's not
really any different than putting the column headers as the first
element of the data, but frequently these are stored separately. At
this point no attempt is made to make them bold or anything like that.

=item format

This parameter is optional. If present, it contains a hash reference,
with format parameters as specified by Excel::Writer::XLSX.

=back

=cut

sub xlsx {
    my ( $class, $self ) = &$invocant_cr;
    my %params = validate(
        @_,
        {   headers     => { type => ARRAYREF, optional => 1 },
            format      => { type => HASHREF,  optional => 1 },
            output_file => 1,
        },
    );

    my $output_file       = $params{output_file};
    my $format_properties = $params{format};
    my @headers;
    if ( $params{headers} ) {
        @headers = @{ $params{headers} };
    }

    require Excel::Writer::XLSX;    ### DEP ###

    my $workbook = Excel::Writer::XLSX->new($output_file);
    ## no critic (Variables::ProhibitPunctuationVars]
    croak "Can't open $output_file for writing: $!"
      unless defined $workbook;
    ## use critic
    my $sheet = $workbook->add_worksheet();
    my @format;

    if ( defined $format_properties ) {
        push @format, $workbook->add_format(%$format_properties);
    }

    # an array @format is used because if it were a scalar, it would be undef,
    # where what we want if it is empty is no value at all

    my $unblessed = blessed $self ? $self->unblessed : $self;

    # Excel::Writer::XLSX checks 'ref' and not 'reftype'

    if (@headers) {
        $sheet->write_row( 0, 0, \@headers, @format );
        $sheet->write_col( 1, 0, $unblessed, @format );
    }
    else {
        $sheet->write_col( 0, 0, $unblessed, @format );
    }

    return $workbook->close();

}

1;

__END__

=back

=head1 DIAGNOSTICS

=head2 ERRORS

=over

=item Arguments to Array::2D->new or Array::2D->blessed must be unblessed arrayrefs (rows)

A non-arrayref, or blessed object (other than an Array::2D object), was 
passed to the new constructor.

=item Sheet $sheet_requested not found in $xlsx in Array::2D->new_from_xlsx

Spreadsheet::ParseExcel returned an error indicating that the sheet
requested was not found.

=item File type unrecognized in $filename passed to Array::2D->new_from_file

A file other than an Excel (XLSX) or tab-delimited text files (with
tab,  tsv, or txt extensions) are recognized in ->new_from_file.

=item No file specified in Array::2D->new_from_file

=item No file specified in Array::2D->new_from_xlsx

No filename, or a blank filename, was passed to these methods.

=item No array passed to ...

A method was called that requires an array, but there was no array 
passed in the argument list. Typically this would be when it was called
as a class object, e.g., $class->set_row(qw/a b c/);

=back

=head2 WARNINGS

=over

=item Tab character found converting to tab-separated values. Replaced with REPLACEMENT CHARACTER

=item Line feed character found assembling tab-separated values.  Replaced with REPLACEMENT CHARACTER

An invalid character for TSV data was found in the array when creating 
TSV data. It was replaced with the Unicode REPLACEMENT CHARACTER (U+FFFD).

=back

=head1 TO DO

This is just a list of things that would be nice -- there's no current plan
to implement these.

=over

=item *

splice_row() and splice_col()

=item *

Alternatives to the methods that result in padded rather than pruned data.

=item *

CSV, JSON, maybe other file types in C<new_from_file()> and C<file()>.

=back

=head1 SEE ALSO

Some other modules that have some similarities include:

=over

=item L<Data::CTable|Data::CTable>

=item L<Data::Table|Data::Table>

=item L<PDL|PDL>

=item L<Text::Table|Text::Table>

=back

These all appear much more powerful than Array::2D and may better suit your use.

Another relevant module is L<Data::ShowTable|Data::ShowTable>, 
which creates output formats such as ASCII art boxes and HTML.

=head1 DEPENDENCIES

=over

=item Perl 5.10 or higher

=item List::MoreUtils, 0.28 or higher

=item Params::Validate

=item File::Slurper

=item Spreadsheet::ParseXLSX

=item Excel::Writer::XLSX

The last three are required only by those methods that use them 
(C<new_from_tsv()>, C<new_from_xlsx()>, and C<xlsx()> respectively).

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2015-2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
