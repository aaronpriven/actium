package Actium::Cmd 0.010;

use Actium::Preamble;
use Getopt::Long;    ### DEP ###
use Actium::O::CmdEnv;
use Actium::Crier('default_crier');
use Text::Wrap;       ### DEP ###
use Term::ReadKey;    ### DEP ###

my $crier;

const my $EX_USAGE    => 64;    # from "man sysexits"
const my $EX_SOFTWARE => 70;
const my $COMMAND_PREFIX => 'Actium::Cmd';

sub run {

    my %params      = @_;
    my $system_name = $params{system_name};
    my %module_of   = %{ $params{subcommands} };

    $crier = default_crier();

    _init_terminal();

    _eclipse_command_line();
    my ( $help_requested, $subcommand )
      = _get_subcommand( \%module_of, $system_name );
    my $module = _get_module( $subcommand, \%module_of, $system_name );

    my $env = Actium::O::CmdEnv::->new(
        commandpath => $params{commandpath},
        subcommand  => $subcommand,
        system_name => $system_name,
        crier       => $crier,
        module      => $module,
    );

    require_module($module) or die " Couldn't load module $module: $OS_ERROR";

    my %helpmsg_of = _process_options($env);

    $env->_set_argv_r( [@ARGV] );

    if ( $help_requested or $env->option('help') ) {
        if ( $module->can('HELP') ) {
            $module->HELP($env);
        }
        else {
            say "Help not implemented for $subcommand.";
        }
        _output_usage(%helpmsg_of);
    }
    else {
        $module->START($env);
    }

    return;

} ## tidy end: sub run

const my $SUBCOMMAND_PADDING   => ( $SPACE x 2 );
const my $SUBCOMMAND_SEPARATOR => ( $SPACE x 2 );

sub _mainhelp {
    my %params      = @_;
    my %module_of   = %{ $params{module_of} };
    my $status      = $params{status} // 0;
    my $error       = $params{error};
    my $system_name = $params{system_name};
    my $helptext    = $EMPTY_STR;

    if ($error) {
        $helptext .= "$error\n";
    }

    $helptext .= "Subcommands available for $system_name:\n";

    my @subcommands = grep { not defined( u::reftype( $module_of{$_} ) ) }
      sort keys %module_of;

    #my @subcommands;
    #foreach my $subcommand ( sort keys %module_of ) {
    #    next if defined( u::reftype( $module_of{$subcommand} ) );
    #    push @subcommands, $subcommand;
    #}

    my $width = _get_width() - 2;

    require Actium::O::2DArray;
    ( undef, \my @lines ) = Actium::O::2DArray->new_like_ls(
        array     => \@subcommands,
        width     => $width,
        separator => ($SUBCOMMAND_SEPARATOR)
    );

    say $helptext, $SUBCOMMAND_PADDING,
      join( ( "\n" . $SUBCOMMAND_PADDING ), @lines )
      or die "Can't output help text: $OS_ERROR";

    exit $status;
} ## tidy end: sub _mainhelp

sub _output_usage {

    my %helpmessages = @_;

    say "\nOptions:"
      or carp "Can't output help text : $OS_ERROR";

    my $longest = 0;

    foreach my $option ( keys %helpmessages ) {
        $longest = length($option) if $longest < length($option);
    }

    $longest++;    # add one for the hyphen in front

    const my $HANGING_INDENT_PADDING => 4;
    ## no critic (Variables::ProhibitPackageVars)
    local ($Text::Wrap::columns) = _get_width();
    ## use critic

    foreach ( sort keys %helpmessages ) {
        next if /\A_/s;
        my $optionname = sprintf '%*s -- ', $longest, "-$_";

        say Text::Wrap::wrap (
            $EMPTY_STR,
            q[ ] x ( $longest + $HANGING_INDENT_PADDING ),
            $optionname . $helpmessages{$_}
        );

    }
    print "\n"
      or carp "Can't output help text : $OS_ERROR";

    return;

}    ## <perltidy> end sub output_usage

sub _eclipse_command_line {
    no warnings('once');
    ## no critic (RequireExplicitInclusion, RequireLocalizedPunctuationVars)
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
        ## use critic
    }
    return;
}

sub _get_subcommand {

    my %module_of   = %{ +shift };
    my $system_name = shift;

    my ( $help_arg, $help_requested, $subcommand );

    if (@ARGV) {
        for ( 0 .. $#ARGV ) {
            if ( fc( $ARGV[$_] ) eq fc('help') ) {
                $help_requested = 1;
                $help_arg       = $_;
                #splice( @ARGV, $_, 1 );
                next;
            }
            if ( $ARGV[$_] !~ /\A -/sx ) {
                $subcommand = splice( @ARGV, $_, 1 );
                last;
            }
        }
    }

    if ($help_arg) {
        splice( @ARGV, $help_arg, 1 );
    }

    if ( not $subcommand ) {
        _mainhelp(
            module_of   => \%module_of,
            system_name => $system_name,
            #status => $EX_USAGE,
            #error  => (
            #    $help_requested
            #    ? 'No subcommand found after "help" on command line.'
            #    : 'No subcommand found on command line.'
            #),
        );
    }

    return $help_requested, $subcommand;
} ## tidy end: sub _get_subcommand

sub _get_module {
    my $subcommand  = shift;
    my %module_of   = %{ +shift };
    my $system_name = shift;

    my $referred;
    while ( exists( $module_of{$subcommand} )
        and defined( u::reftype( $module_of{$subcommand} ) ) )
    {
        $subcommand = ${ $module_of{$subcommand} };
        $referred   = 1;
    }
    if ( not exists $module_of{$subcommand} ) {
        if ($referred) {
            _mainhelp(
                module_of   => \%module_of,
                system_name => $system_name,
                status      => $EX_SOFTWARE,
                error =>
                  "Internal error (bad reference) in subcommand $subcommand."
            );
        }
        else {
            _mainhelp(
                module_of   => \%module_of,
                system_name => $system_name,
                status      => $EX_USAGE,
                error       => "Unrecognized subcommand $subcommand."
            );
        }
    }

    return "${COMMAND_PREFIX}::$module_of{$subcommand}";

} ## tidy end: sub _get_module

##### PROCESS OPTIONS

sub _process_options {
    my $env    = shift;
    my $module = $env->module;

    my @option_requests = (
        [ 'help|?', 'Displays this help message' ],
        [   '_stacktrace',
            'Provides lots of debugging information if there is an error. '
              . 'Best ignored'
        ],
        [ 'quiet!',     'Does not display unnecessary information' ],
        [ 'termcolor!', 'May display colors in terminal output.' ],
        [   'progress!',
            'May display dynamic progress indications. '
              . 'On by default. Use -noprogress to turn off',
            1,
        ],
    );

    my @module_options;
    @module_options = $module->OPTIONS($env) if $module->can('OPTIONS');

    # add code for plugins here

    unshift @option_requests, @module_options;

    my ( %options, @option_specs, %callback_of, %helpmsg_of );

    for my $optionrequest_r (@option_requests) {
        my ( $option_spec, $option_help, $callbackordefault )
          = @{$optionrequest_r};
        push @option_specs, $option_spec;

        my $allnames   = $option_spec =~ s/( [\w ? \- | ] + ) .*/$1/rsx;
        my @splitnames = split( /[|]/s, $allnames );
        my $mainname   = shift @splitnames;

        foreach my $optionname ( $mainname, @splitnames ) {
            die "Attempt to add duplicate option or alias $optionname."
              if ( exists $helpmsg_of{$optionname} );
        }

        $helpmsg_of{$mainname} = $option_help;
        $helpmsg_of{$_} = "Same as -$mainname" foreach @splitnames;

        if ( ref($callbackordefault) eq 'CODE' ) {
            # it's a callback
            $callback_of{$mainname} = $callbackordefault;
        }
        else {
            # it's a default value
            $options{$mainname} = $callbackordefault;
        }

    } ## tidy end: for my $optionrequest_r...

    my $returnvalue = GetOptions( \%options, @option_specs );
    die "Errors parsing command-line options.\n" unless $returnvalue;

    foreach my $thisoption ( keys %options ) {
        if ( exists $callback_of{$thisoption} ) {
            &{ $callback_of{$thisoption} }( $options{$thisoption} );
        }
    }

    $env->_set_options_r( \%options );

    $env->crier->set_maxdepth(0) if $options{'quiet'};
    $env->crier->use_color if $options{'termcolor'};
    $env->crier->hide_progress unless $options{'progress'};

    if ( $options{'_stacktrace'} ) {
        ## no critic (RequireLocalizedPunctuationVars)
        $SIG{'__WARN__'} = \&_stacktrace;
        $SIG{'__DIE__'}  = \&_stacktrace;
        ## use critic
    }

    return %helpmsg_of;

} ## tidy end: sub _process_options

##### TERMINAL AND SIGNAL FUNCTIONS #####

sub _init_terminal {

    ## no critic (RequireLocalizedPunctuationVars)
    $SIG{'WINCH'} = \&_set_width;
    $SIG{'INT'}   = \&_terminate;
    ## use critic

    _set_width();
    return;

}

sub _stacktrace {
    Carp::confess(@_);
    return;
}

sub _terminate {
    my $signal = shift;
    $crier->text("Caught SIG$signal... Aborting program.");
    exit 1;
}

sub _set_width {
    my $width = _get_width();
    $crier->set_column_width($width);
    return;
}

const my $FALLBACK_COLUMNS => 80;

sub _get_width {
    my $width = (
        eval {
            #local ( $SIG{__DIE__} ) = 'IGNORE';
            ( Term::ReadKey::GetTerminalSize() )[0];

            # Ignore errors from GetTerminalSize
        }

          #or $Actium::Eclipse::is_under_eclipse ? 132 : 80
          or $FALLBACK_COLUMNS
    );
    return $width;
}

sub term_readline {

    require IO::Prompter;    ### DEP ###

    my $prompt = shift;
    my $hide   = shift;

    my $val;

    print "\n";

    if ($hide) {
        $val
          = IO::Prompter::prompt( $prompt, -echo => '*', '-hNONE', '-stdio' );
    }
    else {
        $val = IO::Prompter::prompt( $prompt, '-stdio' );
    }

    $crier->set_position(0);

    return "$val";
    # stringify what would otherwise be a weird Contextual::Return value,
    # thank you Mr. Conway

} ## tidy end: sub term_readline

1;

__END__

Documentation originally from Actium::Term

=over

=item B<output_usage>

This routine gets the help messages from B<Actium::Options::helpmessages()> 
and displays them in a pretty manner. It is intended to be used from HELP 
routines in modules.

Help messages of options beginning with underscores (e.g., -_stacktrace) 
are not displayed.

Documentation from Actium::Options

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

Actium::Options is a wrapper for L<Getopt::Long|Getopt::Long>. 
It contains routines designed to allow both main programs and 
any used modules to set particular command-line options.

The idea is that the main program can set options that apply to the main
program, and any modules can set other options that apply to that module. 

Note that the default configuration for Getopt::Long is used, so (for
example) bundling is off and options can be abbreviated to their shortest
unique abbreviation. See 
L<Getopt::Long/"Configuring Getopt::Long"|"Configuring Getopt::Long" in Getopt::Long>.

=head1 SUBROUTINES

No subroutine names are exported by default, but most can be imported.

=over

=item B<add_option($optionspec, $description, $callbackordefault)>

To add an option for processing, use B<add_option()>.

$optionspec is an
option specification as defined in L<Getopt::Long|Getopt::Long>. Note that to specify
options that take list or hash values, it is necessary to indicate this
by appending an "@" or "%" sign after the type. See L<Getopt::Long/"Summary 
of Option Specifications"> for more information.

B<add_option()> will accept alternate names in the $optionspec, as described in 
L<Getopt::Long/Getopt::Long>.  
Other subroutines (B<option()>, B<set_option()>, etc.) require that
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
the same terms as Perl itself. See L<perlartistic|perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.


