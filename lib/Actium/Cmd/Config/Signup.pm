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

    $defaults{CACHE} = $env->sysenv($CACHE_ENV);
    return;

} ## tidy end: sub build_defaults

sub options {
    my $env = shift;
    build_defaults($env);

    my $signup_default_text
      = ( not defined( $defaults{SIGNUP} ) or $defaults{SIGNUP} eq $EMPTY_STR )
      ? $EMPTY_STR
      : qq<. If not specified, will use "$defaults{SIGNUP}">;

    return (
        [   'base=s',
            'Base folder (normally [something]/Actium/signups). '
              . qq<If not specified, will use "$defaults{BASE}">
        ],
        [   'signup=s',
            'Signup. This is the subfolder under the base folder. Typically '
              . qq<something like "f08" (meaning Fall 2008)>
              . $signup_default_text
        ],
        [   'cache=s',
            'Cache folder. Files (like SQLite files) that cannot be stored '
              . 'on network filesystems are stored here. Defaults to the '
              . 'location of the files being cached'
        ],
    );
} ## tidy end: sub options

sub options_with_old {
    my $env = shift;
    build_defaults($env);

    my $oldsignup_default_text
      = (
        not defined( $defaults{OLDSIGNUP} )
          or $defaults{OLDSIGNUP} eq $EMPTY_STR
      )
      ? $EMPTY_STR
      : qq<. If not specified, will use "$defaults{OLDSIGNUP}">;

    return (
        options(@_),
        [   'oldsignup|o=s',
            'The older signup, to be compared with the current signup'
              . $oldsignup_default_text,
        ],
        [   'oldbase|ob=s',
            'The base folder to be used for the older signup.'
              . ' If not specified, will be the same as -base',
        ],

    );
} ## tidy end: sub options_with_old

sub signup {
    
    my $env = shift;
    
    \my %params = u::positional(\@_ , '@subfolders') ;
    #\my %params = _process_args(@_);

    $params{base}   //= ( $env->option('base')   // $defaults{BASE} );
    $params{signup} //= ( $env->option('signup') // $defaults{SIGNUP} );
    $params{cache}  //= ( $env->option('cache')  // $defaults{CACHE} );

    if ( not defined $params{signup} ) {
        croak 'No signup specified in ' . $env->subcommand;
    }

    return Actium::O::Folders::Signup::->new(%params);

} ## tidy end: sub signup

sub oldsignup {

    my $env = shift;
    \my %params = u::positional(\@_ , '@subfolders') ;

    #\my %params = _process_args(@_);

    $params{base} //= ( $env->option('oldbase') // $env->option('base')
          // $defaults{OLDBASE} );

    $params{signup} //= ( $env->option('oldsignup') // $defaults{OLDSIGNUP} );

    if ( not exists $params{cache} ) {
        my $cache = ( $env->option('cache') // $defaults{CACHE} );
        if ( defined $cache ) {
            $params{cache} = $cache;
        }
    }
    if ( not defined $params{signup} ) {
        croak 'No old signup specified in ' . $env->subcommand;
    }
    return Actium::O::Folders::Signup::->new(%params);

} ## tidy end: sub oldsignup

#sub _process_args {
#    my @args = @_;
#
#    my %params;
#    while ( u::reftype( $args[-1] ) eq 'HASH' ) {
#        my $theseparams = pop @args;
#        %params = ( %params, %{ $theseparams } );
#    }
#    
#    $params{subfolders} = u::flatten(@args);
#    return \%params;
#
#}

1;

__END__

Old documentation from Actium::O::Folders::Signup 

The base folder is specified as follows (in the following order of
precedence):

=over

=item *

In the "base" argument to the "signup" method call

=item *
In the command line with the "-base" option

=item *
By the environment variable "ACTIUM_BASE".

=back

If none of these are set, Actium::O::Folders::Signup uses
L<FindBin|FindBin> to find the folder where the script is running
(in the above example, /Actium/bin), and sets the base folder to
"signups" in the script folder's parent folder.  In other words,
it's something like "/Actium/bin/../signups". In the normal case
where the "bin" folder is in the same folder as the Actium data
this means it will all work fine without any specification of the
base folder. If not, then it will croak.

=item Signup folder

The data for each signup is stored in a subfolder of the base folder.
This folder is usually named after the period of time when the signup
becomes effective ("w08" meaning "Winter 2008", for example). 

The signup folder is specified as follows (in the following order of
precedence):

=over

=item *
In the "signup" argument to the "signup" method call

=item *
In the command line with the "-signup" option

=item *
By the environment variable "ACTIUM_SIGNUP".

=back

If none of these are present, then Actium::O::Folders::Signup 
will croak "No signup folder specified."

=head1 COMMAND-LINE OPTIONS AND ENVIRONMENT VARIABLES

=over

=item -base (option)

=item ACTIUM_BASE (environment variable)

These supply a base folder used when the calling program doesn't
specify one.

=item -signup (option)

=item ACTIUM_SIGNUP (environment variable)

These supply a signup folder used when the calling program doesn't
specify one.

=item -cache (option)

=item ACTIUM_CACHE (environment variable)

These supply a cache folder used when the calling program doesn't
specify one. See the method "cache" below.

=back
