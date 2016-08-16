package Actium::Util 0.012;

# Cannot use Actium::Preamble since that module uses this one

use 5.022;
use warnings;

use Actium::Constants;
use List::Util (qw[first max min sum]);    ### DEP ###
use List::MoreUtils(qw[any all none notall natatime uniq]);    ### DEP ###
use Scalar::Util(qw[blessed reftype looks_like_number]);       ### DEP ###
use Ref::Util ('is_plain_hashref');                            ### DEP ###
use Carp;                                                      ### DEP ###
use File::Spec;                                                ### DEP ###

use English '-no-match-vars';

use constant DEBUG => 1;

use Sub::Exporter -setup => {
    exports => [
        qw<
          positional          positional_around
          joinseries          joinseries_ampersand
          j
          joinempty          jointab
          joinkey            joinlf
          define
          isblank             isnotblank
          filename            file_ext
          remove_leading_path add_before_extension
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
          >
    ]
};
# Sub::Exporter ### DEP ###

=head1 NAME

Actium::Util - Utility functions for the Actium system

=head1 VERSION

This documentation refers to Actium::Util version 0.001

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

=head2 JOINING AND SPLITTING

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
    return join( $EMPTY_STR, map { $_ // $EMPTY_STR } @_ );
}

=item joinkey

Takes the list passed to it and joins it together, with each element separated 
by the $KEY_SEPARATOR value from L<Actium::Constants/Actium::Constants>.
A quicker way to type "join ($KEY_SEPARATOR , @list)".

=cut

sub joinkey {
    return join( $KEY_SEPARATOR, map { $_ // $EMPTY_STR } @_ );
}

=item joinlf

Takes the list passed to it and joins it together, with each element separated 
by a line feed. A quicker way to type 'join ("\n" , @list)'.

=cut 

sub joinlf {
    return join( "\n", map { $_ // $EMPTY_STR } @_ );
}

=item jointab

Takes the list passed to it and joins it together, with each element separated 
by tabs. A quicker way to type 'join ("\t" , @list)'.

=cut

sub jointab {
    return join( "\t", map { $_ // $EMPTY_STR } @_ );
}

=item joinseries

This routine takes the list passed to it and joins it together. It
adds a comma and a space between all the entries except the penultimate
and last. Between the penultimate and last, adds only the word "and"
and a space.

For example

 joinseries(qw[Alice Bob Eve Mallory])
 
becomes

 "Alice, Bob, Eve and Mallory"

The routine intentionally follows Associated Press style and 
omits the serial comma.

=cut

sub _joinseries_with_x {
    my $and    = shift;
    my @things = @_;
    return $things[0] if @things == 1;
    return "$things[0] $and $things[1]" if @things == 2;
    my $final = pop @things;
    return ( join( q{, }, @things ) . " $and $final" );
}

sub joinseries {
    croak 'No argumments passed to ' . __PACKAGE__ . '::joinseries'
      unless @_;
    return _joinseries_with_x( 'and', @_ );
}

=item joinseries_ampersand

Just like I<joinseries>, but uses "&" instead of "and".

=cut

sub joinseries_ampersand {
    croak 'No argumments passed to ' . __PACKAGE__ . '::joinseries_ampersand'
      unless @_;
    return _joinseries_with_x( '&', @_ );
}

=cut

=back

=head2 Unclassified as yet

=over

=item define

For each value passed to it, returns either 
that value, if defined, or the empty string, if not.

=cut

sub define {
    if (wantarray) {
        my @list = @_;
        $_ = $_ // $EMPTY_STR foreach @list;
        return @list;
    }
    else {
        local $_ = shift;
        $_ = $_ // $EMPTY_STR;
        return $_;
    }
}

=item isnotblank

...

=cut

sub isnotblank {
    my $value = shift;
    return ( defined $value and $value ne $EMPTY_STR );
}

=item isblank

...

=cut

sub isblank {
    my $value = shift;
    return ( not( defined $value and $value ne $EMPTY_STR ) );
}

=item filename

...

=cut

sub filename {

    my $filespec = shift;
    my $filename;
    ( undef, undef, $filename ) = File::Spec->splitpath($filespec);
    return $filename;
}

=item file_ext

...

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

...

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

=item remove_leading_path

...

=cut

sub remove_leading_path {
    my ( $filespec, $path ) = @_;

    ############################
    ## GET CANONICAL PATHS

    require Cwd;    ### DEP ###
    $path     = Cwd::abs_path($path);
    $filespec = Cwd::abs_path($filespec);

    ##############
    ## FOLD CASE

    # if a component of $filespec is the same except for upper/lowercase
    # from a component of $path, use the upper/lowercase of $path

    my ( $filevol, $filefolders_r, $file ) = _split_path_components($filespec);
    my ( $pathvol, $pathfolders_r, $pathfile )
      = _split_path_components( $path, 1 );

    $file    = $pathfile if ( lc($file) eq lc($pathfile) );
    $filevol = $pathvol  if ( lc($filevol) eq lc($pathvol) );

    # put each component into $case_of. But
    # if there is a conflict between folder names within $path --
    # e.g., $path is "/Whatever/whatever/WHatEVer" -- use
    # the first one

    my %case_of;
    foreach ( @{$pathfolders_r} ) {
        my $lower = lc($_);
        if ( exists( $case_of{$lower} ) ) {
            $_ = $case_of{$lower};
        }
        else {
            $case_of{$lower} = $_;
        }
    }

    foreach my $component ( @{$filefolders_r} ) {
        $component = $case_of{ lc($component) }
          if $case_of{ lc($component) };
    }

    $filespec = _join_path_components( $filevol, $filefolders_r, $file );
    $path     = _join_path_components( $pathvol, $pathfolders_r, $pathfile );

    ############################
    ## REMOVE THE LEADING PATH

    return File::Spec->abs2rel( $filespec, $path );
} ## tidy end: sub remove_leading_path

# _split_path_components and _join_path_components
# might be worth making public if they are used again.
# Originally written for the case-folding in remove_leading_path

sub _split_path_components {
    my $filespec = shift;
    my $nofile   = shift;
    my ( $volume, $folders, $file )
      = File::Spec->splitpath( $filespec, $nofile );
    my @folders = File::Spec->splitdir($folders);
    return $volume, \@folders, $file;
}

sub _join_path_components {
    my ( $vol, $folders_r, $file ) = @_;
    my $path
      = File::Spec->catpath( $vol, File::Spec->catdir( @{$folders_r} ), $file );
    return $path;
}

=item hashref

...

=cut

sub hashref {
    return $_[0] if is_plain_hashref( $_[0] ) and @_ == 1;
    croak 'Odd number of elements passed to ' . __PACKAGE__ . '::hashref'
      if @_ % 2;
    return {@_};
}

=item flatten

Takes a list and flattens any array references in it, 
ensuring that the contents of any lists of lists
are returned as individual items.

So

 @list =  ( 'A' , [ 'B1' , 'B2', [ 'B3A' , 'B3B' ], ] ) ; 

 $array_ref = flatten(@list);
 @flatarray = flatten(@list);
 # $list_ref = [ 'A', 'B1', 'B2', 'B3A', 'B3B' ]
 # @flatarray = ('A', 'B1', 'B2', 'B3A', 'B3B') 

Returns its result as an array reference in scalar context, but as a
list in list context.

=cut 

sub iterative_flatten {

    # needs testing before replacing 'flatten'

    my @results;

    while (@_) {
        my $element = shift @_;
        if ( Ref::Util::is_plain_arrayref($element) ) {
            unshift @_, @{$element};
        }
        else {
            push @results, $element;
        }
    }

    return wantarray ? @results : \@results;

    # other alternatives, which are untested

    #while ( any { reftype $_ eq 'ARRAY' } @array ) {
    #    @array = map { reftype $_ eq 'ARRAY' ? @{$_} : $_ } @array
    #}

    #my $continue = 1;
    #while ($continue) {
    #    @array = map {
    #        if ( reftype $_ eq 'ARRAY' ) {
    #            $continue = 0 unless any { reftype $_ eq 'ARRAY' } @{$_};
    #            @{$_};
    #        }
    #        else {
    #            $_;
    #        }
    #      } @array
    #}

} ## tidy end: sub iterative_flatten

sub flatten {

    my @inputs = @_;
    my @results;
    foreach my $input (@inputs) {
        if ( reftype($input) && reftype($input) eq 'ARRAY' ) {
            push @results, flatten( @{$input} );
        }
        else {
            push @results, $input;
        }
    }

    return wantarray ? @results : \@results;

}

# this should be moved to a more general
# "information from the filemaker database" section
# when LINES_TO_COMBINE gets moved there

=item folded_in

...

=cut

sub folded_in {

    my $item    = fc(shift);
    my $reftype = reftype( $_[0] );
    if ( defined $reftype and $reftype eq 'ARRAY' ) {
        return any { $item eq fc($_) } @{ $_[0] };
    }
    return any { $item eq fc($_) } @_;
}

=item in

...

=cut

sub in {

    # is-an-element-of (stringwise)

    my $item    = shift;
    my $reftype = reftype( $_[0] );
    if ( defined $reftype and $reftype eq 'ARRAY' ) {
        return any { $item eq $_ } @{ $_[0] };
    }

    return any { $item eq $_ } @_;

}

=item is_odd

...

=cut

sub is_odd {
    return $_[0] % 2;
}

=item is_even

...

=cut

sub is_even {
    return not( $_[0] % 2 );
}

=item mean

...

=cut

sub mean {

    if ( ref( $_[0] ) eq 'ARRAY' ) {
        return sum( @{ $_[0] } ) / scalar( @{ $_[0] } );
    }

    return sum(@_) / scalar(@_);
}

=item population_stdev

...

=cut

sub population_stdev {

    my @popul = ref $_[0] ? @{ $_[0] } : @_;

    my $themean = mean(@popul);
    return sqrt( mean( [ map $_**2, @popul ] ) - ( $themean**2 ) );
}

=item all_eq

...

=cut

sub all_eq {
    my $first = shift;
    my @rest  = @_;
    return all { $_ eq $first } @rest;
}

=item halves( I<wholes> , I<halves> )

This takes two values, "wholes" and "halves", and returns the number of halves
(that is, it multiples wholes by two, and adds the results to halves,
and returns that).

=cut

sub halves {
    my ( $wholes, $halves ) = ( flatten(@_) );
    return ( $wholes * 2 + $halves );
}

=item dumpstr

...

=cut

sub dumpstr (\[@$%&];%) {
    # prototype copied from Data::Printer::np
    require Data::Printer;    ### DEP ###
    return Data::Printer::np(
        @_,
        hash_separator => ' => ',
        class => { expand => 'all', parents => 0, show_methods => 'none', }
    );
}

=back

=head2 Unicode column untilities

=over

=item u_columns

...

=cut

##########################
## Unicode column utilities

sub u_columns {
    my $str = shift;
    require Unicode::GCString;    ### DEP ###
    return Unicode::GCString->new("$str")->columns;
    # the quotes are necessary because GCString doesn't work properly
    # with variables Perl thinks are numbers. It doesn't automatically
    # stringify them.
}

=item u_pad

...

=cut

sub u_pad {
    my $text  = shift;
    my $width = shift;

    my $textwidth = u_columns($text);

    return $text unless $textwidth < $width;

    my $spaces = ( $SPACE x ( $width - $textwidth ) );

    return ( $text . $spaces );

}

=item u_wrap

...

=cut

sub u_wrap {
    my ( $msg, $min, $max ) = @_;

    return unless defined $msg;

    $min //= 0;
    $max ||= 79;

    return $msg
      if $max < 3 or $min > $max;

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

...

=cut

sub u_trim_to_columns {
    my $text        = shift;
    my $num_columns = shift;

    require Unicode::GCString;    ### DEP ###

    my $gc = Unicode::GCString::->new($text);

    while ( $gc->columns > $num_columns ) {
        $gc->substr( -1, 1, $EMPTY_STR );
    }

    return $gc->as_string;

}

=item feq

...

=cut

sub feq {
    my ( $x, $y ) = @_;
    return fc($x) eq fc($y);
}

=item fne

...

=cut

sub fne {
    my ( $x, $y ) = @_;
    return fc($x) ne fc($y);
}

=item display_percent

...

=cut

sub display_percent {
    my $val   = shift;
    my $total = shift;
    return sprintf( ' %.0f%%', $val / $total * 100 );
}

=back

=head2 Positional or named arguments

=over

=item positional(\@_ , I<arguments>)

=item positional_around(\@_ , I<arguments>)

The B<positional> and B<positional_around> routines allow the use of positional
arguments in addition to named arguments in method calls or Moose object
construction.

The I<positional_around> routine is intended for use within a BUILDARGS block,
or another "around" method modifer in a
Moose class (see L<Moose::Manual::Construction|Moose::Manual::Construction>
and L<Moose::Manual::MethodModifiers|Moose::Manual::MethodModifiers>).

Typical use for positional would be as follows:

 sub a_method {
    my $self = shift;
    $arguments_r = positional(\@_, 'foo' , 'bar');
    
    ... # rest of your method
    
 }

Typical use for positional_around would be as follows: 

 around BUILDARGS => sub {
    return positional_around (\@_ , 'foo' , 'bar' );
 };
 
The first argument to I<positional> or I<positional_around> must always be 
a reference to the arguments passed to the original routine. 
The remaining arguments are the C<init_arg> values (usually, the same
as the names) of attributes to be passed to Moose. 

When using these routines, the arguments to your method are 
first, the optional positional arguments that you specify, followed by 
an optional hashref of named arguments, which must be the last argument. 
If named arguments in the hashref 
conflict with the positional arguments, the positional arguments will be used.

For example, the following are all valid in the above positional_around example:

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

Note that if only named arguments are given, I<they must be given in a hash
reference>. 

B<The following will not work:>

 Class->new( foo => 'foo_value');
    # will be taken as two positional arguments: foo => foo and 
    #    bar => 'foo_value'
 Class->new( foo => 'foo_value', bar => 'bar_value');
    # Will croak 'Too many positional arguments in object construction'
 Class->new( foo => 'foo_value', { foo => 'a_different_foo_value');
    # Will croak 'Conflicting values specified in object construction'

If the name of the last argument to C<positional> or C<positional_around>
begins with an at sign (@), then the at sign will be removed, and an arrayref 
pointing to an array of the remaining arguments to your method will be returned
in that slot of the array.

For example, given the following:

 around BUILDARGS => sub {
    return positional_around (\@_ , 'baz' , '@qux' );
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
    ## no critic (RequireInterpolationOfMetachars)
    my $qualsub = __PACKAGE__ . '::positional';
    ## use critic
    croak 'First argument to ' . $qualsub . ' must be a reference to @_'
      if not( ref($argument_r) eq 'ARRAY' );

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

sub positional_around {
    my $args_r   = shift;
    my $orig     = shift @{$args_r};    # see Moose::Manual::Construction
    my $invocant = shift @{$args_r};    # see Moose::Manual::Construction
    return $invocant->$orig( positional( $args_r, @_ ) );
}

=back

=head1 DEPENDENCIES

=over

=item Perl 5.22

=item Sub::Exporter

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011-2016

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

=cut

1;
