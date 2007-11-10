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

my %verb_of = (
                 GET        => 'get',
                 SET        => 'set',
                 GETELEMENT => 'get an element of',
                 SETELEMENT => 'set an element of',
              );
              
my %methodname_of = (
                 GET        => 'get&',
                 SET        => 'set&',
                 GETELEMENT => 'get&element',
                 SETELEMENT => 'set&element',
              );
 
my %expansion_of = ( 
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
                 );

sub make_methods {

   my ($class,$struct_of_ref,$fields_ref) = @_;

   foreach my $field (keys %{$fields_ref}) {
      my $coderefs_for_this_field = $fields_ref->{$field};

      if (exists($expansion_of{$coderefs_for_this_field})) {
         $coderefs_for_this_field = $expansion_of{$coderefs_for_this_field};
      }
      
      croak 
         "Declaring field '$field': '$coderefs_for_this_field'"
         . " is not a valid field type"
         if reftype($coderefs_for_this_field) ne 'HASH';
         
      foreach my $methodtype (keys %{$coderefs_for_this_field}) {
      
         my $methodname = $methodname_of{$methodtype};
         $methodname =~ s/\&/_${field}_/;
         $methodname =~ s/_\z//;
         $methodname =~ s/\A_//;

			{
	         no strict 'refs';
	         *{$class . "::$methodname"} 
	             = sub { 
	                     my $self = shift;
	                     my $struct = $struct_of_ref->{refaddr($self)};
	                     &{$coderefs_for_this_field->{$methodtype}}
	                       ($struct,@_);
	                   };
			}

      }
   
   }

}

# Note that the various subroutines below (_get_scalar, etc.) 
# do NOT necessarily know
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