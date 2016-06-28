package Actium::O::Cmd 0.011;

# Amalgamation of Actium::Cmd, Actium::O::CmdEnv, and the various
# Actium::Cmd::Config::* modules

use Actium::Moose;
use FindBin (qw($Bin));
use Actium::O::Files::Ini;

use Getopt::Long('GetOptionsFromArray');    ### DEP ###
use Text::Wrap;                             ### DEP ###
use Term::ReadKey;                          ### DEP ###
use File::HomeDir;                          ### DEP ###

use Actium::Crier('default_crier');
use Actium::O::Cmd::Option;
use Actium::O::Folder;

const my $EX_USAGE       => 64;              # from "man sysexits"
const my $EX_SOFTWARE    => 70;
const my $COMMAND_PREFIX => 'Actium::Cmd';

const my $FALLBACK_COLUMNS     => 80;
const my $SUBCOMMAND_PADDING   => ( $SPACE x 2 );
const my $SUBCOMMAND_SEPARATOR => ( $SPACE x 2 );

const my %OPTION_PACKAGE_DISPATCH => ( map { $_ => ( '_' . $_ . '_package' ) }
      (qw/default actiumfm flickr signup geonames signup_with_old/) );

my $term_width_cr = sub {
    return (
        eval { ( Term::ReadKey::GetTerminalSize() )[0]; }
          or $FALLBACK_COLUMNS
    );
};

###############
##### BUILDARGS

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %params = u::validate(
        @_,
        {   system_name => { type => $PV_TYPE{SCALAR} },
            commandpath => { type => $PV_TYPE{SCALAR} },
            sysenv      => { type => $PV_TYPE{HASHREF}, default => {%ENV} },
            subcommands => { type => $PV_TYPE{HASHREF} },
            argv        => { type => $PV_TYPE{ARRAYREF}, default => [@ARGV] },
            home_folder =>
              { type => $PV_TYPE{SCALAR}, default => File::HomeDir->my_home },
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

    my @argv = @original_argv;    # intentional copy
    my ( $help_requested, $help_arg_index, $subcommand );

    if (@argv) {
        for my $i ( 0 .. $#argv ) {
            if ( $argv[$i] =~ /-?help/i ) {
                $help_requested = 1;
                $help_arg_index = $i;
                next;
            }
            if ( $argv[$i] !~ /\A -/sx ) {
                $subcommand = splice( @argv, $i, 1 );
                # remove subcommand from args
                last;    # stop after first command found
            }
        }
    }

    splice( @argv, $help_arg_index, 1 ) if $help_arg_index;
    # delete 'help' from args

    my %init_args = (
        %params{qw/sysenv system_name/},
        commandpath     => $params{commandpath},
        subcommand      => $subcommand // $EMPTY,
        _subcommands    => $params{subcommands},
        _original_argv  => \@original_argv,
        _help_requested => $help_requested,
        argv            => \@argv,
        home_folder     => Actium::O::Folder->new( $params{home_folder} ),
    );

    return $class->$orig(%init_args);

};

###############
#### BUILD

sub BUILD {
    my $self       = shift;
    my $subcommand = $self->subcommand;

    $self->_init_terminal();

    if ( not $subcommand ) {
        $self->_mainhelp();
    }

    my $module = $self->module;

    if ( $self->_help_requested or $self->option('help') ) {
        if ( $module->can('HELP') ) {
            $module->HELP($self);
        }
        else {
            say "Help not implemented for $self->subcommand.";
        }
        $self->_output_usage();
    }
    else {
        $module->START($self);
    }

} ## tidy end: sub BUILD

##### TERMINAL AND SIGNAL FUNCTIONS #####

sub be_quiet {
    my $self = shift;
    $self->crier->set_maxdepth(0);
    $self->_set_option( 'quiet', 1 );

}

sub _init_terminal {

    my $self = shift;

    $SIG{'WINCH'} = sub {
        $self->crier->set_column_width( $term_width_cr->() );
    };
    $SIG{'INT'} = sub {
        my $signal = shift;
        $self->crier->text("Caught SIG$signal... Aborting program.");
        exit 1;
    };

    $self->crier->set_column_width( $term_width_cr->() );
    return;

}

sub term_readline {

    my $self = shift;

    require IO::Prompter;    ### DEP ###

    my $prompt = shift;
    my $hide   = shift;

    my $val;

    print "\n";

    if ($hide) {
        $val = IO::Prompter::prompt(
            $prompt,
            -echo => '*',
            '-hNONE',
            '-stdio'
        );
    }
    else {
        $val = IO::Prompter::prompt( $prompt, '-stdio' );
    }

    $self->crier->set_position(0);

    return "$val";
    # stringify what would otherwise be a weird Contextual::Return value,
    # thank you Mr. Conway

} ## tidy end: sub term_readline

#############
#### HELP

sub _mainhelp {

    my $self = shift;

    my %params = u::validate(
        @_,
        {   error  => { type => $PV_TYPE{SCALAR}, default => $EMPTY },
            status => { type => $PV_TYPE{SCALAR}, default => 0 },
        }
    );

    #my $system_name = $self->system_name;
    my $command = $self->command;

    my $helptext = $params{error} ? "$params{error}\n" : $EMPTY;

    $helptext .= "Subcommands available for $command:\n";

    my @subcommands = $self->_subcommand_names;

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

    exit $params{status};

} ## tidy end: sub _mainhelp

sub _output_usage {

    my $self = shift;

    my @objs = $self->_option_objs;

    my %description_of;
    foreach my $obj (@objs) {
        my $name = $obj->name;
        $description_of{$name} = $obj->description;
        $description_of{$_} = "Same as -$name" foreach $obj->aliases;
    }

    my $longest = 1 + u::max( map { length($_) } keys %description_of );
    # add one for the hyphen

    say STDERR 'Options:';

    const my $HANGING_INDENT_PADDING => 4;
    ## no critic (Variables::ProhibitPackageVars)
    local ($Text::Wrap::columns) = $term_width_cr->();
    ## use critic

    foreach my $name ( sort keys %description_of ) {
        next if $name =~ /\A_/s;
        my $displayname = sprintf '%*s -- ', $longest, "-$name";

        say STDERR Text::Wrap::wrap(
            $EMPTY_STR,
            q[ ] x ( $longest + $HANGING_INDENT_PADDING ),
            $displayname . $description_of{$name}
        );

    }

    return;

}    ## <perltidy> end sub output_usage

#################################
## Public Attributes and builders

has home_folder => (
    isa      => 'Actium::O::Folder',
    is       => 'ro',
    required => 1,
);

has config => (
    is      => 'ro',
    isa     => 'Actium::O::Files::Ini',
    builder => '_build_config',
    lazy    => 1,
);

sub _build_config {
    my $self       = shift;
    my $systemname = $self->system_name;
    my $config     = Actium::O::Files::Ini::->new(".$systemname.ini");
    return $config;
}

has bin => (
    isa     => 'Actium::O::Folder',
    is      => 'ro',
    builder => '_build_bin',
    lazy    => 1,
);

sub _build_bin {
    require Actium::O::Folder;
    return Actium::O::Folder::->new($Bin);
}

has [qw/commandpath subcommand system_name/] => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has module => (
    isa     => 'Str',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_module',
);

sub _build_module {
    my $self       = shift;
    my $subcommand = $self->subcommand;

    \my %subcommands = $self->_subcommands_r;

    my $system_name = shift;

    my $referred;
    while ( exists( $subcommands{$subcommand} )
        and u::is_ref( $subcommands{$subcommand} ) )
    {
        $subcommand = ${ $subcommands{$subcommand} };
        $referred   = 1;
    }

    if ( not exists $subcommands{$subcommand} ) {
        if ($referred) {
            $self->_mainhelp(
                status => $EX_SOFTWARE,
                error  => "Internal error (bad reference) ' 
                      . 'in subcommand $subcommand."
            );
        }
        else {
            $self->_mainhelp(
                status => $EX_USAGE,
                error  => "Unrecognized subcommand $subcommand."
            );
        }
    }

    my $module = "${COMMAND_PREFIX}::$subcommands{$subcommand}";
    require_module($module) or die " Couldn't load module $module: $OS_ERROR";
    return $module;

} ## tidy end: sub _build_module

has crier => (
    is      => 'ro',
    default => sub { default_crier() },
    isa     => 'Actium::O::Crier',
    lazy    => 1,
);

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
    traits   => ['Hash'],
    isa      => 'HashRef[Str]',
    is       => 'bare',
    required => 1,
    handles  => { sysenv => 'get', },
    init_arg => 'sysenv',
);

has _original_argv_r => (
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    is       => 'bare',
    default  => sub { [] },
    init_arg => '_original_argv',
    handles  => {
        _original_argv     => 'elements',
        _original_argv_idx => 'get',
    },
);

has argv_r => (
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    is       => 'bare',
    writer   => '_set_argv_r',
    default  => sub { [] },
    init_arg => 'argv',
    handles  => {
        argv     => 'elements',
        argv_idx => 'get',
    },
);

has options_r => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    is      => 'bare',
    builder => '_build_options',
    lazy    => 1,
    handles => {
        option        => 'get',
        _set_option   => 'set',
        option_is_set => 'exists',
    },
);

sub _build_options {
    my $self         = shift;
    my @objs         = $self->_option_objs;
    my @option_specs = map { $_->spec } @objs;

    my @argv = $self->argv;

    my %options;
    my $returnvalue = GetOptionsFromArray( \@argv, \%options, @option_specs );
    die "Errors parsing command-line options.\n" unless $returnvalue;

    foreach my $thisoption ( keys %options ) {
        my $callback = $self->_option_obj_of($thisoption)->callback;
        if ($callback) {
            $callback->( $options{$thisoption} );
        }
    }

    $self->_set_argv_r( \@argv );
    # replace old argv with new one without options in it

    return \%options;

} ## tidy end: sub _build_options

##########################################################
## Private attributes (used in processing options, etc.)

has _help_requested => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0,
);

has _subcommands_r => (
    traits   => ['Hash'],
    isa      => 'HashRef[Str|ScalarRef[Str]]',
    is       => 'ro',
    required => 1,
    init_arg => '_subcommands',
    handles  => { _subcommands => 'keys' },
);

sub _subcommand_names {
    my $self = shift;
    \my %subcommands = $self->_subcommands_r;

    return (
        grep { not u::is_ref( $subcommands{$_} ) }
        sort keys %subcommands
    );
}

has _option_obj_r => (
    traits  => ['Hash'],
    isa     => 'HashRef[Actium::O::Cmd::Option]',
    is      => 'bare',
    lazy    => 1,
    builder => '_build_option_objs',
    handles => {
        _option_names  => 'keys',
        _option_obj_of => 'get',
        _option_objs   => 'values'
    },
);

sub _build_option_objs {

    my $self   = shift;
    my $module = $self->module;

    my @optionspecs = 'default';
    push @optionspecs, $module->OPTIONS($self) if $module->can('OPTIONS');

    my @opt_objs;
    while (@optionspecs) {
        my $optionspec = shift @optionspecs;

        if ( u::is_hashref($optionspec) ) {
            push @opt_objs, Actium::O::Cmd::Option->new($optionspec);
        }
        elsif ( u::is_arrayref($optionspec) ) {

            my ( $spec, $description, $callbackordefault ) = @{$optionspec};

            my %option_init = ( spec => $spec, description => $description );

            if ( defined $callbackordefault ) {

                my $key
                  = u::is_coderef($callbackordefault) ? 'callback' : 'default';
                $option_init{$key} = $callbackordefault;
            }

            push @opt_objs, Actium::O::Cmd::Option->( \%option_init );

        }
        else {
            # option package
            if ( not exists $OPTION_PACKAGE_DISPATCH{$optionspec} ) {
                croak(  'Internal error. Invalid option package '
                      . "$optionspec specified in "
                      . $self->module );
            }

            my $dispatch = $OPTION_PACKAGE_DISPATCH{$optionspec};
            unshift @optionspecs, $self->$dispatch;

        }
    } ## tidy end: while (@optionspecs)

    my ( %opt_obj_of, %opt_truename_of );

    for my $obj (@opt_objs) {
        my $name    = $obj->name;
        my @aliases = $obj->aliases;

        for my $this_name ( $name, @aliases ) {
            if ( exists $opt_obj_of{$this_name} ) {
                croak
                  "Internal error. Duplicate option $this_name specified in "
                  . $self->module;
            }
        }

        $opt_obj_of{$name} = $obj;

    }

    return \%opt_obj_of;

} ## tidy end: sub _build_option_objs

sub _default_package {

    my $self = shift;

    return (
        {   spec        => 'help|?',
            description => 'Displays this help message',
        },
        {   spec        => '_stacktrace',
            description => 'Provides lots of debugging information if '
              . 'there is an error.  Best ignored',
            callback => sub {
                if ( $_[0] ) {
                    $SIG{'__WARN__'} = sub { Carp::confess(@_) };
                    $SIG{'__DIE__'}  = sub { Carp::confess(@_) };
                }
            },
        },
        {   spec        => 'quiet!',
            description => 'Does not display unnecessary information',
            callback    => sub { $self->crier->set_maxdepth(0) if $_[0] }
        },
        {   spec        => 'termcolor!',
            description => 'May display colors in terminal output.',
            callback    => sub { $self->crier->use_color if $_[0] },
        },
        {   spec        => 'progress!',
            description => 'May display dynamic progress indications. '
              . 'On by default. Use -noprogress to turn off',
            default  => 1,
            callback => sub { $self->crier->hide_progress unless $_[0] },
        },

    );

} ## tidy end: sub _default_package

{

    my ( $default_dbname, %config );
    const my $CONFIG_SECTION => 'ActiumFM';

    sub _actiumfm_package {

        my $self   = shift;
        my %config = $self->config->config_obj->section($CONFIG_SECTION);

        require Actium::O::Files::ActiumFM;

        has actiumdb => (
            is      => 'ro',
            builder => '_build_actiumdb',
            isa     => 'Actium::O::Files::ActiumFM',
            lazy    => 1,
        );

        const my $DBNAME_ENV      => 'ACTIUM_DBNAME';
        const my $FALLBACK_DBNAME => 'ActiumFM';

        $default_dbname = $self->sysenv($DBNAME_ENV) // $config{db_name}
          // $FALLBACK_DBNAME;
        return (

            {   spec        => 'db_user=s',
                description => 'User name to access Actium database'
            },
            {   spec        => 'db_password=s',
                description => 'Password to access Actium database'
            },
            {   spec        => 'db_name=s',
                description => 'Name of the database in the ODBC driver. '
                  . qq[If not specified, will use "$default_dbname"],
                $default_dbname,
            }
        );

    } ## tidy end: sub _actiumfm_package

    sub _build_actiumdb {
        my $self = shift;

        my %params;
        foreach (qw(db_user db_password db_name)) {
            $params{$_} = $self->option($_) // $config{$_};
        }

        $params{db_user}
          //= $self->term_readline('User name to access Actium database:');

        $params{db_password}
          //= $self->term_readline( 'Password to access Actium database:', 1 );
        $params{db_name} //= $default_dbname;

        my $actium_db = Actium::O::Files::ActiumFM::->new(%params);
        return $actium_db;

    }

}

{

    const my $BASE_ENV      => 'ACTIUM_BASE';
    const my $SIGNUP_ENV    => 'ACTIUM_SIGNUP';
    const my $OLDSIGNUP_ENV => 'ACTIUM_OLDSIGNUP';
    const my $OLDBASE_ENV   => 'ACTIUM_OLDBASE';
    const my $CACHE_ENV     => 'ACTIUM_CACHE';

    my %defaults;
    my %config;

    const my $CONFIG_SECTION => 'Signup';

    sub _signup_package {

        my $self = shift;
        %config = $self->config->section($CONFIG_SECTION);

        require Actium::O::Folders::Signup;

        has signup => (
            is      => 'ro',
            builder => '_build_signup',
            isa     => 'Actium::O::Folders::Signup',
            lazy    => 1,
        );

        my $last_resort_base
          = File::Spec->catdir( $self->bin->path, File::Spec->updir(),
            'signups' );

        $defaults{BASE}
          = ( $self->sysenv($BASE_ENV) // $config{base} // $last_resort_base );

        $defaults{SIGNUP}
          = ( $self->sysenv($SIGNUP_ENV) // $config{signup} );

        $defaults{CACHE} = $self->sysenv($CACHE_ENV) // $config{cache}
          // $self->home_folder->subfolder_path( $self->system_name );

        my $signup_default_text
          = (
            not defined( $defaults{SIGNUP} )
              or $defaults{SIGNUP} eq $EMPTY_STR
          )
          ? $EMPTY_STR
          : qq<. If not specified, will use "$defaults{SIGNUP}">;
          
        my $cache_default_text = ' If not specified, will use ' . 
             qq{"$defaults{CACHE}"};
        
        #my $cache_default_text = ' If not specified, will use '
        #  . (
        #    defined( $defaults{CACHE} )
        #    ? qq{"$defaults{CACHE}"}
        #    : 'the location of the files being cached'
        #  );

        return (
            {   spec => 'base=s',
                description =>
                  'Base folder (normally [something]/Actium/signups). '
                  . qq<If not specified, will use "$defaults{BASE}">,
                default => $defaults{BASE},
            },
            {   spec => 'signup=s',
                description =>
                  'Signup. This is the subfolder under the base folder. '
                  . qq<Typically something like "f08" (meaning Fall 2008)>
                  . $signup_default_text,
                default => $defaults{SIGNUP},
            },
            {   spec => 'cache=s',
                description =>
                  'Cache folder. Files (like SQLite files) that cannot '
                  . 'be stored on network filesystems are stored here.'
                  . $cache_default_text,
                default => $defaults{CACHE},
            },
        );
    } ## tidy end: sub _signup_package

    sub _signup_with_old_package {
        my $self = shift;

        my %signup_specs = $self->_signup_package;

        has oldsignup => (
            is      => 'ro',
            builder => '_build_oldsignup',
            isa     => 'Actium::O::Folders::Signup',
            lazy    => 1,
        );

        $defaults{OLDSIGNUP}
          = ( $self->sysenv($OLDSIGNUP_ENV) // $config{oldsignup} );

        my $oldsignup_default_text
          = (
            not defined( $defaults{OLDSIGNUP} )
              or $defaults{OLDSIGNUP} eq $EMPTY_STR
          )
          ? $EMPTY_STR
          : qq<. If not specified, will use "$defaults{OLDSIGNUP}">;

        return (
            %signup_specs,
            {   spec => 'oldsignup|o=s',
                description =>
                  'The older signup, to be compared with the current signup'
                  . $oldsignup_default_text,
                default => $defaults{OLDSIGNUP},
            },
            {   spec => 'oldbase|ob=s',
                description =>
                  'The base folder to be used for the older signup.'
                  . ' If not specified, will be the same as -base',
            },

        );
    } ## tidy end: sub _signup_with_old_package

}

sub _build_signup {

    my $self = shift;

    if ( not defined $self->option('signup') ) {
        croak 'No signup specified in ' . $self->subcommand;
    }

    my %params = map { $_ => $self->option($_) } qw/base signup cache/;

    return Actium::O::Folders::Signup::->new(%params);

}

sub _build_oldsignup {

    my $self = shift;

    if ( not defined $self->option('signup') ) {
        croak 'No old signup specified in ' . $self->subcommand;
    }
    my %params = {
        base => ( $self->option('oldbase') // $self->option('base') ),
        signup => $self->option('oldsignup'),
        cache  => $self->option('cache'),
    };

    return Actium::O::Folders::Signup::->new(%params);

}

1;

__END__

Documentation from Actium::Options


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
