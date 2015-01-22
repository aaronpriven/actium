# Actium/O/2DArray.pm

# Convenience object for 2D array methods

# Subversion: $Id$

use 5.020;
use warnings;

package Actium::O::2DArray 0.008;

use Actium::Preamble;
use Actium::Util ('u_columns');

# this is a deliberately non-encapsulated object that is just
# an array of arrays.  The object can be treated as an ordinary array of arrays,
# or have methods invoked on it

####################
### Construction

sub new {

    my $class = shift;
    my $self;

    if ( @_ == 0 ) {    # if no arguments, new anonymous AoA
        $self = [ [] ];
    }
    elsif ( @_ == 1 and reftype( $_[0] ) eq 'ARRAY' ) {

        # if one argument, and it's an array:
        $self = shift;
        if ( 0 == scalar @{$self} ) {

            # if it's empty, push an empty array on it, making it an empty AoA
            push @{$self}, [];
        }
        else {
            # if it's not empty and any of its members are not arrays,
            # it's the only row of an AoA
            if ( any { reftype($_) ne 'ARRAY' } @{$self} ) {
                $self = [$self];
            }
        }
    }
    else {
        # more than one argument: the rows of an AoA
        $self = [@_];
    }

    bless $self, $class;
    return $self;

}

sub clone {
    my $self = shift;
    my $new = [ map { [ @{$_} ] } @{$self} ];
    bless $new, ( ( blessed $self ) // __PACKAGE__ );
    return $new;
}

sub new_from_tsv {
    my $class = shift;
    my $self = [ map { [ split(/\t/) ] } @_ ];

    bless $self, $class;
    return $self;
}

##################
### Constructors or mutators

sub transpose {

    my $self = shift;
    $self->trim;
    my $new = [];

    foreach my $col ( 0 .. $self->last_col ) {
        push @{$new}, [ map { $_->[$col] } @{$self} ];
    }

    # non-void context: return new object
    if ( defined wantarray ) {
        bless $new, ( ( blessed $self ) // __PACKAGE__ );
        return $new;
    }

    # void context: alter existing object
    @{$self} = @{$new};
    return;

}

####################
### Simple accessors

sub row {
    my $self = shift;
    my $rowidx = shift || 0;
    return @{ $self->[$rowidx] };
}

sub column {
    my $self = shift;
    my $colidx = shift || 0;
    return map { $_->[$colidx] } @{$self};
}

sub height {
    my $self = shift;
    $self->trim;
    return scalar @{$self};
}

sub width {
    my $self = shift;
    $self->trim;
    return max( map { scalar @{$_} } @{$self} );
}

sub _last_row_untrimmed {
    my $self = shift;
    return $#{$self};
}

sub _last_col_untrimmed {
    my $self = shift;
    return max( map { $#{$_} } @{$self} );
}

sub last_row {
    my $self = shift;
    $self->trim;
    return $self->_last_row_untrimmed;
}

sub last_col {
    my $self = shift;
    $self->trim;
    return $self->_last_col_untrimmed;
}

################
### Trim

sub trim {

    my $self = shift;

    # remove final blank rows
    while ( @{$self}
        and all { not defined $_ or $_ eq $EMPTY_STR } $self->[-1] )
    {
        pop @{$self};
    }

    my $last_col = $self->_last_col_untrimmed;
    while ( $last_col > -1
        and all { not defined $_ or $_ eq $EMPTY_STR }
        $self->column($last_col) )
    {
        $self->_pop_column_last_is($last_col);
        $last_col--;
    }

    return $self;

}

##############################
### push, pop, shift, unshift

sub pop_column {
    my $self = shift;
    return $self->_pop_column_last_is( $self->last_col );
}

sub _pop_column_last_is {
    my $self    = shift;
    my $lastcol = shift;
    my @popped_column;

    for my $row ( @{$self} ) {
        if ( $#{$row} < $lastcol ) {
            push @popped_column, undef;
        }
        else {
            push @popped_column, pop @{$row};
        }
    }

    return @popped_column;

}

sub push_column {
    my $self = shift;

    return $self unless @_;

    my @column_values;
    if ( @_ == 1 and reftype( $_[0] ) eq 'ARRAY' ) {
        @column_values = @{ +shift };
    }
    else {
        @column_values = @_;
    }

    my $column_idx = $self->last_col + 1;

    for my $row_idx ( 0 .. $#column_values ) {
        $self->[$row_idx][$column_idx] = $column_values[$row_idx];
    }

    return $self;

}

###################
### Making hashes

sub hash_of_rows {
    my $self   = shift;
    my $column = shift;

    my %hash;

    if ($column) {
        for my $row_r ( @{$self} ) {
            my @row = @{$row_r};
            my $key = splice( @row, $column, 1 );
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
        $valuecol = shift || ( $keycol == 0 ? 1 : 0 );

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

##################
### Output

sub tabulate {

    my $self = shift;

    my @length_of_column;

    foreach my $row ( @{$self} ) {

        my @fields = @{$row};
        for my $this_column ( 0 .. $#fields ) {
            my $thislength = u_columns( $fields[$this_column] ) // 0;
            if ( not $length_of_column[$this_column] ) {
                $length_of_column[$this_column] = $thislength;
            }
            else {
                $length_of_column[$this_column] =
                  max( $length_of_column[$this_column], $thislength );
            }
        }
    }

    my @lines;

    foreach my $record_r ( @{$self} ) {
        my @fields = @{$record_r};

        for my $this_column ( 0 .. $#fields - 1 ) {
            $fields[$this_column] = sprintf( '%-*s',
                $length_of_column[$this_column],
                ( $fields[$this_column] // $EMPTY_STR ) );
        }
        push @lines, join( $SPACE, @fields );

    }

    return \@lines;

}    ## tidy end: sub tabulate

sub tsv {

    # tab-separated-values,
    # suitable for something like File::Slurp::write_file

    # converts line feeds, tabs, and carriage returns to the Unicode
    # visible symbols for these characters. Which is probably wrong, but
    # why would you feed those in then...

    my $self    = shift;
    my @headers = flatten(@_);

    my @lines;
    push @lines, jt(@headers) if @headers;

    foreach my $row ( @{$self} ) {
        foreach ( @{$row} ) {
            $_ //= $EMPTY_STR;
            s/\t/\x{2409}/g;    # visible symbol for tab
        }
        push @lines, jt( @{$row} );
    }

    foreach (@lines) {
        s/\n/\x{240A}/g;        # visible symbol for line feed
        s/\r/\x{240D}/g;        # visible symbol for carriage return
    }

    my $str = jn(@lines) . "\n";

    return $str;

}

1;
