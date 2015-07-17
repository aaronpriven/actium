package Actium::Cmd::Config::Signup 0.010;

use Actium::Preamble;
use File::Spec;
use Actium::O::Folders::Signup;

use Sub::Exporter ( -setup => { exports => [qw(signup oldsignup)] } );
# Sub::Exporter ### DEP ###

const my $BASE_ENV      => 'ACTIUM_BASE';
const my $SIGNUP_ENV    => 'ACTIUM_SIGNUP';
const my $OLDSIGNUP_ENV => 'ACTIUM_OLDSIGNUP';
const my $OLDBASE_ENV   => 'ACTIUM_OLDBASE';
const my $CACHE_ENV     => 'ACTIUM_CACHE';

my %defaults;

const my $CONFIG_SECTION => 'Signup';

sub build_defaults {
    return if %defaults;    # already built

    my $env        = shift;
    my $config_obj = $env->config;
    my %config     = $config_obj->section($CONFIG_SECTION);

    my $last_resort_base
      = File::Spec->catdir( $env->bin->path, File::Spec->updir(), 'signups' );

    $defaults{BASE}
      = ( $env->sysenv($BASE_ENV) // $config{Base} // $last_resort_base );

    $defaults{SIGNUP}
      = ( $env->sysenv($SIGNUP_ENV) // $config{Signup} );

    $defaults{OLDSIGNUP}
      = ( $env->sysenv($OLDSIGNUP_ENV) // $config{OldSignup} );

    $defaults{OLDBASE}
      = ( $env->sysenv($OLDBASE_ENV) // $config{OldBase} // $defaults{BASE} );

    $defaults{CACHE} = $env->sysenv($CACHE_ENV);
    return;

} ## tidy end: sub build_defaults

sub options {
    my $env = shift;
    build_defaults($env);

    my $signup_default_text
      = $defaults{SIGNUP} eq $EMPTY_STR
      ? $EMPTY_STR
      : qq< If not specified, will use "$defaults{SIGNUP}">;

    return (
        [   'base=s',
            'Base folder (normally [something]/Actium/signups). '
              . qq<If not specified, will use "$defaults{BASE}">
        ],
        [   'signup=s',
            'Signup. This is the subfolder under the base folder. Typically '
              . qq<something like "f08" (meaning Fall 2008). >
              . $signup_default_text
        ],
        [   'cache=s',
            'Cache folder. Files (like SQLite files) that cannot be stored '
              . 'on network filesystems are stored here. Defaults to the '
              . 'location of the files being cached.'
        ],
    );
} ## tidy end: sub options

sub options_with_old {
    my %params = @_;
    build_defaults(%params);

    my $oldsignup_default_text
      = $defaults{OLDSIGNUP} eq $EMPTY_STR
      ? $EMPTY_STR
      : qq< If not specified, will use "$defaults{OLDSIGNUP}">;

    return (
        options(@_),
        [   'oldsignup=s',
            'The older signup, to be compared with the current signup.'
              . $oldsignup_default_text,
        ],
        [   'oldbase=s',
            'The base folder to be used for the older signup.'
              . qq< If not specified, will use "$defaults{OLDBASE}">,
        ],

    );
} ## tidy end: sub options_with_old

sub signup {
    my ( $env, $first_argument, @rest ) = @_;

    my %params;
    if ( ref($first_argument) eq 'HASH' ) {
        \%params = $first_argument;
    }
    elsif ( defined($first_argument) ) {
        \%params = { subfolders => [ $first_argument, @rest ] };
    }

    $params{base}   //= ( $env->option('base')   // $defaults{BASE} );
    $params{signup} //= ( $env->option('signup') // $defaults{SIGNUP} );
    
    if (not defined $params{signup}) {
        croak "No signup specified.";
    }

    return Actium::O::Folders::Signup->new(%params);

}

sub oldsignup {

    my ( $env, $first_argument, @rest ) = @_;

    my %params;
    if ( ref($first_argument) eq 'HASH' ) {
        \%params = $first_argument;
    }
    elsif ( defined($first_argument) ) {
        \%params = { subfolders => [ $first_argument, @rest ] };
    }

    $params{base}   //= ( $env->option('oldbase')   // $defaults{OLDBASE} );
    $params{signup} //= ( $env->option('oldsignup') // $defaults{OLDSIGNUP} );
    
    if (not defined $params{signup}) {
        croak "No old signup specified.";
    }
    return Actium::O::Folders::Signup->new(%params);

}

1;
