package Actium::Cmd::Scratch 0.010;

use Actium::Preamble;

# a place to test out small programs, in the Actium environment

sub OPTIONS {
    my ( $class, $env ) = @_;
    return ( qw/actiumdb signup/,
        [   'update',
            'Will only process signs that have the status "Needs Update."', 0
        ],
        [ 'type=s', 'Will only process signs that have a given signtype.', '' ],
    );
}

use Actium::O::DateTime;

sub START {
    my ( $class, $env ) = @_;
    say $env->option('update');
}

sub zSTART {
    my ( $class, $env ) = @_;
    

    my $actiumdb = $env->actiumdb;
    #my $signup   = $env->signup;

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
