# Actium/O/2DArray.pm

# Convenience object for 2D array methods

# Subversion: $Id$

use 5.020;
use warnings;

package Actium::O::2DArray 0.008;

use Actium::Preamble;
use Actium::Util ('u_columns');

# this is a deliberately non-encapsulated object that is just
# an array of arrays (AoA).
# The object can be treated as an ordinary array of arrays,
# or have methods invoked on it

####################
### Construction

sub new {

    my $class = shift;
    my $self;

    my @rows = @_;

    if ( @rows == 0 ) {    # if no arguments, new anonymous AoA
        $self = [ [] ];
    }
    elsif ( any { reftype($_) ne 'ARRAY' } @rows ) {
        croak 'Arguments to ' . __PACKAGE__ . '->new must be arrayrefs (rows)';
    }
    else {
        $self = [@rows];
    }

    CORE::bless $self, $class;
    return $self;

}

sub bless {
    my $class = shift;
    my $self  = shift;

    my $selfclass = blessed($self);
    return $self if $selfclass eq $class;

    croak 'Cannot re-bless existing object' if ( defined $selfclass );

    CORE::bless $self, $class;
    return $self;
}

sub clone {
    my $self = shift;
    my $new = [ map { [ @{$_} ] } @{$self} ];
    CORE::bless $new, ( blessed $self );
    return $new;
}

sub clone_unblessed {
    my $self = shift;
    my $new = [ map { [ @{$_} ] } @{$self} ];
    return $new;
}

sub new_from_tsv {
    my $class = shift;
    my $self = [ map { [ split(/\t/) ] } @_ ];

    CORE::bless $self, $class;
    return $self;
}

##################################################
### find the last index, or the number of elements
### (like scalar @array or $#array for 1D arrays)

sub height {
    my $self = shift;
    return scalar @{$self};
}

sub width {
    my $self = shift;
    return max( map { scalar @{$_} } @{$self} );
}

sub last_row {
    my $self = shift;
    return $#{$self};
}

sub last_col {
    my $self = shift;
    return max( map { $#{$_} } @{$self} );
}

#########################################
### Accessors for elements, rows and columns

sub element {
    my $self   = shift;
    my $colidx = shift;
    my $rowidx = shift;
    return $self->[$rowidx][$colidx];
}

sub row {
    my $self = shift;
    my $rowidx = shift || 0;
    return @{ $self->[$rowidx] };
}

sub col {
    my $self = shift;
    my $colidx = shift || 0;
    return map { $_->[$colidx] } @{$self};
}

sub rows {
    my $self     = shift;
    my $class    = blessed $self;
    my @returned = map { $self->[$_] } @_;
    return $class->bless( \@returned );
}

sub cols {
    my $self     = shift;
    my $class    = blessed $self;
    my @returned = map { [ $self->col($_) ] } @_;
    return $class->bless( \@returned );
}

##############################
### push, pop, shift, unshift

sub shift_row {
    my $self = shift;
    return shift @{$self};
}

sub shift_col {
    my $self = shift;
    return map { shift @{$_} } @{$self};
}

sub pop_row {
    my $self = shift;
    return pop @{$self};
}

sub pop_col {
    my $self     = shift;
    my $last_col = $self->last_col;
    return $self->del_col($last_col);
}

sub push_row {
    my $self       = shift;
    my @col_values = @_;
    return push @{$self}, \@col_values;
}

sub push_col {
    my $self       = shift;
    my @col_values = @_;
    my $col_idx    = $self->last_col;
    return $self->ins_col( $col_idx, @col_values );
}

sub push_rows {
    my $self = shift;
    my @cols = @_;
    return push @{$self}, @cols;
}

sub push_cols {
    my $self    = shift;
    my @cols    = @_;
    my $col_idx = $self->last_col;
    return $self->ins_cols( $col_idx, @cols );
}

sub unshift_row {
    my $self       = shift;
    my @col_values = @_;
    return unshift @{$self}, \@col_values;
}

sub unshift_col {
    my $self       = shift;
    my @col_values = @_;
    return $self->ins_col( 0, @col_values );
}

sub unshift_rows {
    my $self = shift;
    my @cols = @_;
    return unshift @{$self}, @cols;
}

sub unshift_cols {
    my $self = shift;
    my @cols = @_;
    return $self->ins_cols( 0, @cols );
}

#################################
### insert rows or columns by index

sub ins_row {
    my $self    = shift;
    my $row_idx = shift;
    my @row     = @_;

    splice( @{$self}, $row_idx, 0, \@row );
    return scalar @{$self};
}

sub ins_col {
    my $self    = shift;
    my $col_idx = shift;
    my @col     = @_;

    my $last_row = max( $self->last_row, $#col );

    for my $row_idx ( 0 .. $last_row ) {
        splice( @{ $self->[$row_idx] }, $col_idx, 0, $col[$row_idx] );
    }

    return $self->width;
}

sub ins_rows {
    my $self    = shift;
    my $row_idx = shift;
    my @rows    = @{ +shift };

    splice( @{$self}, $row_idx, 0, @rows );
    return scalar @{$self};
}

sub ins_cols {
    my $self    = shift;
    my $col_idx = shift;
    my @cols    = @{ +shift };

    my $last_row = max( $self->last_row, map { $#{$_} } @cols );

    for my $row_idx ( 0 .. $last_row ) {
        for my $col (@cols) {
            splice( @{ $self->[$row_idx] }, $col_idx, 0, $col->[$row_idx] );
        }
    }
    return $self->width;
}

#################################
### delete rows or columns by index

sub del_row {
    my $self    = shift;
    my $row_idx = shift;

    my $deleted;
    if ( defined wantarray ) {
        $deleted = $self->row($row_idx);
    }

    splice( @{$self}, $row_idx, 1 );

    return $deleted if defined wantarray;
    return;
}

sub del_col {
    my $self    = shift;
    my $col_idx = @_;

    my $deleted;
    if ( defined wantarray ) {
        $deleted = $self->col($col_idx);
    }

    foreach my $row ( @{$self} ) {
        splice( @{$row}, $col_idx, 1 );
    }

    return $deleted if defined wantarray;
    return;
}

sub del_rows {
    my $self     = shift;
    my @row_idxs = @_;

    my $deleted;
    if ( defined wantarray ) {
        $deleted = $self->rows(@row_idxs);
    }

    foreach my $row_idx (@row_idxs) {
        splice( @{$self}, $row_idx, 1 );
    }

    return $deleted if defined wantarray;
    return;
}

sub del_cols {
    my $self     = shift;
    my @col_idxs = @_;

    my $deleted;
    if ( defined wantarray ) {
        $deleted = $self->cols(@col_idxs);
    }

    foreach my $col_idx (@_) {
        foreach my $row ( @{$self} ) {
            splice( @{$row}, $col_idx, 1 );
        }
    }

    return $deleted if defined wantarray;
    return;
}

##################################################
### Mutators. Modify object in void context; returns new object otherwise

sub slice {
    my $self = shift;
    my ( $firstcol, $lastcol, $firstrow, $lastrow ) = @_;

    state $methodname = __PACKAGE__ . '->slice';

    croak "Arguments to $methodname must not be negative"
      if any { $_ < 0 } ( $firstcol, $lastcol, $firstrow, $lastrow );

    ( $firstrow, $lastrow ) = ( $lastrow, $firstrow )
      if $firstrow > $lastrow;

    ( $firstcol, $lastcol ) = ( $lastcol, $firstcol )
      if $firstcol > $lastcol;

    my $self_lastcol = $self->lastcol;
    my $self_lastrow = $#{$self};

    $lastcol = min( $lastcol, $self_lastcol );
    $lastrow = min( $lastrow, $self_lastrow );

    my $new =
      $self->col( $firstcol .. $lastcol )->rows( $firstrow .. $lastrow );

    if ( defined wantarray ) {
        return $new;
    }

    @{$self} = @{$new};

}

sub transpose {

    my $self = shift;
    my $new  = [];

    foreach my $col ( 0 .. $self->last_col ) {
        push @{$new}, [ map { $_->[$col] } @{$self} ];
    }

    # non-void context: return new object
    if ( defined wantarray ) {
        CORE::bless $new, ( blessed $self );
        return $new;
    }

    # void context: alter existing object
    @{$self} = @{$new};
    return;

}

sub prune {
    my $self = shift;
    my $callback = sub { !defined $_ };
    return $self->prune_callback( $callback );
}

sub prune_empty {
    my $self = shift;
    my $callback = sub { !defined $_ or $_ eq $EMPTY_STR };
    return $self->prune_callback( $callback );
}

sub prune_callback {
    my $orig     = shift;
    my $callback = shift;
    my $self;

    if ( defined wantarray ) {
        $self = $orig->clone($self);
    }
    else {
        $self = $orig;
    }

    # remove final blank rows
    while ( @{$self} and all { $callback->() } $self->[-1] ) {
        pop @{$self};
    }

    # if it's all blank, make it an empty AoA and return it
    unless ( @{$self} ) {
        @{$self} = ( [] );
        return $self;
    }

    # remove final blank columns

    # does not use the last_col method because that method calls this one
    my $last_col = max( map { $#{$_} } @{$self} );

    while ( $last_col > -1 and all { $callback->() } $self->col($last_col) ) {
        $last_col--;

        # set index of the last item of each row to the new $last_col
        $#{$_} = $last_col for @{$self};

    }

    return $self;

}

sub apply {
    my $orig     = shift;
    my $callback = shift;
    my $self;

    if ( defined wantarray ) {
        $self = $orig->clone($self);
    }
    else {
        $self = $orig;
    }

    for my $row ( @{$self} ) {
        for my $idx ( 0 .. $#{$row} ) {
            for ($row->[$idx] ) {  
                # localize $_ to $row->[$idx]. Autovivifies.
                $callback->();
            }
        }
    }
    return $self;
}

sub trim {
    my $self = shift;

    my $callback = sub {
        my $str = shift;
        $str =~ s/\A\s+//;
        $str =~ s/\s+\z//;
        return $str;
    };

    return $self->apply($callback);
}

sub trim_right {
    my $self = shift;

    my $callback = sub {
        my $str = shift;
        $str =~ s/\s+\z//;
        return $str;
    };

    return $self->apply($callback);
}

sub undef2empty {
    my $self = shift;

    my $callback = sub {
        my $str = shift;
        $str //= $EMPTY_STR;
        return $str;
    };

    return $self->apply($callback);
}

#################################################
### Transforming the object into something else

sub hash_of_rows {
    my $self = shift;
    my $col  = shift;

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

sub hash_of_row_elements {
    my $self = shift;

    my ( $keycol, $valuecol );
    if (@_) {
        $keycol = shift;
        $valuecol = shift // ( $keycol == 0 ? 1 : 0 );

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

sub tabulate {

    my $self = undef2empty(shift);
    
    my $separator = shift // $SPACE;

    my @length_of_col;

    foreach my $row ( @{$self} ) {

        my @fields = @{$row};
        for my $this_col ( 0 .. $#fields ) {
            my $thislength = u_columns( $fields[$this_col] ) // 0;
            if ( not $length_of_col[$this_col] ) {
                $length_of_col[$this_col] = $thislength;
            }
            else {
                $length_of_col[$this_col] =
                  max( $length_of_col[$this_col], $thislength );
            }
        }
    }

    my @lines;

    foreach my $record_r ( @{$self} ) {
        my @fields = @{$record_r};

        for my $this_col ( 0 .. $#fields - 1 ) {
            $fields[$this_col] = sprintf( '%-*s',
                $length_of_col[$this_col],
                ( $fields[$this_col] // $EMPTY_STR ) );
        }
        push @lines, join( $separator, @fields );

    }

    return \@lines;

}    ## tidy end: sub tabulate

sub tsv {

    # tab-separated-values,
    # suitable for something like File::Slurp::write_file

    # converts line feeds, tabs, and carriage returns to the Unicode
    # visible symbols for these characters. Which is probably wrong, but
    # why would you feed those in then...

    my $self = undef2empty(shift);

    my @headers = flatten(@_);

    my @lines;
    push @lines, jt(@headers) if @headers;

    foreach my $row ( @{$self} ) {
        my @rowcopy = @{$row};
        foreach ( @rowcopy ) {
            $_ //= $EMPTY_STR;
            s/\t/\x{2409}/g;    # visible symbol for tab
        }
        push @lines, jt( @rowcopy );
    }

    foreach (@lines) {
        s/\n/\x{240A}/g;        # visible symbol for line feed
        s/\r/\x{240D}/g;        # visible symbol for carriage return
    }

    my $str = jn(@lines) . "\n";

    return $str;

}

1;

### old code to be deleted

################
### Prune blank rows/columns at the end

#sub prune {
#
#    my $orig = shift;
#    my $self;
#
#    if (defined wantarray) {
#        $self = $orig->clone($self);
#    }
#
#    # remove final blank rows
#    while ( @{$self} and all { not defined $_ } $self->[-1] ) {
#        pop @{$self};
#    }
#
#    # if it's all blank, make it an empty AoA and return it
#    unless ( @{$self} ) {
#        @{$self} = ( [] );
#        return $self;
#    }
#
#    # remove final blank columns
#
#    # does not use the last_col method because that method calls this one
#    my $last_col = max( map { $#{$_} } @{$self} );
#
#    while ( $last_col > -1 and all { not defined $_ } $self->col($last_col) ) {
#        $last_col--;
#
#        # set index of the last item of each row to the new $last_col
#        $#{$_} = $last_col for @{$self};
#
#    }
#
#    return $self;
#
#}
#
#sub prune_empty {
#
#    # like prune, only treats the empty string as a blank
#
#    my $self = shift;
#
#    # remove final blank rows
#    while ( @{$self}
#        and all { not defined $_ or $_ eq $EMPTY_STR } $self->[-1] )
#    {
#        pop @{$self};
#    }
#
#    # if it's all blank, make it an empty AoA and return it
#    unless ( @{$self} ) {
#        @{$self} = ( [] );
#        return $self;
#    }
#
#    # remove final blank columns
#
#    my $last_col = max( map { $#{$_} } @{$self} );
#
#    # does not use the last_col method because that method calls this one
#
#    while ( $last_col > -1
#        and all { not defined $_ or $_ eq $EMPTY_STR } $self->col($last_col) )
#    {
#        $last_col--;
#
#        # set index of the last item of each row to the new $last_col
#        $#{$_} = $last_col for @{$self};
#
#    }
#
#    return $self;
#
#}

__END__

=encoding utf8

=head1 NAME

Actium::O::2DArray - Simple 2D array objects

=head1 VERSION

This documentation refers to version 0.008

=head1 SYNOPSIS

 use Actium::O::2DArray;
 
 my $array2d = Actium::O::2DArray->new( [ qw/a b c/ ] , [ qw/w x y/ ] );

 # $array2d contains
 
 #     a  b  c
 #     w  x  y
 
 $array2d->push_col (qw/d z/);

 #     a  b  c  d
 #     w  x  y  z
 
 say $array2d->[0][1];
 # prints "b"
 
=head1 DESCRIPTION

Actium::O::2DArray is a module that adds useful methods to Perl's standard
array of arrays ("AoA") data structure, as described in 
L<Perl's perldsc page|perldsc>. That is, an array that contains other arrays:

 [ [ 1, 2, 3 ] , [ 4, 5, 6 ] ]

Most of the time, it's good practice to avoid having programs that use a module
know about the internal construction of a module. However, this module is not
like that. It exists purely to give methods to a standard construction in Perl,
and will never change the data structure to include anything else. Therefore,
it is perfectly reasonable to use the normal reference syntax to access
items inside the array. A construction like C<< $array2d->[0][1] >> 
for accessing a single element, or C<< @{$array2d} >> to get the list of
rows, is perfectly acceptable. This module exists because the reference-based 
implementation of multidimensional arrays in Perl makes it difficult to access,
for example, a single column, or a two-dimensional slice.

Actium::O::2DArray uses "row" for the first dimension, and "column" or "col" 
for the second dimension.

Because this object is just an array of arrays, most of the methods referring 
to rows are here mainly for completeness, and aren't really more useful than
the native Perl construction (e.g., C<< $array2d->last_row() >> 
is just a slower way of doing C<< $#{$array2d} >>.) 

On the other hand, most of the methods referring to columns are useful, since
there's no simple way of doing that in Perl. 
Notably, the column methods are careful, when a row doesn't have an entry, to
to fill out the column with undefined values. In other words, if there are five 
rows in the object, a requested column will always return five values,
although some of them might be undefined.

=head1 METHODS

Some general notes:

=over 

=item *

In all cases where an array of arrays is specified (I<$aoa_ref>), this can be
either an Actium::O::2DArray object or an array of arrays data structure 
that is not an object.

=item *

Where rows are columns are removed from the object (as with any of the 
C<pop_*>, C<shift_*>, C<del_*> methods), time-consuming assemblage of return
values is ommitted in void context.

=back

=head2 CLASS METHODS

=over

=item B<new( I<$row_ref>, I<$row_ref>...)>

Returns a new Actium::O::2DArray object.  It accepts a list of array 
references as arguments, which become the rows of the object.

=item B<bless(I<$aoa_ref>)>

Takes an existing non-object array of arrays and returns an 
Actium::O::2DArray object. Returns the new object. 

Note that this blesses the original array, so any other references to this 
data structures will become a reference to the object, too.

=back

=head2 OBJECT METHODS

=over

=item B<clone(I<$array2d>)>

Returns new object which has copies of the data in the 2D array object.
The 2D array will be different, but if any of the elements of the 2D array are 
themselves references, they will refer to the same things as in the original
2D array.

=item B<clone_unblessed(I<$array2d>)>

Returns a new, unblessed, array of arrays containing copies of the data in the
2D array object.  This is usually pointless, as Perl lets you ignore the 
object-ness of any object and access the data inside, but sometimes certain
modules don't like to break object encapsulation, and this will allow getting
around that.

=item B<new_from_tsv(I<$tsv_string>, I<$tsv_string> ...)>

Returns a new object from a list of strings containing tab-delimited values. 
There will be one row per string, and the elements of each row will be the
values delimited by tabs.

=item B<height()>

Returns the number of rows in the object.  Here for completeness, as 
C<@{$object}> works just as well.

=item B<width()>

Returns the number of columns in the object. (The number of elements in the
longest row.)

=item B<last_row()>

Returns the index of the last row of the object. Like C<height()>, this is here 
mainly for completeness, as C<$#{$object}> works just as well.

=item B<last_col()>

Returns the index of the last column of the object. (The index of the last
element in the longest row.)

=item B<element(I<$row_idx, $col_idx>)>

Returns the element in the given row and column. Just a slower way of saying
C<< $array2d->[$row_idx][$col_idx] >>.

=item B<row(I<$row_idx>)>

Returns the elements in the given row.  A slower way of saying 
C<< @{$array2d->[$row_idx]} >>.

=item B<col(I<$col_idx>)>

Returns the elements in the given column.

=item B<< rows(I<$row_idx>, I<$row_idx>...) >>

Returns a new Actium::O::2DArray object with all the columns of the 
specified rows.

=item B<cols(I<$col_idx>, I<$col_idx>...)>

Returns a new Actium::O::2DArray object with all the 
rows of the specified columns.

=item B<shift_row()>

Removes the first row of the object and returns a list 
of the elements of that row.

=item B<shift_col()>

Removes the first column of the object and returns a list 
of the elements of that column.

=item B<pop_row()>

Removes the last row of the object and returns
a list of the elements of that row.

=item B<pop_col()>

Removes the last column of the object and returns 
a list of the elements of that column.

=item B<push_row(I<@elements>)>

Adds the specified elements as the new final row. Returns the new 
number of rows.

=item B<push_col(I<@elements>)>

Adds the specified elements as the new final column. Returns the new 
number of columns.

=item B<push_rows(I<$aoa_ref>)>

Takes the specified array of arrays and adds them as new rows
after the end of the existing rows. Returns the new number of rows.

=item B<push_cols(I<$aoa_ref>)>

Takes the specified array of arrays and adds them as new columns,
after the end of the existing columns. Returns the new number of columns.

=item B<unshift_row(I<@elements>)>

Adds the specified elements as the new first row. Returns the new 
number of rows.

=item B<unshift_col(I<@elements>)>

Adds the specified elements as the new first column. Returns the new 
number of columns.

=item B<unshift_rows(I<$aoa_ref>)>

Takes the specified array of arrays and adds them as new rows
before the beginning of the existing rows. Returns the new number of rows.

=item B<unshift_cols(I<$aoa_ref>)>

Takes the specified array of arrays and adds them as new columns,
before the beginning of the existing columns. Returns the new number of columns.

=item B<ins_row(I<row_idx>, I<@elements>)>

Adds the specified elements as a new row at the given index.
Returns the new number of rows.

=item B<ins_col(I<col_idx>, <@elements>)>

Adds the specified elements as a new column at the given index.
Returns the new number of columns.

=item B<ins_rows(I<row_idx>, I<@aoa_ref>)>

Takes the specified array of arrays and inserts them as new rows at the
given index. 
Returns the new number of rows.

=item B<ins_cols(I<col_idx>, <@elements>)>

Takes the specified array of arrays and inserts them as new columns at the
given index. 
Returns the new number of columns.

=item B<del_row(I<row_idx>)>

Removes the row of the object specified by the index and returns a list of
the elements of that row.

=item B<del_col(I<col_idx>)>

Removes the column of the object specified by the index and returns a list of
the elements of that column.

=item B<del_rows(I<row_idx>, I<row_idx>...)>

Removes the rows of the object specified by the indices.
Returns an Actium::O::2DArray object of those rows.

=item B<del_cols(I<col_idx>, I<col_idx>...)>

Removes the columns of the object specified by the indices.
Returns an Actium::O::2DArray object of those columns.

=item B<slice(I<$firstcol>, I<lastcol>, I<$firstrow>, I<lastrow>)>

Takes a two-dimensional slice of the object; like cutting a rectangle out of
the object. 

In void context, alters the original object, which then will 
contain only the area specified; otherwise, creates a new Actium::O::2DArray 
object and returns the object.

=item B<transpose()>

Transposes the object: the elements that used to be in rows are now in columns,
and vice versa.

In void context, alters the original object.
Otherwise, creates a new Actium::O::2DArray object and returns the object.

=item B<prune()>

Occasionally an array of arrays can end up with rows or columns that are
entirely undefined. For example:

 my $obj = Actium::O::2DArray->new ( [ qw/a b c/]  , [ qw/f g h/ ]);
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
  
That would yield an object with four columns, but last column (with index 3)
consisted of only undefined values.

The C<prune> method eliminates these entirely undefined or empty columns 
and rows at the end of the object.

In void context, alters the original object.
Otherwise, creates a new Actium::O::2DArray object and returns the object.

=item B<prune_blank()>

Like C<prune>, but treats not only undefined values as blank, but also 
empty strings.

In void context, alters the original object.
Otherwise, creates a new Actium::O::2DArray object and returns the object.

=item B<prune_callback(I<$code_ref>)>

Like C<prune>, but calls the C<$code_ref> for each element, setting $_ to 
each element. If the callback code returns true, the value is considered
blank.

For example, this would prune values that were undefined, 
the empty string, or zero:

 my $callback = sub { 
     my $val = shift;
     ! defined $val or $val eq $EMPTY_STR  or $val == 0;
 }
 $obj->prune_callback($callback);

In void context, alters the original object.
Otherwise, creates a new Actium::O::2DArray object and returns the object.

=item B<apply(I<$coderef>)>

Calls the C<$code_ref> for each element, aliasing $_ to each element in turn.
This allows an operation to be performed on every element.

For example, this would lowercase every element in the array (assuming all
values are defined):

 $obj->apply(sub {lc});

In void context, alters the original object.
Otherwise, creates a new Actium::O::2DArray object and returns the object.

=item B<trim()>

Removes white space, if present, from the beginning and end 
of each element in the array.

In void context, alters the original object.
Otherwise, creates a new Actium::O::2DArray object and returns the object.

=item B<trim_right()>

Removes white space from the end of each element in the array.

In void context, alters the original object.
Otherwise, creates a new Actium::O::2DArray object and returns the object.

=item B<undef2empty()>

Replaces undefined values with the empty string.

In void context, alters the original object.
Otherwise, creates a new Actium::O::2DArray object and returns the object.

=item B<hash_of_rows(I<$col_idx>)>

Creates a hash reference. 
The keys are the values in the specified column of the array.
The values are arrayrefs containing the elements of the rows of the array,
with the value in the key column removed.  

If the key column is not specified,
the first column is used for the keys.

So:

 $obj = Actium::O::2DArray->new([qw/a 1 2/],[qw/b 3 4/]);
 $hashref = $obj->hash_of_rows(0);
 # $hashref = { a => [ '1' , '2' ]  , b => [ '3' , '4' ] }

=item B<hash_of_row_elements(I<$key_column_idx>, I<$value_column_idx>)>

Like C<hash_of_rows>, but accepts a key column and a value column,
and the values are not whole rows but only single elements.

So:

 $obj = Actium::O::2DArray->new([qw/a 1 2/],[qw/b 3 4/]);
 $hashref = $obj->hash_of_row_elements(0, 1);
 # $hashref = { a => '1' , b => '3' }
 
If neither key column nor value column are specified, column 0
will be used for the key and the column 1 will be used for the value. 

If the key column is specified but the value column is not, then the first
column that is not the key column will be used as the value column. (In other
words, if the key column is column 0, then column 1 will be used as the value;
otherwise column 0 will be used as the value.)

=item B<tabulate(I<$separator>)>

Returns an arrayref of strings, where each string consists of the elements of each
row, padded with enough spaces to ensure that each column is the same width.

The columns will be separated by whatever string is passed to C<tabulate()>. 
If nothing is passed, a single space will be used.

So, for example,

 $obj = Actium::O::2DArray->new([qw/a bbb cc/],[qw/dddd e f/]);
 $arrayref = $obj->tabulate();
 
 # $arrayref = [ 'a    bbb cc' ,
                 'dddd e   f'] ;
                 
The width of each element is determined using the 
C<Unicode::GCString->columns()> method, so it will treat composed accented
characters and double-width Asian characters correctly.

=item B<tsv()>

Returns a single string with the elements of each row delimited by tabs, 
and rows delimited by line feeds.

If tabs, carriage returns, or line feeds are present in any element, they
will be replaced by the Unicode visible symbols for tabs (U+2409), line
feeds (U+240A), or carriage returns (U+240A).

=back

=head1 DIAGNOSTICS

=over

=item Arguments to Actium::O::2DArray->new must be arrayrefs (rows)

=item Cannot re-bless existing object

An object of another class was passed to the bless() method. Only pass
unblessed (non-object) data structures to bless().

=item Arguments to Actium::O::2DArray->slice must not be negative

A negative row or column index was 

=head1 DEPENDENCIES

None, other than those required by other Actium modules.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2015

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








