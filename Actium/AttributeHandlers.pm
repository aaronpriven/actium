# Actium/AttributeHandlers.pm
# Attribute handlers for Moose classes in Actium

# Subversion: $Id$

use warnings;
use strict;

package Actium::AttributeHandlers;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;

use Exporter qw( import );
our @EXPORT_OK
  = qw(arrayhandles stringhandles numhandles boolhandles counterhandles);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use Actium::Constants;

#use Data::Dumper;
#print Dumper(arrayhandles('thing') , stringhandles('thing');

### PRIVATE HELPER ROUTINES FOR ATTRIBUTE HANDLERS

sub _op_name {
    my @pairs;
    foreach (@_) {
        push @pairs, "${_}_%", $_;
    }
    return @pairs;
}

sub _name_op {
    my @pairs;
    foreach (@_) {
        push @pairs, "%_$_", $_;
    }
    return @pairs;
}

sub _op_to_name {
    my @pairs;
    foreach (@_) {
        push @pairs, "${_}_to_%", $_;
    }
    return @pairs;
}

sub _array_pl_ro {
    return (
        _op_name(qw<grep map>),
        _name_op('natatime'),
        q{%}            => 'elements',
        '%_joinedwith' => 'join',
        '%_reducedwith' => 'reduce',
        'sorted_%'     => 'sort',
        'shuffled_%'   => 'shuffle',
        'unique_%'     => 'uniq',
        '%_are_empty'  => 'is_empty',
    );

}

sub _array_sing_ro {
    return (
        'first_%_where' => 'first',
        _name_op('count'),
        q{%} => 'get',
    );
}

sub _array_pl_rw {
    return ( _op_name(qw<pop push shift unshift splice clear insert >),
        'sort_%' => 'sort_in_place', );
}

sub _array_sing_rw {
    return _op_name(qw<delete set insert>),;
}

sub _str {
    return (
        _op_to_name(qw<append prepend length>),
        _op_name(qw<inc chop chomp replace match clear substr>),
    );
}

sub _num {
    return (
        _op_name(qw<set abs>),
        _op_to_name(qw<add>),
        'subtract_from_%' => 'sub',
        'multiply_by_%'   => 'mul',
        'divide_by_%'     => 'div',
        '%_modulo'        => 'mod',
    );
}

sub _bool {
    return ( _op_name(qw<set unset toggle not>) );
}

sub _counter {
    return ( _op_name(qw<set inc dec reset>) );
}

sub _privacy {
    my @names = @_;
    my $private;

    if ( substr( $names[0], 0, 1 ) eq '_' ) {
        $private = $TRUE;
        substr( $_, 0, 1, $EMPTY_STR ) foreach @names;
    }

    return $private, @names;

}

sub _restore_privacy {

    my ( $private, %handles ) = @_;

    return %handles unless $private;

    my %newhandles;

    foreach ( keys %handles ) {
        $newhandles{ '_' . $_ } = $handles{$_};
    }

    return %newhandles;
}

sub _replace_attr {
    my $attr = shift;
    my @pairs = @_;
    s/%/$attr/sg foreach @pairs;
    return @pairs;
}

sub _singularplural {
    my $singular = shift;
    my $plural = shift || ("${singular}s");
    return ( $singular, $plural );
}
### ATTRIBUTE HANDLERS

sub arrayhandles_ro {

    my ( $privacy, @names ) = _privacy(@_);

    my ( $singular, $plural ) = _singularplural(@_);

    my %handles = (
        _replace_attr( $plural,   _array_pl_ro() ),
        _replace_attr( $singular, _array_sing_ro() ),
    );

    return _restore_privacy( $privacy, %handles );

}

sub arrayhandles {
    my ( $privacy, @names ) = _privacy(@_);

    my ( $singular, $plural ) = _singularplural(@names);

    #my %handles = (
    #    _replace_attr( $plural,   _array_pl_ro() ),
    #    _replace_attr( $singular, _array_sing_ro() ),
    #    _replace_attr( $plural,   _array_pl_rw() ),
    #    _replace_attr( $singular, _array_sing_rw() ),
    #);

    my %a = _replace_attr( $plural,   _array_pl_ro() );
    my %b = _replace_attr( $singular, _array_sing_ro() );
    my %c = _replace_attr( $plural,   _array_pl_rw() );
    my %d = _replace_attr( $singular, _array_sing_rw() );

    my %handles = ( %a, %b, %c, %d );

    return _restore_privacy( $privacy, %handles );

} ## <perltidy> end sub arrayhandles

sub _handles {

    my ( $privacy, $name ) = _privacy( shift @_ );
    my %handles = _replace_attr( $name, @_ );
    return _restore_privacy( $privacy, %handles );
}

sub stringhandles {
    return _handles( shift, _str() );
}

sub numhandles {
    return _handles( shift, _num() );
}

sub boolhandles {
    return _handles( shift, _bool() );
}

sub counterhandles {
    return _handles( shift, _counter() );
}

#sub hashhandles {

# For now, I can't decide what the appropriate language would be. PBP
# recommends a hash be named %thing_of so you can write $thing_of{other_thing}.
# But I'm not sure how that would work.

# if exists_thing_of{other_thing}
# if there_is_a_thing_of{other_thing}
# or
# if thing_of_is_defined{other_thing}
# if definition_exists_of_thing_of{other_thing}
# ...

# I'm tempted just to make everything be _op_name, but I don't really
# think that's actually right.

#}

1;

__END__

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.001

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.


=head1 OPTIONS

A complete list of every available command-line option with which
the application can be invoked, explaining what each does and listing
any restrictions or interactions.

If the application has no options, this section may be omitted.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2009 

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
