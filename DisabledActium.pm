#!/usr/bin/perl

# Actium.pm
# Various initialization and other routines related to the Actium system
# This is to be phased out and routines moved to other modules

# Subversion: $Id$

0; # die if loaded

__END__

use strict;
use warnings;
use 5.010;    # turns on features

package Actium;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

use Getopt::Long;
use FindBin(qw($Bin));
use Carp;
use Storable;
use Text::Wrap;
use Memoize;
use Readonly;
use base qw(Exporter);

our @EXPORT_OK = qw(
  add_option ensuredir chdir_signup all_true option initialize
  avldata bylines underlinekey jt jn jtn key 
  sayq printq sayt transposed
);

use Actium::Support::Constants;

my ( %optionspecs, %caller_of, %options );

#################
#### OPTIONS ####
#################

sub add_option {

    # If another module (as opposed to a main program)
    # calls this routine, it should do so in an INIT block

    while (@_) {

        my $option     = lc( +shift );
        my $optiontext = shift;

        my $caller = ( scalar( caller() ) ) || 'main';

        # check to see that there are no duplicate options

        foreach my $optionname ( _split_optionnames($option) ) {

            if ( exists $caller_of{$optionname} ) {
                croak "Duplicate option $optionname."
                  . "Set by $caller_of{$optionname} and $caller";
            }
            $caller_of{$optionname} = $caller;
        }
        $optionspecs{$option} = $optiontext;
    }

    return;

}

sub _split_optionnames {

    # This routine takes an option (in the form used in Getopt::Long)
    # and returns a list of the aliases.
    my $option = shift;
    $option =~ s/( [a-z \? \- \| ] + ) .*/ $1 /sx;
    return split( /\|/s, $option );

}

sub option {
    return $options{ $_[0] } if exists( $options{ $_[0] } );

    # else
    return;
}

####################
#### INITIALIZE ####
####################

sub initialize {

    #  1) Get command-line options
    #  2) Prints help message if --help specified
    #  3) Get the Actium directory information
    #  4) Dies if there's no signup or basedir
    #  5) changes current directory

    # #######
    # Specify the default options, add options from other modules, and
    # get them from the command line via Getopts::Long

    my $helptext = shift;
    my $intro    = shift;

    add_option( 'basedir=s',
        'Base directory (normally [something]/Actium/signups)' );
    add_option( 'signup=s',
            'Signup. This is the subdirectory under the base directory. '
          . 'Typically something like "f08" (meaning Fall 2008).' );
    add_option( 'quiet!', 'Do not display status information.' );
    add_option( 'help',   'Display this message and quit.' );
    add_option( 'debug!', 'Produce debugging text.' );

    add_option( 'lettersfirst!',
            'When routes are sorted, sort letters ahead of numbers'
          . '(like Muni, not AC)' );

    # useful for others, maybe

    # the ACTIUMCMD environment variable goes on the front of the command line.
    # This allows the command line to override items. I think this should work.
    # The Getopt::Long documentation is not clear.

    if ( $ENV{'ACTIUMCMD'} ) {
        unshift( @ARGV, split( /\s+/s, $ENV{'ACTIUMCMD'} ) );
    }

    my $optresult = GetOptions( \%options, keys %optionspecs );

    # From Getopt::Long

## ######
## help
##
    if ( option('help') or not $optresult ) {

        my %helpmessages;

        print "\n"
          or carp "Can't output help text: $!";

        $helptext =~ s/\n+\z//s;

        print $helptext , "\n\nOptions:\n"
          or carp "Can't output help text: $!";

        my $longest = 0;

        foreach my $spec ( keys %optionspecs ) {
            my (@optionnames) = _split_optionnames($spec);

            foreach (@optionnames) {
                $longest = length($_) if $longest < length($_);
            }

            my $first = shift @optionnames;

            $helpmessages{$first} = $optionspecs{$spec};
            $helpmessages{$_} = "Same as -$first." foreach @optionnames;

        }

        $longest++;    # add one for the hyphen in front

        Readonly my $HANGING_INDENT_PADDING => 4;

        foreach ( sort keys %helpmessages ) {
            my $optionname = sprintf '%*s -- ', $longest, "-$_";

            #local($Text::Wrap::columns) = 75 - ($longest);
            say Text::Wrap::wrap (
                $_,
                q[ ] x ( $longest + $HANGING_INDENT_PADDING ),
                $optionname . $helpmessages{$_}
            );

        }
        print "\n"
          or carp "Can't output help text: $!";

        exit 1;

    }

    sayq($intro);

## ###########
## check for, and change to, directories

    $options{basedir} =
         $options{basedir}
      || $ENV{'ACTIUM_BASEDIR'}
      || "$Bin/../signups/";

    croak "Base directory $options{basedir} not found"
      unless -d $options{basedir};

    chdir_signup(qw(signup ACTIUM_SIGNUP signup));

    return;

}


##########################
#### SAY, PRINT, JOIN, ETC.
##########################

sub sayt {

    #   my $join = ( $ENV{'RUNNING_UNDER_AFFRUS'} ? '  ' : "\t" );
    #   print join ($join , @_) , "\n";
    say jt(@_);
    return;
}

# syntactic sugar is so, so sweet

sub jt { return join( "\t", @_ ) }

sub jn { return join( "\n", @_ ) }

sub jtn {
    return ( join( "\t", @_ ) . "\n" );
}

##########################
### KEY ROUTINES
##########################

sub key {
    return join( $KEY_SEPARATOR, @_ );
}

sub underlinekey {
    local $_ = shift;
    s/$KEY_SEPARATOR/_/sxg;
    return $_;
}

## use critic

1;
