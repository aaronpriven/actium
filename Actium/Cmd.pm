package Actium::Cmd 0.010;

use Actium::Preamble;
use Actium::O::CmdEnv;
use Actium::O::Crier ('default_crier');
use Text::Wrap; # for output_usage
use Actium::Term ('get_width');

use Actium::Options qw(add_option init_options option);

# eventually merge that into this module

# Ask user for a command line, if running under Eclipse.

sub run {
    
    my %params      = @_;
    my $system_name = $params{system_name};
    \my %module_of = $params{commands};

    {
        no warnings('once');
        ## no critic (RequireExplicitInclusion, RequireLocalizedPunctuationVars)
        if ($Actium::Eclipse::is_under_eclipse)
        {    ## no critic (ProhibitPackageVars)
            @ARGV = Actium::Eclipse::get_command_line();
            ## use critic
        }
    }

    # Someday, if I want to allow these to run as CGI, rather than
    # creating a separate actium.cgi I can find out whether it's in that
    # environment by checking whether $ENV{GATEWAY_INTERFACE} exists --
    # if so, we're under CGI. Cool.

    my $help       = 0;
    my $subcommand = shift(@ARGV);

    if ( not $subcommand or ( lc($subcommand) eq 'help' and ( @ARGV == 0 ) ) ) {
        print mainhelp(\%module_of) or die "Can't print help text: $OS_ERROR";
        exit 0;
    }

    if ( lc($subcommand) eq 'help' ) {
        $help       = 1;
        $subcommand = shift(@ARGV);
    }

    $subcommand = lc($subcommand);

    while ( exists( $module_of{$subcommand} )
        and defined( reftype( $module_of{$subcommand} ) ) )
    {
        $subcommand = ${ $module_of{$subcommand} };
    }
    if ( not exists $module_of{$subcommand} ) {
        print "Unrecognized subcommand $subcommand.\n\n"
          . mainhelp( \%module_of )
          or die "Can't print help text: $OS_ERROR";
        exit 1;
    }

    my $module = "Actium::Cmd::$module_of{$subcommand}";

    require_module($module) or die "Couldn't load module $module: $OS_ERROR";

    my @options = (
        [ 'help|?', 'Displays this help message.' ],
        [   '_stacktrace',
            'Provides lots of debugging information if there is an error. '
              . 'Best ignored.'
        ],
    );

    my $env = Actium::O::CmdEnv::->new(
        subcommand  => $subcommand,
        system_name => $system_name,
        #crier => default_crier(), # not working for some mysterious reason
        crier => Actium::O::Crier->new(),
    );

    unshift @options, $module->OPTIONS($env) if $module->can('OPTIONS');

    while (@options) {
        my $option_r = shift(@options);
        add_option( @{$option_r} );
    }

    init_options();

    ## no critic (ProtectPrivateSubs)

    $env->_set_options_r( Actium::Options::_optionhash() );
    $env->_set_argv_r( [@ARGV] );

    if ( option('_stacktrace') ) {
        ## no critic (RequireLocalizedPunctuationVars)
        $SIG{'__WARN__'} = \&stacktrace;
        $SIG{'__DIE__'}  = \&stacktrace;
        ## use critic
    }

    if ( $help or option('help') ) {
        if ( $module->can('HELP') ) {
            $module->HELP($env);
        }
        else {
            say "Help not implemented for $subcommand";
        }
    }
    else {
        $module->START($env);
    }
    
    output_usage();

    return;

} ## tidy end: sub run

sub mainhelp {
    \my %module_of = shift;

    my $helptext = "$PROGRAM_NAME subcommands available:\n\n";
    foreach my $subcommand ( sort keys %module_of ) {
        next if defined( reftype( $module_of{$subcommand} ) );
        $helptext .= "$subcommand\n";
    }

    return $helptext;

}

sub stacktrace {
    require Carp;    ### DEP ###
    Carp::confess(@_);
}

sub output_usage {

    my $messages_r = Actium::Options::helpmessages;

    say 'Options:'
      or carp "Can't output help text: $!";

    my $longest = 0;

    foreach my $option ( keys %{$messages_r} ) {
        $longest = length($option) if $longest < length($option);
    }

    $longest++;    # add one for the hyphen in front

    my $HANGING_INDENT_PADDING = 4;
    local ($Text::Wrap::columns) = get_width();

    foreach ( sort keys %{$messages_r} ) {
        next if /^_/;
        my $optionname = sprintf '%*s -- ', $longest, "-$_";

        say Text::Wrap::wrap (
            $EMPTY_STR,
            q[ ] x ( $longest + $HANGING_INDENT_PADDING ),
            $optionname . $messages_r->{$_}
        );

    }
    print "\n"
      or carp "Can't output help text: $!";

}    ## <perltidy> end sub output_usage
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


