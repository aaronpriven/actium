package Actium::Util 0.012;

# Cannot use Actium.pm since that module uses this one

use 5.022;
use warnings;

use List::Util (qw[first max min sum]);    ### DEP ###
use List::MoreUtils(qw[any all none notall natatime uniq]);    ### DEP ###
use Scalar::Util(qw[blessed reftype looks_like_number]);       ### DEP ###
use Ref::Util (qw/is_plain_hashref is_plain_arrayref/);        ### DEP ###
use Carp;                                                      ### DEP ###
use File::Spec;                                                ### DEP ###
use Const::Fast;                                               ### DEP ###
use Kavorka ( fun => { -as => 'func' } );                      ### DEP ###

use English '-no_match_vars';

## no critic (ProhibitConstantPragma)
use constant DEBUG => 1;
## use critic

const my $KEY_SEPARATOR => "\c]";
# duplicated from Actium...

use Sub::Exporter -setup => {
    exports => [
        qw<
          positional
          joinseries          joinseries_with
          j
          joinempty           jointab
          joinkey             joinlf
          define              isempty
          filename            file_ext
          add_before_extension
          display_percent
          is_odd              is_even
          mean                population_stdev
          all_eq
          in                  folded_in
          feq                 fne
          halves
          flatten             hashref
          dumpstr
          u_wrap              u_columns
          u_trim_to_columns   u_pad
          immut
          >
    ]
};
# Sub::Exporter ### DEP ###

## no critic (RequirePodAtEnd)

=encoding utf-8

=head1 NAME

Actium::Util - Utility functions for the Actium system

=head1 VERSION

This documentation refers to Actium::Util version 0.012

=head1 SYNOPSIS

 @list = ('Thing One' , 'Thing Two' , 'Red Fish');
 use Actium::Util ':all';
 
 $smashed = joinempty(@list); # 'Thing OneThing TwoRed Fish'
 say jointab(@list);          # "Thing One\tThing Two\tRed Fish"
 $key = joinkey(@list);       # "Thing One\c]Thing Two\c]Red Fish"
                      
 $string = undef;
 $string = define($string); # now contains empty string
 
=head1 DESCRIPTION

This module contains some simple routines for use in other modules.

=head1 SUBROUTINES

=head2 JOINING

=over

=item joinempty

=item j (deprecated synonym)

Takes the list passed to it and joins it together as a simple string. 
A quicker way to type "join ('' , @list)".

=cut

sub j {
    carp 'Call to "Actium::Util::j" remains' if DEBUG;
    goto &joinempty;
}

sub joinempty {
    return join( q[], map { $_ // q[] } @_ );
}

=item joinkey

Takes the list passed to it and joins it together, with each element
separated  by the $KEY_SEPARATOR value from L<Actium/Actium>. A quicker
way to type "join ($KEY_SEPARATOR , @list)".

=cut

sub joinkey {
    return join( $KEY_SEPARATOR, map { $_ // q[] } @_ );
}

=item joinlf

Takes the list passed to it and joins it together, with each element
separated  by a line feed. A quicker way to type 'join ("\n" , @list)'.

=cut 

sub joinlf {
    return join( "\n", map { $_ // q[] } @_ );
}

=item jointab

Takes the list passed to it and joins it together, with each element
separated  by tabs. A quicker way to type 'join ("\t" , @list)'.

=cut

sub jointab {
    return join( "\t", map { $_ // q[] } @_ );
}

=item joinseries_with (I<conjunction> , I<item>, I<item>, ...)

This routine is designed to display a list as it should appear in
English.

   Sally and Carlos
   Fred, Sally and Carlos
   Mei, Fred, Sally and Carlos

The first argument is the conjunction, used to connect the penultimate
and last items in the list. The remaining arguments are the members of
the list.

   joinseries_with('or' , qw(Sasha Aisha Raj)); 
   # 'Sasha, Aisha or Raj'

The routine intentionally follows Associated Press style and  omits the
serial comma.

=cut

func joinseries_with (Str $and!, Str @things!) {
    return $things[0] if @things == 1;
    return "$things[0] $and $things[1]" if @things == 2;
    my $final = pop @things;
    return ( join( q{, }, @things ) . " $and $final" );
}

=item joinseries (I<list>)

The same as C< joinseries_with('and', ...)>;

=cut

sub joinseries {
    croak 'No argumments passed to ' . __PACKAGE__ . '::joinseries'
      unless @_;
    return joinseries_with( 'and', @_ );
}

=back

=head2 DEFINEDNESS, EMPTINESS

=over

=item define

For each value passed to it, returns either  that value, if defined, or
the empty string, if not.

=cut

sub define {
    if (wantarray) {
        my @list = @_;
        $_ = $_ // q[] foreach @list;
        return @list;
    }
    else {
        local $_ = shift;
        $_ = $_ // q[];
        return $_;
    }
}

=item isempty

Returns a boolean value: false if the first argument is defined and not
an  empty string, or true if it is either undefined or the empty
string.

=cut

sub isempty {
    my $value = shift;
    return ( not( defined $value and $value ne q[] ) );
}

=back

=head2 STRING EQUALITY

=over

=item in

Returns a boolean value: true if the first argument is equal to  (using
the C<eq> operator) any of the subsequent arguments,  or if the second
argument is a plain arrayref,  any of the elements of that array.

=cut

sub in {

    # is-an-element-of (stringwise)

    my $item = shift;
    if ( is_plain_arrayref( $_[0] ) ) {
        return any { $item eq $_ } @{ $_[0] };
    }

    return any { $item eq $_ } @_;

}

=item folded_in

Like C<in>, but folding the case of the arguments (using C<fc>)  before
making the comparison.

=cut

sub folded_in {

    my $item = fc(shift);
    if ( is_plain_arrayref( $_[0] ) ) {
        return any { $item eq fc($_) } @{ $_[0] };
    }
    return any { $item eq fc($_) } @_;
}

=item all_eq

Returns a boolean value: true if the first value is equal to all the
subsequent values (using C<eq>), false otherwise.

=cut

sub all_eq {
    my $first = shift;
    my @rest  = @_;
    return all { $_ eq $first } @rest;
}

=item feq

Returns a boolean value:  true if, when case-folded (using C<fc>),  the
first argument is equal to its second; otherwise false.

=cut

sub feq {
    my ( $x, $y ) = @_;
    return fc($x) eq fc($y);
}

=item fne

Returns a boolean value:  true if, when case-folded (using C<fc>),  the
first argument is not equal to its second; otherwise false.


=cut

sub fne {
    my ( $x, $y ) = @_;
    return fc($x) ne fc($y);
}

=back

=head2 MATHEMATICS

=over

=item is_odd

Returns true if the first argument is odd (not divisible by two), false
if it is not.

=cut

sub is_odd {
    return $_[0] % 2;
}

=item is_even

Returns true if the first argument is even (divisible by two), false if
it is not.

=cut

sub is_even {
    return not( $_[0] % 2 );
}

=item mean

The arithmetic mean of its arguments.

=cut

sub mean {

    if ( is_plain_arrayref( $_[0] ) ) {
        return sum( @{ $_[0] } ) / scalar( @{ $_[0] } );
    }

    return sum(@_) / scalar(@_);
}

=item population_stdev

The population standard deviation of its arguments, or if the first 
argument is an array ref, of the members of that array.

=cut

sub population_stdev {

    my @popul = is_plain_arrayref( $_[0] ) ? @{ $_[0] } : @_;

    my $themean = mean(@popul);
    return sqrt( mean( [ map { $_**2 } @popul ] ) - ( $themean**2 ) );
}

=item halves( I<wholes> , I<halves> )

This takes two values, "wholes" and "halves", and returns the number of
halves (that is, it multiples wholes by two, and adds the results to
halves, and returns that).

=cut

sub halves {
    my ( $wholes, $halves ) = ( flatten(@_) );
    return ( $wholes * 2 + $halves );
}

=back

=head2 ARRAY AND HASH REFERENCES

=over

=item hashref

Returns its argument if there is only one argument and it is a plain
hashref. Otherwise creates a hash from its arguments. Useful in
accepting either a hashref or a plain hash as arguments to a function.

=cut

sub hashref {
    return $_[0] if is_plain_hashref( $_[0] ) and @_ == 1;
    croak 'Odd number of elements passed to ' . __PACKAGE__ . '::hashref'
      if @_ % 2;
    return {@_};
}

=item flatten

Takes a list and flattens any (unblessed) array references in it, 
ensuring that the contents of any lists of lists are returned as
individual items.

So

 @list =  ( 'A' , [ 'B1' , 'B2', [ 'B3A' , 'B3B' ], ] ) ; 

 $array_ref = flatten(@list);
 @flatarray = flatten(@list);
 # $list_ref = [ 'A', 'B1', 'B2', 'B3A', 'B3B' ]
 # @flatarray = ('A', 'B1', 'B2', 'B3A', 'B3B') 

Returns its result as an array reference in scalar context, but as a
list in list context.

=cut 

sub flatten {

    my @results;

    while (@_) {
        my $element = shift @_;
        if ( is_plain_arrayref($element) ) {
            unshift @_, @{$element};
        }
        else {
            push @results, $element;
        }
    }

    return wantarray ? @results : \@results;

}

=item dumpstr

This returns a string --  a dump from the Data::Printer module of the
passed  data structure, suitable for displaying and debugging.

=cut

sub dumpstr (\[@$%&];%) {    ## no critic (ProhibitSubroutinePrototypes)
                              # prototype copied from Data::Printer::np
    require Data::Printer;    ### DEP ###
    return Data::Printer::np(
        @_,
        hash_separator => ' => ',
        class => { expand => 'all', parents => 0, show_methods => 'none', }
    );
}

=back

=head2 UNICODE COLUMNS

These utilities are used when displaying text in a monospaced typeface,
 to ensure that text with combining characters and wide characters are 
shown taking up the proper width.

=over

=item u_columns

This returns the number of columns in its first argument, as determined
by the L<Unicode::GCString|Unicode::GCString> module.

=cut

sub u_columns {
    my $str = shift;
    require Unicode::GCString;    ### DEP ###
    return Unicode::GCString->new("$str")->columns;
    # the quotes are necessary because GCString doesn't work properly
    # with variables Perl thinks are numbers. It doesn't automatically
    # stringify them.
}

=item u_pad

Pads a string with spaces to a number of columns. The first argument
should be the string, and the second the number of columns.

 $y = u_pad("x", 2);
 # returns  "x "
 $z = u_pad("柱", 4);
 # returns ("柱  ");

Uses u_columns internally to determine the width of the text.

=cut

sub u_pad {
    my $text  = shift;
    my $width = shift;

    my $textwidth = u_columns($text);

    return $text if $textwidth >= $width;

    my $spaces = ( q[ ] x ( $width - $textwidth ) );

    return ( $text . $spaces );

}

=item u_wrap (I<string>, I<min_columns>, I<max_columns>)

Takes a string and wraps it to a number of columns, producing  a series
of shorter lines, using the  L<Unicode::Linebreak|Unicode::LineBreak>
module. If the string has embedded newlines, these are taken as
separating paragraphs.

The first argument is the string to wrap.

The second argument, if present, is the minimum number of columns --
ColMin from Unicode::LineBreak. If not present, 0 will be used.

The third argment, if present, is the maximum number of columns --
ColMax from Unicode::LineBreak. If not present, 79 will be used.

=cut

const my $DEFAULT_LINE_LENGTH  => 79;
const my $DEFAULT_MINIMUM_LINE => 3;

sub u_wrap {
    my ( $msg, $min, $max ) = @_;

    return unless defined $msg;

    $min //= 0;
    $max ||= $DEFAULT_LINE_LENGTH;

    return $msg
      if $max < $DEFAULT_MINIMUM_LINE or $min > $max;

    require Unicode::LineBreak;    ### DEP ###

    state $breaker = Unicode::LineBreak::->new();
    $breaker->config( ColMax => $max, ColMin => $min );

    # First split on newlines
    my @lines = ();
    foreach my $line ( split( /\n/, $msg ) ) {

        my $linewidth = u_columns($line);

        if ( $linewidth <= $max ) {
            push @lines, $line;
        }
        else {
            push @lines, $breaker->break($line);
        }

    }
    foreach (@lines) {
        s/\s+\z//;
    }

    return wantarray ? @lines : joinlf(@lines);

} ## tidy end: sub u_wrap

=item u_trim_to_columns

Trims an input string to a particular number of columns.

 $x = u_trim_to_columns("Barney", 4);
 # returns "Barn"

=cut

sub u_trim_to_columns {
    my $text        = shift;
    my $max_columns = shift;

    require Unicode::GCString;    ### DEP ###

    my $gc = Unicode::GCString::->new($text);

    my $columns = $gc->columns;
    while ( $gc->columns > $max_columns ) {
        $gc->substr( -1, 1, q[] );
        $columns = $gc->columns;
    }

    return $gc->as_string if $columns == $max_columns;

    return u_pad( $gc->as_string, $max_columns );
    # in case we trimmed off a double-wide character or something,
    # pad it to the right number of columns

} ## tidy end: sub u_trim_to_columns

=item display_percent

Returns the first argument as a whole percentage:

=cut

sub display_percent {
    my $val   = shift;
    my $total = shift;
    ## no critic (ProhibitMagicNumbers)
    return sprintf( ' %.0f%%', $val / $total * 100 );
    ## use critic
}

=back

=head2 FILENAMES AND EXTENSIONS

=over

=item filename

Treats the first argument as a file specification and returns the 
filename portion (as determined by File::Spec->splitpath ).

=cut

sub filename {

    my $filespec = shift;
    my $filename;
    ( undef, undef, $filename ) = File::Spec->splitpath($filespec);
    return $filename;
}

=item file_ext

Treats the first argument as a file specification and returns two
strings: the filename without extension, and the extension.

=cut

sub file_ext {
    my $filespec = shift;                 # works on filespecs or filenames
    my $filename = filename($filespec);
    my ( $filepart, $ext )
      = $filename =~ m{(.*)    # as many characters as possible
                      [.]     # a dot
                      ([^.]+) # one or more non-dot characters
                      \z}sx;
    return ( $filepart, $ext );
}

=item add_before_extension

Treats the first argument as a file specification and adds the second
argument to it, prior to the extension, separated from it by a hyphen.
So:

 $file = add_before_extension("sam.txt", "fred");
 # $file is "sam-fred.txt"

=cut

sub add_before_extension {

    my $input_path = shift;
    my $addition   = shift;

    my ( $volume, $folders, $filename ) = File::Spec->splitpath($input_path);
    my ( $filepart, $ext ) = file_ext($filename);

    my $output_path
      = File::Spec->catpath( $volume, $folders, "$filepart-$addition.$ext" );

    return ($output_path);

}

=back

=head2 POSITIONAL OR NAMED ARGUMENTS

=over

=item positional(\@_ , I<arguments>)

The B<positional> routine allows the use of positional arguments in
addition to named arguments in method calls or Moose object
construction.

Typical use for positional would be as follows:

 sub a_method {
    my $self = shift;
    $arguments_r = positional(\@_, 'foo' , 'bar');
    
    ... # rest of your method
    
 }

 or

 around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    return $class->$orig->(positional(\@_ , 'foo' , 'bar' ));
 };
 
The first argument to I<positional> must always be  a reference to the
arguments passed to the original routine.  The remaining arguments are
the C<init_arg> values (usually, the same as the names) of attributes
to be passed to Moose.

When using these routines, the arguments to your method are  first, the
optional positional arguments that you specify, followed by  an
optional hashref of named arguments, which must be the last argument. 
If named arguments in the hashref  conflict with the positional
arguments, the positional arguments will be used.

For example, the following are all valid in the above 'around' 
example:

 Class->new('foo_value', 'bar_value'); 
    # both specified
 Class->new('foo_value'); 
    # just one specified
 Class->new({ foo => 'foo_value' , bar => 'bar_value'});  
    # named arguments used instead
 Class->new( 'foo_value' , 'bar_value' , { baz => 'baz_value'} );
    # positional arguments followed by named arguments
 Class->new( 'foo_value' , { bar => 'bar_value', baz => 'baz_value'} );
    # Mixing it up will work also
 Class->new( foo => 'foo_value', { foo => 'a_different_foo_value');
    # will use 'foo_value'

Note that if only named arguments are given, I<they must be given in a
hash reference>.

B<The following will not work:>

 Class->new( foo => 'foo_value');
    # will be taken as two positional arguments: foo => foo and 
    #    bar => 'foo_value'
 Class->new( foo => 'foo_value', bar => 'bar_value');
    # Will croak 'Too many positional arguments in object construction'
 Class->new( foo => 'foo_value', { foo => 'a_different_foo_value');
    # Will croak 'Conflicting values specified in object construction'

If the name of the last argument to C<positional>  begins with an at
sign (@), then the at sign will be removed, and an arrayref  pointing
to an array of the remaining arguments to your method will be returned
in that slot of the array.

For example, given the following:

 around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    return $class->$orig->(positional(\@_ , 'baz' , '@qux' ));
 };

The following would be valid:

 Class->new ('baz_value', 'qux_value_1', 'qux_value_2');
   #  would return 
   #     { baz => 'baz_value' , qux => [ 'qux_value_1' , 'qux_value_2' ] }

 Class->new ('baz_value', 'qux_value_1' , {xyzzy => 'xyzzy_value' } );
   #  would return 
   #  { baz => 'baz_value' , qux => [ 'qux_value_1' ] , xyzzy => 'xyzzy_value' }

 Class->new ('baz_value');
    # would return { baz => 'baz_value' }

 Class->new ('baz_value' , { qux => 'qux_value' } );
    # would return { baz => 'baz_value' , qux => 'qux_value' }
    
Note that no change is made to any named arguments.

=cut

#### ACCEPTING POSITIONAL OR NAMED ARGUMENTS

sub positional {

    my $argument_r = shift;
    my $qualsub    = __PACKAGE__ . '::positional';
    ## no critic (RequireInterpolationOfMetachars)
    croak 'First argument to ' . $qualsub . ' must be a reference to @_'
      if not( ref($argument_r) eq 'ARRAY' );
    ## use critic

    my @arguments = @{$argument_r};
    my @attrnames = @_;

    # if the last attribute begins with @, package up all remaining
    # positional arrguments into an arrayref and return that
    my $finalarray;
    if ( $attrnames[-1] =~ /\A @/sx ) {
        $finalarray = 1;
        $attrnames[-1] =~ s/\A @//sx;
    }

    for my $attrname (@attrnames) {
        next unless $attrname =~ /\A @/sx;
        croak "Attribute $attrname specified.\n"
          . "Only the last attribute specified in $qualsub in can be an array";
    }

    my %newargs;
    if ( defined reftype( $arguments[-1] )
        and reftype( $arguments[-1] ) eq 'HASH' )
    {
        %newargs = %{ pop @arguments };
    }
    if ( not $finalarray and scalar @attrnames < scalar @arguments ) {
        croak 'Too many positional arguments in object construction';
    }

    while (@arguments) {
        my $name = shift @attrnames;
        if ( not @attrnames and $finalarray ) {
            # if this is the last attribute name, and it originally had a @
            $newargs{$name} = [@arguments];
            @arguments = ();
        }
        else {
            $newargs{$name} = shift @arguments;
        }
    }

    #    foreach my $i ( 0 .. $#arguments ) {
    #        my $name  = $attrnames[$i];
    #        my $value = $arguments[$i];
    #        croak 'Conflicting values specified in object construction'
    #          . " for attribute $name:\n"
    #          . " (positional: [$value], by name: [$newargs{$name}]"
    #          if $newargs{$name} and $newargs{$name} ne $value;
    #        $newargs{$name} = $value;
    #    }

    return \%newargs;

} ## tidy end: sub positional

=back

=head2 MOOSE

=over

=item immut

The B<immut> routine is designed to be used in place of the rather
unwieldy

    __PACKAGE__->meta->make_immutable
    
The C<immut> routine simply performs this on the calling package,
making the Moose class immutable.

=back

=cut

sub immut {
    my $package = caller;
    $package->meta->make_immutable;
}

1;

__END__

=head1 DEPENDENCIES

=over

=item Perl 5.22

=item Sub::Exporter

=item Ref::Util

=item List::MoreUtils

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011-2017

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

=cut

