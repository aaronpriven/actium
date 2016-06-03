package Actium::Cmd::Scratch 0.010;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup   (qw<signup oldsignup>);

# a place to test out small programs, in the Actium environment

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        Actium::Cmd::Config::Signup::options($env)
    );
}

use Actium::O::DateTime;

sub START {
    my ( $class, $env ) = @_;

    my $actiumdb = actiumdb($env);
    #my $signup   = signup($env);

    my $str = $actiumdb->agency_effective_date('ACTransit');
    say "String: $str";
    
    my @ymd = split(/-/ , $str);
    say "array: @ymd";
    
    my $dt = Actium::O::DateTime::->new(
        #datetime => $str,
        ymd => \@ymd,
        #pattern  => '%Y-%m-%d'
      )
      ;

    say '$dt->ymd is ' , $dt->ymd;
    
    say u::jointab ($dt->fulls);
    print "\n";
    say u::jointab ($dt->longs);

}

1;
