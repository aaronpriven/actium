# Actium/Cmd.pm - command-line access to Actium system

package Actium::Cmd 0.010;

use Actium::Preamble;

use Actium::Options qw(add_option init_options option);

# eventually merge that into this module

use Actium::O::Files::Ini;
my $config = Actium::O::Files::Ini::->new('.actium.ini');

# Ask user for a command line, if running under Eclipse.

sub run {

    \my %module_of = shift;

    my $config = Actium::O::Files::Ini::->new('.actium.ini');

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
        print mainhelp() or die "Can't print help text: $OS_ERROR";
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
        print "Unrecognized subcommand $subcommand.\n\n" . mainhelp(\%module_of)
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

    unshift @options, $module->OPTIONS if $module->can('OPTIONS');

    while (@options) {
        my $option_r = shift(@options);
        add_option( @{$option_r} );
    }

    init_options();

    my $options_r = Actium::Options::_optionhash();

    if ( option('_stacktrace') ) {
## no critic (RequireLocalizedPunctuationVars)
        $SIG{'__WARN__'} = \&stacktrace;
        $SIG{'__DIE__'}  = \&stacktrace;
    }

    if ( $help or option('help') ) {
        $module->HELP(@ARGV);
    }
    else {
        $module->START(
            options => $options_r,
            argv    => [@ARGV],
            config  => $config
        );
    }

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

1;

__END__
