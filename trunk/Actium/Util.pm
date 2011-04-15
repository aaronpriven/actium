# Actium/Util.pm
# Utility routines

# Subversion: $Id$

use warnings;
use 5.012;

package Actium::Util 0.001;

use Actium::Constants;
use Perl6::Export::Attrs;
use List::Util;
use Carp;

#### MISC UTILITY ROUTINES

sub positional : Export {

    my $argument_r = shift;
    croak 'First argument to positional must be a reference to the BUILDARGS @_'
      if not( ref($argument_r) eq 'ARRAY' );

    my @arguments = @{$argument_r};
    my @attrnames = @_;
    
    my %newargs;
    if ( ref( $arguments[-1] ) eq 'HASH' ) {
        %newargs = %{ pop @arguments };
    }
    if ( scalar @attrnames < scalar @arguments ) {
        croak 'Too many positional arguments in object construction';
    }

    foreach my $i ( 0 .. $#arguments ) {
        my $name  = $attrnames[$i];
        my $value = $arguments[$i];
        croak 'Conflicting values specified in object construction'
          . " for attribute $name:\n"
          . " (positional: [$value], by name: [$newargs{$name}]"
          if $newargs{$name} and $newargs{$name} ne $value;
        $newargs{$name} = $value;
    }

    return \%newargs;

} ## tidy end: sub positional :

sub positional_around : Export {
    my $arguments_r = shift;
    my $orig = shift @{$arguments_r}; # see Moose::Manual::Construction
    my $invocant = shift @{$arguments_r}; # see Moose::Manual::Construction
    return $invocant->$orig(positional_method ($arguments_r , @_));
}

sub _joinseries_with_x {
    my $and = shift;
    my @things = @_;
    return $things[0] if @things == 1;
    return "$things[0] and $things[1]" if @things == 2;
    my $last = pop @things;
    return ( join( q{, }, @things ) . " $and $last" );
}

sub joinseries :Export {
    return _joinseries_with_x('and', @_);
}

sub joinseries_ampersand :Export {
    return _joinseries_with_x('&' , @_);
};

sub j : Export {
    return join( $EMPTY_STR, map { $_ // $EMPTY_STR } @_ );
}

sub jt : Export {
    return join( "\t", map { $_ // $EMPTY_STR } @_ );
}

sub jk : Export {
    return join( $KEY_SEPARATOR, map { $_ // $EMPTY_STR } @_ );
}

sub jn : Export {
    return join( "\n", map { $_ // $EMPTY_STR } @_ );
}

sub sk : Export {
    return split( /$KEY_SEPARATOR/, $_[0] );
}

sub st : Export {
    return split( /\t/, $_[0] );
}

sub keyreadable : Export {
    if (wantarray) {
        my @list = @_;
        s/$KEY_SEPARATOR/_/g foreach @list;
        return @list;
    }
    my $_ = shift;
    s/$KEY_SEPARATOR/_/g;
    return $_;
}

sub keyunreadable : Export {
    if (wantarray) {
        my @list = @_;
        s/_/$KEY_SEPARATOR/g foreach @list;
        return @list;
    }
    my $_ = shift;
    s/_/$KEY_SEPARATOR/g;
    return $_;
}

sub even_tab_columns : Export {
    my $list_r = shift;

    my @lengths;
    foreach my $line ( @{$list_r} ) {
        chomp $line;
        my @fields = split( /\t/, $line );
        for my $idx ( 0 .. $#fields ) {
            my $len = length( $fields[$idx] );
            if ( not $lengths[$idx] ) {
                $lengths[$idx] = $len;
            }
            else {
                $lengths[$idx] = List::Util::max( $lengths[$idx], $len );
            }
        }
    }

    my @returns;

    foreach my $line ( @{$list_r} ) {
        my @fields = split( "\t", $line );
        for my $idx ( 0 .. $#fields - 1 ) {
            $fields[$idx] = sprintf( '%-*s', $lengths[$idx], $fields[$idx] );
        }
        push @returns, join( " ", @fields );
    }

    return \@returns;

} ## tidy end: sub even_tab_columns :

sub doe : Export {
    my @list = @_;
    $_ = $_ // $EMPTY_STR foreach @list;
    return wantarray ? @list : $list[0];
}

1;

__END__


=head1 NAME

Actium::Util - Utility functions for the Actium system

=head1 VERSION

This documentation refers to Actium::Util version 0.001

=head1 SYNOPSIS

 @list = ('Thing One' , 'Thing Two' , 'Red Fish');
 use Actium::Util ':all';
 
 $smashed = j(@list); # 'Thing OneThing TwoRed Fish'
 say jt(@list);       # "Thing One\tThing Two\tRed Fish"
 $key = jk(@list);    # "Thing One\c]Thing Two\c]Red Fish"
 $readable_key = keyreadable($key); 
                      # 'Thing One_Thing Two_Red Fish'
                      
 $string = undef;
 $string = doe($string); # now contains empty string
 
=head1 DESCRIPTION

This module contains some simple routines for use in other modules.

=head1 SUBROUTINES

=over

=item B<doe()>

This stands for "defined-or-empty." For each value passed to it, returns either 
that value, if defined, or the empty string, if not.

=item B<j()>

Takes the list passed to it and joins it together as a simple string. 
A quicker way to type "join ('' , @list)".

=item B<jk()>

Takes the list passed to it and joins it together, with each element separated 
by the $KEY_SEPARATOR value from L<Actium::Constants>.
A quicker way to type "join ($KEY_SEPARATOR , @list)".

=item B<jt()>

Takes the list passed to it and joins it together, with each element separated 
by tabs. A quicker way to type 'join ("\t" , @list)'.

=item B<joinseries(I<list>)>

This routine takes the list passed to it and joins it together. It adds a comma
and a space between all the entries except the penultimate and last. Between
the penultimate and last, adds only the word "and" and a space.

For example

 joinseries(qw[Alice Bob Eve Mallory])
 
becomes

 "Alice, Bob, Eve and Mallory"

The routine intentionally follows Associated Press style and 
omits the serial comma.

=item B<joinseries_ampersand(I<list>)>

Just like I<joinseries>, but uses "&" instead of "and".

=item B<keyreadable()>

For each string passed to it, returns a string where the $KEY_SEPARATOR value from Actium::Constants is replaced by an underline (_), 
making it readable. (A quicker way to type "s/$KEY_SEPARATOR/_/g foreach @list;".)

=item B<positional(C<\@_> , I<arguments>)>

=item B<positional_around(C<\@_> , I<arguments>)>

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
an optional hashref of named arguments, which may be the same as the
positional arguments if they do not conflict.

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
 Class->new( foo => 'foo_value', { foo => 'foo_value'});
    # Will be OK, because the specified values are the same, although
    #  why you'd want to do this is unclear

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
    
=back

=head1 DEPENDENCIES

=over

=item Perl 5.12

=item Perl6::Export::Attrs

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011 

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
