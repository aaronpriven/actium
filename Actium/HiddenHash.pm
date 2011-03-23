#!/ActivePerl/bin/perl

#/Actium/HiddenHash.pm

# Subversion: $Id$

use warnings;
use strict;

package Actium::HiddenHash;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Scalar::Util(qw/refaddr reftype/);
use Carp;

my %hr_of;

sub new {
    my $class = shift;
    my $self = bless \do { my $scalar }, $class; ## no critic (ProhibitUnusedVariables)
    if ( @_ == 1 and reftype( $_[0] ) eq 'HASH' ) {
        $hr_of{ refaddr $self} = shift;
    }
    else {
        $hr_of{ refaddr $self} = {};
    }

    $self->set(@_) if @_;
    return $self;
}

sub get {
    my $self = shift;
    my $id   = refaddr $self;
    my @keys = @_;
    return wantarray ? @{ $hr_of{$id} }{@keys} : $hr_of{$id}{ $keys[0] };
}

sub set {  ## no critic (ProhibitAmbiguousNames)
    my $self = shift;
    my @kvs  = @_;
    my $id   = refaddr $self;

    while (@kvs) {
        my $key   = shift;
        my $value = shift;
        $hr_of{$id}{$key} = $value;
    }

    return;
}

sub hr {
    my $self = shift;
    my $id   = refaddr $self;
    return $hr_of{$id};
}

sub set_hr {
    my $self = shift;
    my $id   = refaddr $self;
    my $hr = shift;
    croak "Can't set a hidden hash to something other than a hash reference"
       unless reftype($hr) eq 'HASH';
    $hr_of{$id} = $hr;
    return;
}

sub delete { ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;
    my @keys = @_;
    delete $hr_of{ refaddr $self }{$_} foreach @keys;
    return;
}

sub exists { ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;
    my $key = shift; 
    return exists $hr_of{ refaddr $self }{$key} ;
}

sub DESTROY {
    my $self = shift;
    delete $hr_of{ refaddr $self };
    return;
}

1;

__END__


=head1 NAME

Actium::HiddenHash - Simple inside-out class embodying a hash

=head1 VERSION

This documentation refers to Actium::HiddenHash version 0.001

=head1 SYNOPSIS

 use Actium::HiddenHash;
 my $hh = Actium::HiddenHash->new(a => 1, b => 2);
 my $value = $hh->get('a') ; # $value = 1
 $hh->set(b => 3, c => 5); # overrides old b and adds c
 $hh->delete('a'); # deletes 'a'

=head1 DESCRIPTION

HiddenHash is a simple inside-out class implementing a hash. This is, for almost all 
purposes, a complete waste. Why use a fancy class when you can use standard
perl hash syntax?

=over

I<Deep in the fundamental heart of mind and Universe, there is a reason.>

=over

-- Slartibartfast

=back

=back

I use Eclipse with EPIC as my development environment. When debugging the program,
at each breakpoint (or line, if it's stepping through line-by-line) Eclipse will go
through all the variables in the current lexical scope, and display them in the Variables
window. This is exceptionally useful. Unless you have a huge gigantic hash with lots
and lots of data, in which case EPIC can take forever to follow all the references...
and possibly run out of memory and crash.  Bad, bad.

So making an inside-out class seemed like the obvious way of hiding the data from
Eclipse while still making it available to the program.

=head1 METHODS

=over

=item B<new>(I<hashref>)

=item B<new>(I<key, value, ...>)

Creates a new Actium::HiddenHash object. 

If it is passed a single parameter, and that parameter is a hash reference, 
will store that hash reference as the hidden hash, without creating a new hash reference.  
Otherwise it will create a new, empty hash reference, and store any passed parameters 
as keys and values in it. Returns an anonymous scalar reference.

=item B<set>(I<key, value ...>)

Stores the passed keys and values in the hash.

=item B<get>(I<key, ...>)

Returns the values from the specified keys. 
(In scalar context, returns the value from the first passed key.)

=item B<delete>(I<key, ...>)

Deletes the entries for the specified keys.

=item B<exists>(I<key>)

Returns whether the element specified by key in the hash has ever been initialized.
(A simple wrapper of the perl function I<exists>.)

=item B<hr>()

Returns the hash reference for this object. This provides a way of using ordinary hash 
functions on the object, e.g.,

 my @keys = keys %{$hh->hr()};
 
=item B<set_hr>(I<hashref>)

Replaces the hashref for this object with the hashref specified.
 
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
