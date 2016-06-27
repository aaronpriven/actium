package Actium::O::Cmd 0.011;

# Amalgamation of Actium::Cmd, Actium::O::CmdEnv, and the various
# Actium::Cmd::Config::* modules

use Actium::Moose;
use FindBin (qw($Bin));
use Actium::O::Files::Ini;

use Getopt::Long;    ### DEP ###
use Actium::Crier('default_crier');
use Text::Wrap;       ### DEP ###
use Term::ReadKey;    ### DEP ###

const my $EX_USAGE       => 64;              # from "man sysexits"
const my $EX_SOFTWARE    => 70;
const my $COMMAND_PREFIX => 'Actium::Cmd';

const my $FALLBACK_COLUMNS     => 80;
const my $SUBCOMMAND_PADDING   => ( $SPACE x 2 );
const my $SUBCOMMAND_SEPARATOR => ( $SPACE x 2 );

my $term_width_cr = sub {
    return (
        eval { ( Term::ReadKey::GetTerminalSize() )[0]; }
          or $FALLBACK_COLUMNS
    );
};

##### BUILDARGS and associated routines

my $mainhelp_cr = sub {
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

    my @subcommands
      = grep { not is_ref( $module_of{$_} ) } sort keys %module_of;

    my $width = $term_width_cr->() - 2;

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

};

my $get_module_cr = sub {
    my $subcommand = shift;

    my %module_of   = %{ +shift };
    my $system_name = shift;

    my $referred;
    while ( exists( $module_of{$subcommand} )
        and u::is_ref( $module_of{$subcommand} ) )
    {
        $subcommand = ${ $module_of{$subcommand} };
        $referred   = 1;
    }

    if ( not exists $module_of{$subcommand} ) {
        if ($referred) {
            $mainhelp_cr->(
                module_of   => \%module_of,
                system_name => $system_name,
                status      => $EX_SOFTWARE,
                error =>
                  "Internal error (bad reference) in subcommand $subcommand."
            );
        }
        else {
            $mainhelp_cr->(
                module_of   => \%module_of,
                system_name => $system_name,
                status      => $EX_USAGE,
                error       => "Unrecognized subcommand $subcommand."
            );
        }
    }

    return "${COMMAND_PREFIX}::$module_of{$subcommand}";

};

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %params = u::validate(
        @_,
        {   system_name => { type => $PV_TYPE{SCALAR} },
            subcommands => { type => $PV_TYPE{HASHREF} },
            commandpath => { type => $PV_TYPE{SCALAR} },
            argv        => { type => $PV_TYPE{ARRAYREF} },
        }
    );

    my @original_argv = @{ $params{argv} };

    ## no critic (RequireExplicitInclusion, RequireLocalizedPunctuationVars)
    {    # scoping for "no warnings"
        no warnings('once');
        if ( ( not @original_argv ) and $Actium::Eclipse::is_under_eclipse ) {
            @original_argv = Actium::Eclipse::get_command_line();
        }
    }
    ## use critic

    my @argv = @{ $params{argv} };    # intentional copy
    my ( $help_requested, $help_arg_index, $subcommand );

    if (@argv) {
        for my $i ( 0 .. $#argv ) {
            if ( u::feq( $argv[$i], 'help' ) ) {
                $help_requested = 1;
                $help_arg_index = $i;
                next;
            }
            if ( $argv[$i] !~ /\A -/sx ) {
                $subcommand = splice( @argv, $i, 1 );
                # remove subcommand from args
                last;
            }
        }
    }

    if ( not $subcommand ) {
        $mainhelp_cr->(
            module_of   => $params{subcommands},
            system_name => $params{system_name},
        );
    }

    splice( @argv, $help_arg_index, 1 ) if $help_arg_index;
    # delete 'help'

    my $module = $get_module_cr->(
        $subcommand, $params{subcommands}, $params{system_name}
    );

    require_module($module) or die " Couldn't load module $module: $OS_ERROR";

    my %init_args = (
        commandpath    => $params{commandpath},
        subcommand     => $subcommand,
        system_name    => $params{system_name},
        module         => $module,
        original_argv  => \@original_argv,
        help_requested => $help_requested,
        argv           => \@argv,
    );

    return $class->$orig->(%init_args);

};

#### BUILD and associated methods

sub BUILD {
    my $self   = shift;
    my $module = $self->module;

    $self->_init_terminal();

    $self->_get_options();

    if ( $self->help_requested or $self->option('help') ) {
        if ( $module->can('HELP') ) {
            $module->HELP($self);
        }
        else {
            say "Help not implemented for $self->subcommand.";
        }
        $self->_output_usage();
    }
    else {
        $self->_handle_options;
        $module->START($self);
    }

} ## tidy end: sub BUILD

sub _get_options {
    my $self = shift;

    my $module = $self->module;

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
    @module_options = $module->OPTIONS($self) if $module->can('OPTIONS');

    # add code for plugins here

    foreach my $module_option ( reverse @module_options ) {

        if ( u::is_arrayref($module_option) ) {
            unshift @option_requests, $module_option;
        }
        elsif ( $module_option eq 'actiumfm' ) {
            require Actium::Cmd::Config::ActiumFM;
            my @opts = Actium::Cmd::Config::ActiumFM::options($self);
            unshift @option_requests, @opts;
        }

    }
    # that adds the option code, but it needs to actually use
    # the option and put the result in $env (or something)

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

    $self->_set_options_r( \%options );
    $self->_set_helpmsg_of_r( \%helpmsg_of );

    return;

} ## tidy end: sub _get_options

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
    local ($Text::Wrap::columns) = $term_width_cr->();
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

sub _handle_options {

    # these are options set here as opposed to in the submodules

    my $self = shift;

    $self->crier->set_maxdepth(0) if $self->option('quiet');
    $self->crier->use_color if $self->option('termcolor');
    $self->crier->hide_progress unless $self->option('progress');

    if ( $self->option('_stacktrace') ) {
        ## no critic (RequireLocalizedPunctuationVars)
        $SIG{'__WARN__'} = \&_stacktrace;
        $SIG{'__DIE__'}  = \&_stacktrace;
        ## use critic
    }

}

##### TERMINAL AND SIGNAL FUNCTIONS #####

sub _init_terminal {

    my $self = shift;

    ## no critic (RequireLocalizedPunctuationVars)
    #$SIG{'WINCH'} = \&_set_width;
    #$SIG{'INT'}   = \&_terminate;
    $SIG{'WINCH'} = sub {
        $self->crier->set_column_width( $term_width_cr->() );
    };
    $SIG{'INT'} = sub {
        my $signal = shift;
        $self->crier->text("Caught SIG$signal... Aborting program.");
        exit 1;
    };
    ## use critic

    _set_width();
    return;

} ## tidy end: sub _init_terminal

sub _stacktrace {
    Carp::confess(@_);
    return;
}

#sub _terminate {
#    my $signal = shift;
#    $crier->text("Caught SIG$signal... Aborting program.");
#    exit 1;
#}
#
#sub _set_width {
#    my $width = $term_width_cr->();
#    $crier->set_column_width($width);
#    return;
#}

sub term_readline {
    
    my $self = shift;

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

    $self->crier->set_position(0);

    return "$val";
    # stringify what would otherwise be a weird Contextual::Return value,
    # thank you Mr. Conway

} ## tidy end: sub term_readline


################
## Attributes

sub _build_config {
    my $self       = shift;
    my $systemname = $self->system_name;

    ## no critic (RequireExplicitInclusion)
    # bug in RequireExplicitInclusion
    my $config = Actium::O::Files::Ini::->new(".$systemname.ini");
    ## use critic

    return $config;

}

has config => (
    is      => 'ro',
    isa     => 'Actium::O::Files::Ini',
    builder => '_build_config',
    lazy    => 1,
);

has bin => (
    isa     => 'Actium::O::Folder',
    is      => 'ro',
    builder => '_build_bin',
    lazy    => 1,
);

has [qw/commandpath subcommand system_name module/] => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has crier => (
    is      => 'ro',
    default => sub { default_crier() },
    isa     => 'Actium::O::Crier',
    lazy    => 1,
);

sub _build_bin {
    require Actium::O::Folder;
    return Actium::O::Folder::->new($Bin);
}

has command => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_command',
);

sub _build_command {
    my $self        = shift;
    my $commandpath = $self->commandpath;
    return u::filename($commandpath);
}

has sysenv_r => (
    traits  => ['Hash'],
    isa     => 'HashRef[Str]',
    is      => 'bare',
    builder => '_build_sysenv',
    lazy    => 1,
    handles => { sysenv => 'get', },
);

sub _build_sysenv {
    return {%ENV};
}

has argv_r => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    is      => 'bare',
    writer  => '_set_argv_r',
    default => sub { [] },
    handles => {
        argv     => 'elements',
        argv_idx => 'get',
    },
);

has options_r => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    is      => 'bare',
    writer  => '_set_options_r',
    default => sub { {} },
    handles => {
        option        => 'get',
        _set_option   => 'set',
        option_is_set => 'exists',
    },
);

sub be_quiet {

    my $self = shift;
    $self->crier->set_maxdepth(0);
    $self->_set_option( 'quiet', 1 );

}

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


=cut




