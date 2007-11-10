#!/usr/bin/perl

# Actium::Object.pm
# Base class with get and set methods for Actium objects

#        1         2         3         4         5         6         7        
#23456789012345678901234567890123456789012345678901234567890123456789012345678

package Actium::Object;
use strict;
use Carp;
use Scalar::Util qw(blessed reftype refaddr);

#        1         2         3         4         5         6         7        
#23456789012345678901234567890123456789012345678901234567890123456789012345678

#my %method_of = {
#                  GET        => {
#						                  'verb' => 'get'                ,
#						                  '$'    => \&_get_scalar        ,
#						                  '@'    => \&_get_array         ,
#						                  '%'    => \&_get_hash          ,
#                  },
#					   SET        => {
#						                  'verb' => 'set'                ,
#						                  '$'    => \&_set_scalar        ,
#						                  '@'    => \&_set_array         ,
#						                  '%'    => \&_set_hash          ,
#					   },
#					   GETELEMENT => {
#						                  'verb' => 'get an element of ' ,
#						                  '@'    => \&_get_array_element ,
#						                  '%'    => \&_get_hash_element  ,
#					   },
#					   SETELEMENT => {
#						                  'verb' => 'set an element of ' ,
#						                  '@'    => \&_set_array_element ,
#						                  '%'    => \&_set_hash_element  ,
#					   },
#
#};

my %verb_of = {
                 GET        => 'get',
                 SET        => 'set',
                 GETELEMENT => 'get an element of',
                 SETELEMENT => 'set an element of',
              };
 

my %method_of = { 
                 '$' => { 
                         GET        => \&_get_scalar ,
                         SET        => \&_set_scalar ,
                        },
                 '@' => { 
                         GET        => \&_get_array ,
                         SET        => \&_set_array ,
                         GETELEMENT => \&_get_array_element ,
                         SETELEMENT => \&_set_array_element ,
                        },
                 '%' => { 
                         GET        => \&_get_hash ,
                         SET        => \&_set_hash ,
                         GETELEMENT => \&_get_hash_element ,
                         SETELEMENT => \&_set_hash_element ,
                        },
                 };
                 

# Translate standard code abbreviations (e.g., '$' for a scalar)
# into code references

sub get {
   standard_method(@_,'GET');
}

sub set {
   standard_method(@_,'SET');
}

sub get_element {
   standard_method(@_,'GETELEMENT');
}

sub set_element {
   standard_method(@_,'SETELEMENT');
}

sub get_el {
   standard_method(@_,'GETELEMENT');
}

sub set_el {
   standard_method(@_,'SETELEMENT');
}


sub standard_method {

   # This is called by the set(), get(), set_element(), etc. methods,
   # and decides based on the field definitions
   
   my $called_method = pop @_; # added by "get" or "set" routines
   my ($self, $field, @args) = @_;
   
   my $class = blessed($self)
               or croak "$self is not an object";
   
   # If $self is reference to a scalar, then that scalar contains 
   # a reference to the hashref that is the struct. If it's a reference 
   # to a hash, it is itself a reference to the struct.
   my $struct = (reftype($self) eq 'SCALAR') ? ${$self} : $self;
   
	# reference to the field definitions in the appropriate class.  If
	# the value is a hash ref, then each standard method (GET, SET,
	# SETELEMENT, etc.) has its own definition in the hash. If not, then
	# it uses the standard definitions for that type.  A definition can
	# be a string, in which case it is a key in %method_of, or a code
	# reference.
   my $field_ref = $self->fields(); 
   
   croak "No field $field in $class object" 
      if not exists ($field_ref->{$field});

   my $method_for_this_field;   
   if reftype($field_ref->{$field}) eq 'HASH' {
      $method_for_this_field = $field_ref->{$field}{$called_method};
   }
   else {
      $method_for_this_field = $field_ref->{$field};
   }

   croak 
      "Can't $method_of{$called_method}{verb} field $field in $class object "
      . "($called_method method not defined)"
      if not (defined $method_for_this_field) or ($method_for_this_field eq "!");

   if ( reftype($method_for_this_field) eq 'CODE') {
      &{$method_for_this_field}($struct,$field,@args);
   }
   else {
      &{$method_of{$method_for_this_field}{$called_method}}($struct,$field,@args);
   }

}

# Note that the various submethods (_get_scalar, etc.) do NOT necessarily know
# which class they are called in! They only know what data they hold. $struct
# is not necessarily an object, just a hash ref. But it can be.

sub _get_scalar {
   my ($struct, $field) = @_;
   return scalar $struct->{$field};
}

sub _get_array {
   my ($struct, $field) = @_;
   return @{$struct->{$field}};
}

sub _get_array_element {
   my ($struct, $field, $element) = @_;
   return scalar ${$struct->{$field}}[$element];
}

sub _get_hash {
   my ($struct, $field) = @_;
   return %{$struct->{$field}};
}

sub _get_hash_element {
   my ($struct, $field, $element) = @_;
   return scalar ${$struct->{$field}}{$element};
}

sub _set_scalar {
# sets the value of the scalar in $field. Returns previous value.
   my ($struct, $field, $value) = @_;
   my $former_value = $struct->{$field};
   $struct->{$field} = $value;
   return scalar $former_value;
}

sub _set_array {
   my($struct, $field, @values) = @_;
   my @former_values = @{$struct->{$field}};
   @{$struct->{$field}} = @values;
   return @former_values;
}

sub _set_array_element {
   my ($struct, $field, $element, $value) = @_;
   my $former_value = $struct->{$field}[$element];
   $struct->{$field}[$element] = $value;
   return scalar $former_value;
}

sub _set_hash {
   my($struct, $field, @values) = @_;
   my %former_values = %{$struct->{$field}};
   %{$struct->{$field}} = @values;
   return %former_values;
}

sub _set_hash_element {
   my ($struct, $field, $element, $value) = @_;
   my $former_value = $struct->{$field}{$element};
   $struct->{$field}{$element} = $value;
   return scalar $former_value;
}

1;