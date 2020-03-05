package Actium::Env::CLI 0.012;
# vimcolor: #001326

# Amalgamation of Actium::Cmd, Actium::Env::CLIEnv, and the various
# Actium::Cmd::Config::* modules

use Actium ('class');

use Getopt::Long('GetOptionsFromArray');    ### DEP ###
use Term::ReadKey;                          ### DEP ###

use Actium::Env::CLI::Option;
use Actium::Env::CLI::Crier;
use Actium::Storage::Folder;
use Actium::Storage::File;
use Actium::Storage::Ini;
use Actium::Types (qw/Folder File/);
use Array::2D;
use Types::Standard(qw/Enum Int HashRef Maybe Str/);

use Module::Runtime ('require_module');

const my $EX_USAGE      => 64;      # from "man sysexits"
const my $EX_SOFTWARE   => 70;      # from "man sysexits"
const my $EX_SIGINT     => 130;     # from "Advanced BASH scripting guide"
const my $COMMAND_INFIX => 'Cmd';

const my $FALLBACK_WIDTH => 80;

const my %OPTION_PACKAGE_DISPATCH => ( map { $_ => ( '_' . $_ . '_package' ) }
      (qw/default actiumdb geonames signup newsignup signup_with_old/) );
# specifying more than one of the signup packages should give
# duplicate option errors

###########################
##### BUILDARGS AND BUILD

around BUILDARGS ( $orig, $class : slurpy %params ) {
    # the BUILDARGS removes the subcommand from argv,
    # and also handles "help" or "manual" if they come before the subcommand

    $params{argv} //= [@ARGV];

    my @argv = @{ $params{argv} };

    ## no critic (RequireExplicitInclusion, RequireLocalizedPunctuationVars)
    {    # scoping for "no warnings"
        no warnings('once');
        if ( ( not @argv ) and $Actium::Eclipse::is_under_eclipse ) {
            @argv = Actium::Eclipse::get_command_line();
        }
    }
    ## use critic

    my ( $help_type, $subcommand );

    my @new_argv;

    while (@argv) {
        my $arg = shift @argv;
        if ( $arg =~ /-?help/i ) {
            $help_type ||= 'help';
            next;
        }
        elsif ( $arg =~ /-?man(ual)/i ) {
            $help_type = 'manual';
            next;
        }
        if ( $arg !~ /\A -/sx ) {
            $subcommand = $arg;
            push @new_argv, @argv;
            last;    # stop after first command found
        }
        push @new_argv, $arg;

    }

    my %init_args = (
        %params,
        subcommand => $subcommand // $EMPTY,
        _help_type => $help_type // $EMPTY,
        argv       => \@new_argv,
    );

    return $class->$orig(%init_args);

}

method BUILD {
    # all actual work is done inside here
    Actium::_set_env($self);

    $self->_init_terminal();

    my $subcommand = $self->subcommand;
    if ( not $subcommand ) {
        if ( $self->_help_type eq 'manual' ) {
            exec 'perldoc', $self->commandpath;
            die "Can't execute perldoc: $!";
        }
        return $self->_mainhelp();
    }

    my $module = $self->module;

    if ( $self->_help_type eq 'manual' or $self->option('manual') ) {
        exec 'perldoc', $module;
        die "Can't execute perldoc: $!";
    }
    elsif ( $self->_help_type eq 'help' or $self->option('help') ) {
        if ( $module->can('HELP') ) {
            $module->HELP();
        }
        else {
            say STDERR "Help not implemented for " . $subcommand . ".";
        }
        $self->_output_usage();
    }
    else {
        $module->START();
    }

    # returns to main, which usually does nothing else and exits

}

#########################################
##### TERMINAL AND SIGNAL FUNCTIONS #####

method be_quiet {
    $self->crier->set_filter_above_level(0);
    $self->_set_option( 'quiet', 1 );
}

my $term_width_cr = sub {
    return (
        eval { ( Term::ReadKey::GetTerminalSize() )[0]; }
          or $FALLBACK_WIDTH
    );
};

method _init_terminal {
    $SIG{'WINCH'} = sub {
        $self->set_term_width( $term_width_cr->() );
    };
    $SIG{'INT'} = sub {
        my $signal = shift;
        $self->crier->_display_wail(
            text              => "Caught SIG$signal... Aborting program.",
            left_indent_cols  => 0,
            right_indent_cols => 0
        );
        exit $EX_SIGINT;
    };

    $self->set_term_width( $term_width_cr->() );
    return;

}

method prompt ($prompt, $hide) {

    require IO::Prompter;    ### DEP ###

    my $val;

    my $fh = $self->crier->fh;
    $self->crier->_ensure_start_of_line;

    my @filehandles = ( '-in' => *STDIN, '-out' => *{$fh} );

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

    return "$val";
    # stringify what would otherwise be a weird Contextual::Return value,
    # thank you Mr. Conway

}

#############
#### HELP

{
    const my $SUBCOMMAND_PADDING   => ( $SPACE x 2 );
    const my $SUBCOMMAND_SEPARATOR => ( $SPACE x 2 );

    method _mainhelp ( Str :$error = q[] , Int :$status = 0 ) {

        my $command = $self->command;

        my $helptext = $error ? "$error\n" : $EMPTY;
        $helptext .= "Subcommands available for $command:\n";

        my @subcommands = $self->_subcommand_names;

        my $width = $self->term_width() - 2;

        require Array::2D;
        ( undef, \my @lines ) = Array::2D->new_to_term_width(
            array     => \@subcommands,
            width     => $width,
            separator => ($SUBCOMMAND_SEPARATOR)
        );

        say STDERR $helptext, $SUBCOMMAND_PADDING,
          join( ( "\n" . $SUBCOMMAND_PADDING ), @lines )
          or die "Can't output help text: $OS_ERROR";

        exit $status;

    }
}

sub _output_usage {

    my $self = shift;

    my @objs = $self->_option_objs;

    my %description_of;
    foreach my $obj (@objs) {
        my $name = $obj->name;
        $description_of{$name} = $obj->description;
        $description_of{$_} = "Same as -$name" foreach $obj->aliases;
    }

    my $left_padding
      = 5 + Actium::max( map { length($_) } keys %description_of );
    # add one for the hyphen, plus four spaces

    say STDERR 'Options:';

    foreach my $name ( sort keys %description_of ) {
        next if $name =~ /\A_/s;
        my $displayname = sprintf '%*s -- ', $left_padding, "-$name";

        my $wrapped = Actium::u_wrap(
            $displayname . $description_of{$name},
            max_columns => $self->term_width,
            indent      => -$left_padding,
            addspace    => 1,
        );

        say STDERR $wrapped;

    }

    return;

}

#################################
## Public Attributes and builders

has home_folder => (
    isa     => Folder,
    is      => 'ro',
    coerce  => 1,
    default => sub { Actium::Storage::Folder->home },
);

has config => (
    is      => 'ro',
    isa     => 'Actium::Storage::Ini',
    builder => '_build_config',
    lazy    => 1,
);

sub _build_config {
    my $self       = shift;
    my $systemname = $self->system_name;
    my $config     = Actium::Storage::Ini::->new(
        $self->home_folder->file(".$systemname.ini") );
    return $config;
}

has bin => (
    isa     => Folder,
    is      => 'ro',
    default => sub {
        no warnings 'once';
        require FindBin;    ### DEP ###
        Actium::Storage::Folder->new($FindBin::Bin);
    },
    coerce => 1,
);

has commandpath => (
    isa      => File,
    is       => 'ro',
    required => 1,
    # I vaguely recall checking and seeing that  if $0 is put here,
    # it will refer to the module name, CLI.pm. I'm not 100% sure though
    coerce => 1,
);

has subcommand => (
    isa     => 'Str',
    is      => 'ro',
    default => $EMPTY,
);

has system_name => (
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

    my $referred;
    while ( exists( $subcommands{$subcommand} )
        and Actium::is_ref( $subcommands{$subcommand} ) )
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
    # _mainhelp exits, and does not return
    #
    my $module = ucfirst( $self->system_name ) . '::'
      . "${COMMAND_INFIX}::$subcommands{$subcommand}";
    require_module($module)
      or die " Couldn't load module $module: $OS_ERROR";
    return $module;

}

has crier => (
    is      => 'ro',
    default => sub { Actium::Env::CLI::Crier->new() },
    isa     => 'Actium::Env::CLI::Crier',
    handles => [qw(cry last_cry wail)],
);

has command => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_command',
);

sub _build_command {
    my $self = shift;
    my ( $basename, $ext ) = $self->commandpath->basename_ext;
    return $basename;
}

has sysenv_r => (
    traits  => ['Hash'],
    isa     => HashRef [Str],
    is      => 'bare',
    default => sub {
        my @x = %ENV;
        return {@x};
    },
    handles  => { sysenv => 'get', },
    init_arg => 'sysenv',
);

has argv_r => (
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    is       => 'bare',
    writer   => '_set_argv_r',
    default  => sub { [] },
    init_arg => 'argv',
    handles  => { argv => 'elements', argv_idx => 'get', },
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

has term_width => (
    is      => 'rw',
    isa     => Int,
    default => $FALLBACK_WIDTH,
);

after set_term_width { $self->crier->set_column_width( $self->term_width ) }

sub _build_options {
    my $self = shift;
    my @objs = $self->_option_objs;

    my @option_specs;
    my %options;

    foreach my $obj (@objs) {
        push @option_specs, $obj->spec unless $obj->no_command;
    }

    my @argv = $self->argv;

    my $returnvalue = GetOptionsFromArray( \@argv, \%options, @option_specs );
    unless ($returnvalue) {
        say STDERR "Error parsing command-line options.\n";
        %options = ( help => 1 );
    }

    foreach my $obj (@objs) {
        if ( defined $obj->default ) {
            $options{ $obj->name } //= $obj->default;
        }
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
                my $prompt = $obj->prompt;
                $prompt = $obj->description if $prompt eq '1';
                $prompt = $obj->prompt =~ s/:*\z/:/r;
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

}

##########################################################
## Private attributes (used in processing options, etc.)

has _help_type => (
    isa => Enum [ $EMPTY, qw/help manual/ ],
    is => 'ro',
);

# used when help found in BUILDARGS -- it's not set if an option is used, e.g.,
# actium.pl subocommand -help

has _subcommands_r => (
    traits   => ['Hash'],
    isa      => 'HashRef[Str|ScalarRef[Str]]',
    is       => 'ro',
    required => 1,
    init_arg => 'subcommands',
    handles  => { _subcommands => 'keys' },
);

sub _subcommand_names {
    my $self = shift;
    \my %subcommands = $self->_subcommands_r;

    my @subcommands = grep { not Actium::is_ref( $subcommands{$_} ) }
      keys %subcommands;
    @subcommands = sort ( @subcommands, qw/help manual/ );
    return @subcommands;

}

has _option_obj_r => (
    traits  => ['Hash'],
    isa     => 'HashRef[Actium::Env::CLI::Option]',
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

        if ( Actium::is_hashref($optionspec) ) {
            $optionspec->{order} = $count++;
            push @opt_objs, Actium::Env::CLI::Option->new($optionspec);
        }
        # old arrayref should be rewritten as
        # { spec => , description  =>, fallback => ... }
        # or { $spec => , description => , callback => }, depending
        elsif ( Actium::is_arrayref($optionspec) ) {
            croak "Internal error: disallowed arrayref option specfication";
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
    }

    Actium::immut;
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

}

#######################
### OPTION PACKAGES

# I gave much thought as to whether most of these option packages should be set
# in the modules that use them instead of here -- e.g., should the one for
# actiumdb actually be included in Actium::Storage::DB? I've gone back and
# forth on it, but in order to make sure that any duplicate options are caught,
# I decided to leave them here.

sub _default_package {

    my $self = shift;

    return (
        {   spec        => 'help|?',
            description => 'Displays this help message',
        },
        {   spec        => 'manual',
            description => 'Displays the full manual for the command',
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
            fallback       => 0,
            callback => sub { $self->crier->filter_above_level(0) if $_[0] },
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
            fallback       => 1,
            description    => 'May display dynamic progress indications. '
              . 'On by default. Use -noprogress to turn off',
            callback => sub { $self->crier->hide_progress unless $_[0] },
        },

    );

}

### ActiumDB package
#my $DBCLASS  = "Actium::Storage::DB";
my $DBCLASS = "Octium::O::Files::ActiumDB";

sub _actiumdb_package {

    my $self = shift;

    require_module $DBCLASS;

    has actiumdb => (
        is      => 'ro',
        builder => '_build_actiumdb',
        isa     => $DBCLASS,
        lazy    => 1,
    );

    return (
        {   spec           => 'db_user=s',
            config_section => 'ActiumDB',
            config_key     => 'db_user',
            envvar         => 'DB_USER',
            description    => 'User name to access Actium database',
            prompt         => 1,
        },
        {   spec           => 'db_password=s',
            description    => 'Password to access Actium database',
            config_section => 'ActiumDB',
            config_key     => 'db_password',
            envvar         => 'DB_PASSWORD',
            description    => 'Password to access Actium database',
            prompt         => 1,
            prompthide     => 1,
        },
        {   spec            => 'db_name=s',
            description     => 'Name of the database in the ODBC driver',
            display_default => 1,
            config_section  => 'ActiumDB',
            config_key      => 'db_name',
            envvar          => 'DB_NAME',
            fallback        => 'ActiumDB',
        }
    );

}

sub _build_actiumdb {
    my $self = shift;

    my $actiumdb
      = $DBCLASS->new( map { $_ => $self->option($_) }
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

    require Octium::O::Folders::Signup;

    has signup => (
        is      => 'ro',
        builder => ( $is_new ? '_build_newsignup' : '_build_signup' ),
        isa     => 'Octium::O::Folders::Signup',
        lazy    => 1,
    );

    return (
        {   spec        => 'base=s',
            description => 'Base folder (normally [something]/Actium/signups)',
            display_default => 1,
            fallback        => $self->bin->parent->subfolder('signups'),
            envvar          => 'BASE',
            config_section  => 'Signup',
            config_key      => 'base',
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
    );
}

sub _signup_with_old_package {
    my $self = shift;

    my @signup_specs = $self->_signup_package;

    has oldsignup => (
        is      => 'ro',
        builder => '_build_oldsignup',
        isa     => 'Actium::Signup',
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
}

method _build_newsignup {
    return Octium::O::Folders::Signup::->new(
        is_new => 1,
        base   => $self->option('base'),
        signup => $self->option('signup')
    );
}

method _build_signup {
    return Octium::O::Folders::Signup->new(
        base   => $self->option('base'),
        signup => $self->option('signup')
    );
}

method _build_oldsignup {
    return Octium::O::Folders::Signup->new(
        base   => ( $self->option('oldbase') // $self->option('base') ),
        signup => $self->option('oldsignup'),
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

}

sub _build_geonames_username {
    my $self = shift;
    return $self->option('geonames_username');
}

1;

__END__

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011-2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * 

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item * 

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

