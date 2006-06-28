#!/usr/bin/perl

# Actium::Object.pm
# Base class with get and set methods for Actium objects

#        1         2         3         4         5         6         7        
#23456789012345678901234567890123456789012345678901234567890123456789012345678


=comment

These are get and set routines that were supposed to go in the class itself

sub get {
   my $self = shift;
   $$self = \$sked_of{ident($self)};
   standard_method($self, @_, 'GET');
   $$self = undef;
}   

sub set {
   my $self = shift;
   $$self = \$sked_of{ident($self)};
   standard_method($self, @_, 'SET');
   $$self = undef;
}   


=cut

package Actium::Object;
use strict;
use Carp;
use Scalar::Util qw(blessed reftype refaddr);

my %method_of = {
                  GET        => {
						                  'verb' => 'get' ,
						                  '$'    => \&_get_scalar,
						                  '@'    => \&_get_array,
						                  '%'    => \&_get_hash
                  },
					   SET        => {
						                  'verb' => 'set' ,
						                  '$'    => \&_set_scalar,
						                  '@'    => \&_set_array,
						                  '%'    => \&_set_hash,
					   },
					   GETELEMENT => {
						                  'verb' => 'get an element of ' ,
						                  '@'    => \&_get_array_element ,
						                  '%'    => \&_get_hash_element  ,
					   }
					   SETELEMENT => {
						                  'verb' => 'set an element of ' ,
						                  '@'    => \&_set_array_element ,
						                  '%'    => \&_set_hash_element  ,
					   };

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

sub standard_method {

   # This is called by the set(), get(), setelement(), etc. methods,
   # and decides based on the field definitions
   
   my $called_method = pop @_; # added by "get" or "set" routines
   my ($self, $field, @args) = @_;
   
   my $class = blessed($self)
               or croak "$self is not an object";
   
   # If $self is reference to a scalar, then it contains a reference to the 
   # hashref that is the struct. If it's a reference to a hash, it is itself
   # a reference to the struct. 
   my $struct = (reftype($self) eq 'SCALAR') ? $$self : $self;
   
   my $field_ref = $self->fields(); 
      # reference to the field definitions in the appropriate class
   
   croak "No field $field in $class object" 
      if not exists ($field_ref->{$field});
   
   my $method_for_this_field = $field_ref->{$field}{$called_method};

   croak 
      "Can't $method_of{$called_method}{verb} field $field in $class object "
      . "($called_method method not defined)"
      if not (defined $method_for_this_field) or ($method_for_this_field eq "!");

   if ( reftype($method_for_this_field) eq 'CODE') {
      &{$method_for_this_field}($struct,$field,@args);
   }
   else {
      &{$method_of{$called_method}{$method_for_this_field}}($struct,$field,@args);
   }

}

# Note that the various submethods (_get_scalar, etc.) do NOT necessarily know
# which class they are called in! They only know what data they hold. $struct is not
# necessarily an object, just a hash ref.

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
   my ($struct, $field) = @_;
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
   return @former_values;
}

sub _set_hash_element {
   my ($struct, $field, $element, $value) = @_;
   my $former_value = $struct->{$field}{$element};
   $struct->{$field}{$element} = $value;
   return scalar $former_value;
}


sub _get_hash {
# gets the value of the hash in $field, or a single element if that is defined.
   my ($struct, $field, $element) = @_;
   return scalar ${$struct->{$field}}{$element} if not defined reftype($element);
   return %{$struct->{$field}} if reftype($element) eq 'HASH';
   croak "$field requires HASH reference, not " . reftype($element);
}

sub _set_hash {

   my($struct, $field, $element, $value) = @_;

   # If the passed element is a reference to a list,
   # replace the whole list with it
   if (reftype($element) eq 'HASH') {
      my @former_values = @{$struct->{$field}};
      @{$struct->{$field}} = @{$element};
      return @former_values;
   }

   # otherwise, put the $value in $field, returning the old value
   my $former_value = $struct->{$field}[$element];
   $struct->{$field}[$element] = $value;
   return scalar $former_value;

}


__END__

The following include slices, which I decided were a bad idea.

sub _get_array {
# gets the value of the array in $field.
   my ($struct, $field, @slice) = @_;

   # if the user passes a reference to a list instead of a list, 
   # use the list being referred to instead.
   my $slice_is_a_ref = ref($slice[0]);
   if ($slice_is_a_ref) {
      croak "Can't use a $slice_is_a_ref reference when getting $field"
         unless $slice_is_a_ref eq 'ARRAY';
      croak "Can't pass any more elements if the first one is a reference when getting $field"
         if scalar(@slice) > 1;
      @slice = @{$slice[0]};
   }

   my $element_count = scalar(@slice);

   # if it's a single element, return the value of that element
   return ${$struct->{$field}}[$slice[0]] 
      if ($element_count == 1);

   return @{$struct->{$field}} if not $element_count;
   # if called with no arguments, returns the whole list
   
   return @{$struct->{$field}}[@slice];
   # if called with multiple arguments, returns a slice
   
}

sub _set_array {

   my($struct, $field, $element, @values) = @_;

   # If the passed element is a reference, use that as a slice
   my $isref = reftype($element);
   if ($isref) {
      croak "Can't use a $isref reference as elements when setting $field"
         unless $isref eq 'ARRAY';
      my @slice = @{$element};  # @slice is now the slice list 
      
      # If more than one element in the slice, set the values to the given values
      # and return the old values.
      if (scalar(@slice) > 1) {
         my @former_values = @{$struct->{$field}}[@slice];
         @{$struct->{$field}}[@slice] = @values;
         return @former_values;
      }
      else { # put the only element from the arrayref into $element
         $element = @{$slice[0]};
      }
   }   
   
   # if $element is undefined, set the whole array.    
   if (not defined $element) {
      my @former_values = @{$struct->{$field}};
      @{$struct->{$field}} = @values;
      return @former_values;
   }

   # set one value      
   my $former_value = $struct->{$field}[$element];
   $struct->{$field}[$element] = $values[0];
   return $former_value;

}
   
sub _get_hash {
# gets the value of the hash in $field.
   my ($struct, $field, @slice) = @_;

   # if the user passes a reference to a list instead of a list, 
   # use the list being referred to instead.
   my $slice_is_a_ref = ref($slice[0]);
   if ($slice_is_a_ref) {
      croak "Can't use a $slice_is_a_ref reference when getting $field"
         unless $slice_is_a_ref eq 'ARRAY';
      croak "Can't pass any more elements if the first one is a reference when getting $field"
         if scalar(@slice) > 1;
      @slice = @{$slice[0]};
   }

   my $element_count = scalar(@slice);

   # if it's a single element, return the value of that element
   return ${$struct->{$field}}{$slice[0]}
      if ($element_count == 1);

   return %{$struct->{$field}} if not $element_count;
   # if called with no arguments, returns the whole hash
   
   return @{$struct->{$field}}{@slice};
   # if called with multiple arguments, returns a slice
   
}

sub _set_hash {

   my($struct, $field, $firstkey, @values) = @_;

   # There is no "set a slice of a hash" bit.
   # If $firstvalue is undefined, sets the whole hash to @values.
   # If not, sets $hash{$firstkey} to the first value.

   croak "Can't pass a hash reference as an element when setting $field"
      if ref($firstkey);

   # If the passed element is defined, use that as the element to set

   if (defined($firstkey)) {
      my $former_value = $struct->{$field}{$firstkey};
      $struct->{$field}{$firstkey} = $values[0];
      return $former_value;
   }
    
   # otherwise, assume it is the first of a series of key-value pairs
   
   unshift @values, $firstkey;
 
   my %former_values = %{$struct->{$field}};
   %{$struct->{$field}} = @values;
   return %former_values;
   
}

1;
