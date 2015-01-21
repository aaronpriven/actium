# Actium/O/2DArray.pm

# Convenience object for 2D array methods

# Subversion: $Id$

use 5.020;
use warnings;

package Actium::O::2DArray 0.003;

use Actium::Preamble;

# this is a deliberately non-encapsulated object that is just
# an array of arrays.  Can be treated as an ordinary array of arrays,
# or have useful methods invoked on it

sub new {

    my $class = shift;
    my $self;

    if ( @_ == 0 ) {
        $self = [ [] ];
    }
    elsif ( @_ == 1 and reftype( $_[0] ) eq 'ARRAY' ) {
        $self = shift;
    }
    else {
        $self = [@_];
    }

    bless $self, $class;
    return $self;

}

sub row_hash {
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

sub row_elem_hash {

    my $self = shift;

    my ( $keycol, $valuecol );
    if (@_) {
        $keycol   = shift;
        $valuecol = shift;
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

sub column {
    my $self = shift;
    my $colidx = shift || 0;
    
    my @column;
    
    for my $row_r ( @{$self} ) {
        push @column, $row_r->[$colidx];
    }

    return @column;

}

1;
