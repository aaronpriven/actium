package Actium::Cmd 0.010;

use Actium::Preamble;
use Actium::O::CmdEnv;
use Actium::Crier('default_crier');
use Text::Wrap;    ### DEP ###
# for output_usage
use Term::ReadKey;    ### DEP ###

use Actium::Options qw(add_option init_options option);

# eventually merge that into this module

# Ask user for a command line, if running under Eclipse.

my ( $system_name, $crier, $env );
my %module_of;

const my $EX_USAGE    => 64;    # from "man sysexits"
const my $EX_SOFTWARE => 70;

sub run {

    my %params = @_;
    $system_name = $params{system_name};
    %module_of   = %{ $params{commands} };

    $crier = default_crier();

    _init_terminal();

    _eclipse_command_line();
    my ( $help_requested, $subcommand ) = _get_subcommand( \%module_of );
    my $module = _get_module($subcommand);

    my $env = Actium::O::CmdEnv::->new(
        subcommand  => $subcommand,
        system_name => $system_name,
        crier       => $crier,
    );

    require_module($module) or die " Couldn't load module $module: $OS_ERROR ";

    _process_my_options($module);

    $env->_set_argv_r( [@ARGV] );

    if ( $help_requested or option('help') ) {
        if ( $module->can('HELP') ) {
            $module->HELP($env);
            output_usage();
        }
        else {
            say "Help not implemented for $subcommand.";
            output_usage();
        }
    }
    else {
        $module->START($env);
    }

    return;

} ## tidy end: sub run

sub _mainhelp {
    my %params = @_;
    my $status = $params{status} // 0;
    my $error  = $params{error};
    my @helptext;

    if ($error) {
        @helptext = ("$error\n");
    }

    push @helptext, "$system_name subcommands available:\n";
    foreach my $subcommand ( sort keys %module_of ) {
        next if defined( reftype( $module_of{$subcommand} ) );
        push @helptext, $subcommand;
    }

    say jn(@helptext) or die "Can't output help text: $OS_ERROR";

    exit $status;

} ## tidy end: sub _mainhelp

sub output_usage {

    my $messages_r = Actium::Options::helpmessages;

    say 'Options:'
      or carp " Can't output help text : $! ";

    my $longest = 0;

    foreach my $option ( keys %{$messages_r} ) {
        $longest = length($option) if $longest < length($option);
    }

    $longest++;    # add one for the hyphen in front

    my $HANGING_INDENT_PADDING = 4;
    local ($Text::Wrap::columns) = _get_width();

    foreach ( sort keys %{$messages_r} ) {
        next if /^_/;
        my $optionname = sprintf '%*s -- ', $longest, " - $_ ";

        say Text::Wrap::wrap (
            $EMPTY_STR,
            q[ ] x ( $longest + $HANGING_INDENT_PADDING ),
            $optionname . $messages_r->{$_}
        );

    }
    print " \n "
      or carp " Can't output help text : $! ";

}    ## <perltidy> end sub output_usage
1;

sub _eclipse_command_line {
    no warnings('once');
    ## no critic (RequireExplicitInclusion, RequireLocalizedPunctuationVars)
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
        ## use critic
    }
}

sub _get_subcommand {

    #\my %module_of = shift;

    my ( $help_arg, $help_requested, $subcommand );

    if (@ARGV) {
        for ( 0 .. $#ARGV ) {
            if ( $ARGV[$_] =~ /\A help \z/isx ) {
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
    my $subcommand = shift;
    my $referred;
    while ( exists( $module_of{$subcommand} )
        and defined( reftype( $module_of{$subcommand} ) ) )
    {
        $subcommand = ${ $module_of{$subcommand} };
        $referred   = 1;
    }
    if ( not exists $module_of{$subcommand} ) {
        if ($referred) {
            _mainhelp(
                status => $EX_SOFTWARE,
                error =>
                  "Internal error (bad reference) in subcommand $subcommand."
            );
        }
        else {
            _mainhelp(
                status => $EX_USAGE,
                error  => "Unrecognized subcommand $subcommand."
            );
        }
    }

    return "Actium::Cmd::$module_of{$subcommand}";

} ## tidy end: sub _get_module

##### PROCESS MY OPTIONS

sub _process_my_options {
    my $module = shift;

    my @options = (
        [ 'help|?', 'Displays this help message.' ],
        [   '_stacktrace',
            'Provides lots of debugging information if there is an error. '
              . 'Best ignored.'
        ],
        [ 'quiet!', 'Does not display unnecessary information.' ],
        [   'progress!',
            'May display dynamic progress indications. '
              . 'On by default. Use -noprogress to turn off.',
            1,
        ],
    );

    unshift @options, $module->OPTIONS($env) if $module->can('OPTIONS');

    while (@options) {
        my $option_r = shift(@options);
        add_option( @{$option_r} );
    }

    init_options();

    my %option = %{ Actium::Options::_optionhash() };

    $env->_set_options_r( \%option );

    if ( $option{'quiet'} ) {
        $crier->set_maxdepth(0);
    }

    if ( not $option{'progress'} ) {
        $crier->hide_progress;
    }
    if ( $option{'_stacktrace'} ) {
        ## no critic (RequireLocalizedPunctuationVars)
        $SIG{'__WARN__'} = \&_stacktrace;
        $SIG{'__DIE__'}  = \&_stacktrace;
        ## use critic
    }

} ## tidy end: sub _process_my_options

sub _stacktrace {
    Carp::confess(@_);
}

##### TERMINAL AND SIGNAL FUNCTIONS #####

sub _init_terminal {

    ## no critic (RequireLocalizedPunctuationVars)
    $SIG{'WINCH'} = \&_set_width;
    $SIG{'INT'}   = \&_terminate;
    ## use critic

    _set_width();

}

sub _terminate {
    my $signal = shift;
    $crier->text("Caught SIG$signal... Aborting program.");
    exit 1;
}

sub _set_width {
    my $width = _get_width();
    $crier->set_column_width($width);
}

sub _get_width {
    my $width = (
        eval {
            local ( $SIG{__DIE__} ) = 'IGNORE';
            ( Term::ReadKey::GetTerminalSize() )[0];

            # Ignore errors from GetTerminalSize
        }

          #or $Actium::Eclipse::is_under_eclipse ? 132 : 80
          or 80
    );
    return $width;
}

__END__

Documentation originally from Actium::Term

=over

=item B<output_usage>

This routine gets the help messages from B<Actium::Options::helpmessages()> 
and displays them in a pretty manner. It is intended to be used from HELP 
routines in modules.

Help messages of options beginning with underscores (e.g., -_stacktrace) 
are not displayed.
