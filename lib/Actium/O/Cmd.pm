package Actium::O::Cmd 0.011;

# Amalgamation of Actium::Cmd, Actium::O::CmdEnv, and the various
# Actium::Cmd::Config::* modules

use Actium::Moose;

use Getopt::Long('GetOptionsFromArray');    ### DEP ###
use Term::ReadKey;                          ### DEP ###

use Actium::Crier('default_crier');
use Actium::O::Files::Ini;
use Actium::O::Cmd::Option;
use Actium::O::Folder;

const my $EX_USAGE       => 64;              # from "man sysexits"
const my $EX_SOFTWARE    => 70;
const my $COMMAND_PREFIX => 'Actium::Cmd';

const my $FALLBACK_COLUMNS     => 80;
const my $SUBCOMMAND_PADDING   => ( $SPACE x 2 );
const my $SUBCOMMAND_SEPARATOR => ( $SPACE x 2 );

const my %OPTION_PACKAGE_DISPATCH => ( map { $_ => ( '_' . $_ . '_package' ) }
      (qw/default actiumdb flickr geonames signup newsignup signup_with_old/) );
# specifying more than one of the signup packages should give
# duplicate option errors

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
            home_folder => { type => $PV_TYPE{SCALAR}, optional => 1 },
            bin         => { type => $PV_TYPE{SCALAR}, optional => 1 },
        }
    );

    if ( not defined $params{home_folder} ) {
        require File::HomeDir;    ### DEP ###
        $params{home_folder} = File::HomeDir->my_home;
    }
    if ( not defined $params{bin} ) {
        require FindBin;          ### DEP ###
        no warnings 'once';
        $params{bin} = $FindBin::Bin;
    }

    my @original_argv = @{ $params{argv} };

    ## no critic (RequireExplicitInclusion, RequireLocalizedPunctuationVars)
    {                             # scoping for "no warnings"
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
        bin             => Actium::O::Folder->new( $params{bin} ),
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
            say STDERR "Help not implemented for " . $self->subcommand . ".";
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

sub prompt {
    
    my $self = shift;

    require IO::Prompter;    ### DEP ###

    my $prompt = shift;
    my $hide   = shift;

    my $val;

    my $fh = $self->crier->fh;

    print $fh "\n" if ( $self->crier->position != 0 );

    my @filehandles = ( '-in' => *STDIN , '-out' => *{$fh} );

    #say $prompt;

    if ($hide) {
        $val = IO::Prompter::prompt(
            $prompt,
            -echo => '*',
            '-hNONE',
            @filehandles,
        );
    }
    else {
        $val = IO::Prompter::prompt( $prompt, @filehandles );
    }

    $self->crier->set_position(0);

    return "$val";
    # stringify what would otherwise be a weird Contextual::Return value,
    # thank you Mr. Conway

} ## tidy end: sub prompt

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

    require Text::Wrap;    ### DEP ###

    const my $HANGING_INDENT_PADDING => 4;
    ## no critic (Variables::ProhibitPackageVars)
    no warnings 'once';
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
    isa      => 'Actium::O::Folder',
    is       => 'ro',
    required => 1,
);

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
    handles  => { _original_argv => 'elements', },
);

has argv_r => (
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    is       => 'bare',
    writer   => '_set_argv_r',
    default  => sub { [] },
    init_arg => 'argv',
    handles  => { argv => 'elements', },
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
    my $self = shift;
    my @objs = $self->_option_objs;

    my @option_specs;
    my %options;

    foreach my $obj (@objs) {
        push @option_specs, $obj->spec unless $obj->no_command;
        if ( defined $obj->default ) {
            $options{ $obj->name } = $obj->default;
        }
    }
    
    my @argv = $self->argv;

    my $returnvalue = GetOptionsFromArray( \@argv, \%options, @option_specs );
    unless ($returnvalue) {
       say "Error parsing command-line options.\n---";
       %options = ( help => 1 );
    }
    $self->_set_argv_r( \@argv );
    # replace old argv with new one without options in it

    @objs = map { $_->[0] }
      sort { $a->[1] <=> $b->[1] }
      map { [ $_, $_->order ] } @objs;
    # sort options by order submitted, so the prompts come out reasonably
    
    return \%options if $options{help};
    # could be generalized to a "skip prompts" value, for 
    # manuals or other displays

    foreach my $obj (@objs) {
        my $name = $obj->name;

        if ( not exists $options{$name} ) {
            if ( $obj->fallback ) {
                $options{$name} = $obj->fallback;
            }
            elsif ( $obj->prompt ) {
                my $prompt = $obj->prompt =~ s/:*\z/:/r;
                # add a colon if it's not already there
                $options{$name} = $self->prompt( $prompt, $obj->prompthide );
            }
        }
    }
    
    foreach my $thisoption ( keys %options ) {
        my $callback = $self->_option_obj_of($thisoption)->callback;
        if ($callback) {
            $callback->( $options{$thisoption} );
        }
    }

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

    my $count = 0;

    my @opt_objs;
    while (@optionspecs) {
        my $optionspec = shift @optionspecs;

        if ( u::is_hashref($optionspec) ) {
            $optionspec->{cmdenv} = $self;
            $optionspec->{order}  = $count++;
            push @opt_objs, Actium::O::Cmd::Option->new($optionspec);
        }
        elsif ( u::is_arrayref($optionspec) ) {

            my ( $spec, $description, $callbackorfallback ) = @{$optionspec};

            my %option_init = (
                cmdenv      => $self,
                spec        => $spec,
                description => $description,
                order       => $count++
            );

            if ( defined $callbackorfallback ) {

                my $key
                  = u::is_coderef($callbackorfallback)
                  ? 'callback'
                  : 'fallback';
                $option_init{$key} = $callbackorfallback;
            }

            push @opt_objs, Actium::O::Cmd::Option->new( \%option_init );

        } ## tidy end: elsif ( u::is_arrayref($optionspec...))
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

    u::immut;
    # made immutable here, after any new attributes are made in dispatch
    # routines

    my %opt_obj_of;

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

#######################
### OPTION PACKAGES

sub _default_package {

    my $self = shift;

    return (
        {   spec        => 'help|?',
            description => 'Displays this help message',
        },
        {   spec        => '_stacktrace',
            description => 'Provides lots of debugging information if '
              . 'there is an error.  Best ignored',
            config_section => 'Debug',
            config_key     => 'stacktrace',
            envvar         => 'STACKTRACE',
            fallback       => 0,
            callback       => sub {
                if ( $_[0] ) {
                    $SIG{'__WARN__'} = sub { Carp::confess(@_) };
                    $SIG{'__DIE__'}  = sub { Carp::confess(@_) };
                }
            },
        },
        {   spec           => 'quiet!',
            envvar         => 'TERM_QUIET',
            config_section => 'Terminal',
            config_key     => 'quiet',
            description    => 'Does not display unnecessary information',
            callback       => sub { $self->crier->set_maxdepth(0) if $_[0] },
            fallback       => 0,
        },
        {   spec           => 'termcolor!',
            envvar         => 'TERM_COLOR',
            description    => 'May display colors in terminal output',
            config_section => 'Terminal',
            config_key     => 'color',
            fallback       => 0,
            callback       => sub { $self->crier->use_color if $_[0] },
        },
        {   spec           => 'progress!',
            envvar         => 'TERM_PROGRESS',
            config_section => 'Terminal',
            config_key     => 'progress',
            description    => 'May display dynamic progress indications. '
              . 'On by default. Use -noprogress to turn off',
            fallback => 1,
            callback => sub { $self->crier->hide_progress unless $_[0] },
        },

    );

} ## tidy end: sub _default_package

### ActiumDB package

sub _actiumdb_package {

    my $self = shift;

    require Actium::O::Files::ActiumDB;

    has actiumdb => (
        is      => 'ro',
        builder => '_build_actiumdb',
        isa     => 'Actium::O::Files::ActiumDB',
        lazy    => 1,
    );

    return (
        {   spec           => 'db_user=s',
            config_section => 'ActiumDB',
            config_key     => 'db_user',
            envvar         => 'DB_USER',
            description    => 'User name to access Actium database',
            prompt         => 'User name to access Actium database',
        },
        {   spec           => 'db_password=s',
            description    => 'Password to access Actium database',
            config_section => 'ActiumDB',
            config_key     => 'db_password',
            envvar         => 'DB_PASSWORD',
            description    => 'Password to access Actium database',
            prompt         => 'Password to access Actium database',
            prompthide     => 1,
        },
        {   spec            => 'db_name=s',
            description     => 'Name of the database in the ODBC driver. ',
            display_default => 1,
            config_section  => 'ActiumDB',
            config_key      => 'db_name',
            envvar          => 'DB_NAME',
            fallback        => 'ActiumDB',
        }
    );

} ## tidy end: sub _actiumdb_package

sub _build_actiumdb {
    my $self = shift;

    my $actiumdb
      = Actium::O::Files::ActiumDB::->new( map { $_ => $self->option($_) }
          qw /db_user db_password db_name/ );

    return $actiumdb;

}
#### Signup

sub _newsignup_package {

    my $self = shift;
    return $self->_signup_package(1);

}

sub _signup_package {

    my $self   = shift;
    my $is_new = shift;

    require Actium::O::Folders::Signup;

    has signup => (
        is      => 'ro',
        builder => ( $is_new ? '_build_newsignup' : '_build_signup' ),
        isa     => 'Actium::O::Folders::Signup',
        lazy    => 1,
    );

    require File::Spec;    ### DEP ###

    return (
        {   spec        => 'base=s',
            description => 'Base folder (normally [something]/Actium/signups)',
            display_default => 1,
            fallback        => File::Spec->catdir(
                $self->bin->path, File::Spec->updir(), 'signups'
            ),
            envvar         => 'BASE',
            config_section => 'Signup',
            config_key     => 'base',
        },
        {   spec => 'signup=s',
            description =>
              'Signup. This is the subfolder under the base folder. '
              . qq<Typically something like "f08" (meaning Fall 2008)>,
            envvar          => 'SIGNUP',
            config_section  => 'Signup',
            config_key      => 'signup',
            prompt          => 'Signup',
            display_default => 1,
        },
        {   spec => 'cache=s',
            description =>
              'Cache folder. Files (like SQLite files) that cannot '
              . 'be stored on network filesystems are stored here.',
            display_default => 1,
            fallback =>
              $self->home_folder->subfolder_path( '.' . $self->system_name ),
            envvar         => 'CACHE',
            config_section => 'Signup',
            config_key     => 'cache',
        },
    );
} ## tidy end: sub _signup_package

sub _signup_with_old_package {
    my $self = shift;

    my @signup_specs = $self->_signup_package;

    has oldsignup => (
        is      => 'ro',
        builder => '_build_oldsignup',
        isa     => 'Actium::O::Folders::Signup',
        lazy    => 1,
    );

    return (
        @signup_specs,
        {   spec => 'oldsignup|o=s',
            description =>
              'The older signup, to be compared with the current signup',
            display_default => 1,
            prompt          => 'Old signup',
            config_section  => 'Signup',
            config_key      => 'oldsignup',
            envvar          => 'OLDSIGNUP',
        },
        {   spec           => 'oldbase|ob=s',
            envvar         => 'OLDBASE',
            config_section => 'Signup',
            config_key     => 'oldbase',
            description    => 'The base folder to be used for the older signup.'
              . ' If not specified, will be the same as -base',
        },

    );
} ## tidy end: sub _signup_with_old_package

sub _build_newsignup {
    my $self = shift;
    my %params = map { $_ => $self->option($_) } qw/base signup cache/;
    return Actium::O::Folders::Signup::->new(%params);
}

sub _build_signup {
    my $self = shift;
    my %params = map { $_ => $self->option($_) } qw/base signup cache/;
    $params{must_exist} = 1;
    return Actium::O::Folders::Signup::->new(%params);
}

sub _build_oldsignup {
    my $self = shift;

    return Actium::O::Folders::Signup::->new(
        base => ( $self->option('oldbase') // $self->option('base') ),
        signup     => $self->option('oldsignup'),
        cache      => $self->option('cache'),
        must_exist => 1,
    );

}

### Geonames

sub _geonames_package {
    my $self = shift;

    has geonames_username => (
        is      => 'ro',
        builder => '_build_geonames_username',
        isa     => 'Str',
        lazy    => 1,
    );

    return {
        spec            => 'geonames_username=s',
        envvar          => 'GEONAMES_USERNAME',
        config_key      => 'username',
        config_section  => 'Geonames',
        display_default => 1,
        description     => 'Geonames API username',
        prompt          => 'Geonames API username',
    };

} ## tidy end: sub _geonames_package

sub _build_geonames_username {
    my $self = shift;
    return $self->option('geonames_username');
}

#### FLICKR

{
    const my %DESCRIPTION_OF_OPTION => (
        key    => 'Flickr API key',
        secret => 'Flickr API secret',
    );

    sub _flickr_package {
        my $self = shift;

        has flickr_auth => (
            is      => 'ro',
            isa     => 'Actium::O::Photos::Flickr::Auth',
            builder => '_build_flickr_auth',
            lazy    => 1,
        );

        my @optionlist;
        foreach my $optionname ( keys %DESCRIPTION_OF_OPTION ) {
            push @optionlist,
              { spec           => "flickr_${optionname}=s",
                envvar         => "FLICKR_$optionname",
                config_section => 'Flickr',
                config_key     => $optionname,
                description    => $DESCRIPTION_OF_OPTION{$optionname},
                prompt         => $DESCRIPTION_OF_OPTION{$optionname},
              };
        }

        return @optionlist;

    } ## tidy end: sub _flickr_package

    sub _build_flickr_auth {

        my $self = shift;
        my %params
          = map { $_ => $self->option($_) } keys %DESCRIPTION_OF_OPTION;
        return Actium::O::Photos::Flickr::Auth->new(%params);

    }

}

1;

