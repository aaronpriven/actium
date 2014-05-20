# Actium/Options.pm
# command-line option handling for Actium system

# Subversion: $Id$

use strict;
use warnings;

package Actium::Options;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

use 5.010;    # turns on features

use base qw(Exporter);
our @EXPORT_OK = qw(
  add_option option init_options is_an_option set_option helpmessages
);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

use Carp;
use Getopt::Long;

my ( %optionspecs, %caller_of, %callback_of, %options, %caller_seen, $inited );

#sub import {
#
#    my $caller = scalar caller();
#
#    $caller_seen{$caller} = 1
#      if $caller;
#
#    Actium::Options->export_to_level( 1, @_ );
#
#    # use Exporter to export the appropriate symbols
#
#    return;
#
#}

sub add_option {

    croak __PACKAGE__ . ': Attempt to add option after initialization'
      if $inited;

    while (@_) {

        my $option     = lc( +shift );
        my $optiontext = shift;
        my $callbackordefault   = shift;
        
        my $caller = ( scalar( caller() ) ) || 'main';

        my @splitnames = _split_optionnames($option);
        
        my $mainname = $splitnames[0];
        
        if (ref($callbackordefault) eq 'CODE') {
            # it's a callback
            $callback_of{ $splitnames[0] } = $callbackordefault;
            
        }
        else {
            # it's a default value
            $options{$mainname} = $callbackordefault;
        }
        
        # check to see that there are no duplicate options

        foreach my $optionname (@splitnames) {

            if ( exists $caller_of{$optionname} ) {
                croak "Attempt to add duplicate option $optionname. "
                  . "Set by $caller_of{$optionname} and $caller";
            }
            $caller_of{$optionname} = $caller;
        }
        $optionspecs{$option} = $optiontext;
    }

    return;

}

sub is_an_option {
    my $optionname = shift;
    return 1 if $caller_of{$optionname};
    return;
}

# TODO add facility to share options when module says it's ok.
# That is, a add_shared_option would allow for duplicates, but
# add_option would not. Or something like that.

sub _split_optionnames {

    # This routine takes an option (in the form used in Getopt::Long)
    # and returns a list of the aliases.
    my $option = shift;
    $option =~ s/( [\w \? \- \| ] + ) .*/$1/sx;

    # names can contain word characters, question marks or hyphens.
    # Vertical bars separate aliases.
    return split( /\|/s, $option );
}

sub option {
    croak __PACKAGE__ . ': Attempt to access option before initialization'
    #init_options()
      unless $inited;
    my $option = shift;
    if ( exists( $options{$option} ) ) {
        return $options{$option};
    }

    # else
    return;
}

sub set_option {
    croak __PACKAGE__ . ': Attempt to set an option before initaliztion'
#    init_options()
      unless $inited;
    my $option = shift;
    my $old    = option($option);
    $options{$option} = shift;
    return $old;
}

sub init_options {

    croak __PACKAGE__ . ': Attempt to initialize options more than once'
      if $inited;

#    foreach my $caller (keys %caller_seen) {
#        no strict('refs');
#        if ( *{"${caller}::OPTIONS"}{CODE} ) {
#            &{"${caller}::OPTIONS"}();
#        }
#
#        # if there is an OPTIONS sub in each calling package,
#        # run it. Presumably this will have add_option calls in it.
#
#    }

    $inited = 1;

    my $returnvalue = GetOptions( \%options, keys %optionspecs );

    if ($returnvalue) {
        foreach my $thisoption ( keys %options ) {
            if ( exists $callback_of{$thisoption} ) {
                &{ $callback_of{$thisoption} }( $options{$thisoption} );
            }
        }
    }

    return $returnvalue;

    # TODO - allow overrides by environment variables (some or all)

}

sub helpmessages {

    my %helpmessages;

    foreach my $spec ( keys %optionspecs ) {
        my (@optionnames) = _split_optionnames($spec);

        my $first = shift @optionnames;

        $helpmessages{$first} = $optionspecs{$spec};
        $helpmessages{$_} = "Same as -$first." foreach @optionnames;

    }

    return \%helpmessages;

}

1;

__END__

=head1 NAME

Actium::Options - command-line options for the Actium system

=head1 VERSION

This documentation refers to Actium::Options version 0.001

=head1 SYNOPSIS

In a module:

 use Actium::Options qw(option add_option);
 
 add_option ('sad'    , 'Makes the output sad'  );
 add_option ('angry!' , 'Makes the output angry');
 
 sub emotion {
  say 'Grr!!!' if option ('angry');
  say 'Waa!!!' if option ('sad');
 }

In a main program:

 use Actium::Options qw(add_option option init_options);
 add_option('verbose!','Unnecessary output will be presented');
 init_options() or croak 'Options could not be processed';
 print "Now processing..." if option('verbose');
 
=head1 DESCRIPTION

Actium::Options is a wrapper for L<Getopt::Long>. 
It contains routines designed to allow both main programs and 
any used modules to set particular command-line options.

The idea is that the main program can set options that apply to the main
program, and any modules can set other options that apply to that module. 
For example, the Actium::Sorting::Line module has a -lettersfirst option 
that changes the sort order of lines. This
is independent of the -quiet option in Actium::Term, which turns off 
unnecessary text.

Note that the default configuration for Getopt::Long is used, so (for
example) bundling is off and options can be abbreviated to their shortest
unique abbreviation. See L<Getopt::Long/"Configuring Getopt::Long">.

=head1 SUBROUTINES

No subroutine names are exported by default, but most can be imported.

=over

=item B<add_option($optionspec, $description, $callbackordefault)>

To add an option for processing, use B<add_option()>.

$optionspec is an
option specification as defined in L<Getopt::Long>. Note that to specify
options that take list or hash values, it is necessary to indicate this
by appending an "@" or "%" sign after the type. See L<Getopt::Long/"Summary 
of Option Specifications"> for more information.

B<add_option()> will accept alternate names in the $optionspec, as described in 
L<Getopt::Long>.  Other subroutines (B<option()>, B<set_option()>, etc.) require that
the primary name be used.

$description is a human-readable short description to be used in
displaying lists of options to users.

If $callbackordefault is present, and is a code reference, the code referred to will 
be executed if the option is set. The value of the option will be the 
first element of the @_ passed to the code.

If $callbackordefault is present but not a code reference, it will be treated as
the default value for the option.

All calls to add_option must run prior to the time the command line is
processed. Place add_option calls in the main part of your module.

=for comment
All calls to add_option must run prior to the time the command line is
processed. For this purpose, you can put your add_option calls in a 
subroutine called OPTIONS. This subroutine (if present) is called 
by init_options just before the command line is processed. You can 
think of it as a specialized sort of INIT block. (You can also do them in real
INIT blocks, if you know that your INIT blocks will run. The  
'eval "require $module"' syntax for requiring modules at runtime
does not, like all string eval's, run INIT blocks. This syntax has been
used in actium.pl for loading primary modules.) --- THIS ROUTINE NO LONGER EXISTS

=item B<is_an_option($optionname)>

Returns true if an option $optionname has been defined (whether as
a primary name or as an alias).

=item B<init_options()>

This is the routine that actually processes the options. It should be called
from the main program (not from any modules, although this is not enforced).

=for comment
<This has been commented out in the code>
Before processing the options, it checks to see if a subroutine called OPTIONS
exists in the module that added the option, and if so, runs it. This is designed
to allow options to be added by support modules.

After processing the options, for each option that is actually set, it calls
the callback routine as specified in the add_option call.
This replaces the callback feature of Getopt::Long.

=item B<option($optionname)>

The B<option()> subroutine returns the value of the option. This can be
the value, or a reference to a hash or array if that was in the option
specification. 


=item B<set_option($optionname, $value)>

This routine sets the value for an option. It is used to override options
set by users (for whatever reason).

=item B<helpmessages()>

This routine returns a reference to a hash. The keys of the hash are the
option names, and the values are the human-readable help descriptions. Aliases
for option names are given separately. The help text for these is simply 
"Same as -primaryoption."  So:

 add_option ('height|width|h=f' , "Height of box")
will result in

 h => "Same as -height."
 height => "Height of box."
 width => "Same as -height."

In no particular order, of course.

=back


=head1 DIAGNOSTICS

=over

=item Attempt to add option after initialization

This means that add_option was called after init_options was already run.

=item Attempt to set an option before initaliztion

This means that set_option was called before init_options was run.

=for comment
#=item Something other than a code reference was used as a callback

=for comment
When using add_options, something was provided as a callback routine 
that was not actually a code reference.

=item Attempt to add duplicate option $optionname. 

A module tried to add an option that had already been added 
(presumably by another module).

=item Attempt to access option before initialization

A module tried to access an option through option() before init_options 
had been called.

=item Attempt to set an option before initaliztion

A module tried to set an option through set_option() before init_options 
had been called.

=item Attempt to initialize options more than once

Something called init_options after init_options had already been called.

=back

=head1 DEPENDENCIES

perl 5.010.

=head1 BUGS AND LIMITATIONS

Actium::Options does not support all the features of Getopt::Long. Only the
default configuration can be used, and subroutines cannot be specified as the
destinations for non-option arguments. (Callbacks are implemented for options
in another way.)

Arguments currently cannot be shared; there's no way to specify an argument like
"quiet" that might be usable across several different modules, because the
add_option will fail. (You can still access the option, just not specify it, so
you can still use an option if you use the module first.)

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.


