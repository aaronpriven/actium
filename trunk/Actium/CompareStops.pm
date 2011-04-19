# /Actium/CompareStops.pm

# Takes the old and new stops and produces comparison lists.

# Subversion: $Id$

# Legacy status: 4 (still in progress...)

use 5.012;
use warnings;

package Actium::CompareStops 0.001;

use Carp;
use English ('-no_match_vars');

use Actium::Sorting(qw<travelsort>);
use Actium::Constants;
use Actium::Term ('output_usage');
use Actium::Options (qw<add_option option>);
use Actium::Signup;

use Algorithm::Diff;

use Actium::Patterns::Stop;

add_option( 'oldsignup', 'Previous signup to compare this signup to' );

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium comparestops -- compare stops from old to new signups

Usage:

actium comparestops -oldsignup f10 -signup sp11

Compares stops in the specified signups,
producing lists of compared stops in /compare in the new signup.

/compare/comparestops.txt is a simple list of stops.

/compare/comparestopstravel.txt is the same list, ordered by travel routes

HELP

    output_usage();
    return;

} ## tidy end: sub HELP

sub START {

    my $newsignup = Actium::Signup->new();
    my $oldsignup = Actium::Signup->new( { signup => option('oldsignup') } );

    my ( $changes_r, $stops_of_change_r )
      = compare_stops( $oldsignup, $newsignup );

    return;

}

sub compare_stops {

    my ( $oldsignup, $newsignup ) = shift;

    my $oldpatternfolder = $oldsignup->subfolder('pattern');
    my $newpatternfolder = $newsignup->subfolder('pattern');

    my %old_stop_of = %{ $oldpatternfolder->retrieve('stops.storable') };
    my %new_stop_of = %{ $oldpatternfolder->retrieve('stops.storable') };

    my @stopids = uniq( sort ( keys %new_stop_of, keys %old_stop_of ) );

    my ( %changes_of, %stops_of_change );

  STOPID:
    foreach my $stopid (@stopids) {

        my @oldroutes = sort $old_stop_of{$stopid}->routes;
        my @newroutes = sort $new_stop_of{$stopid}->routes;

        next STOPID if ( "@oldroutes" eq "@newroutes" );
        # no changes

        my $result;

        if ( not exists $old_stop_of{$stopid} ) {
            $result = { '?' => 'AS', q{+} => \@newroutes };
        }
        elsif ( not exists $new_stop_of{$stopid} ) {
            $result = { '?' => 'RS', q{-} => \@oldroutes };
        }
        else {
            $result = compare_stop( \@oldroutes, \@newroutes );
        }

        push @{ $stops_of_change{ $result->{'?'} } }, $stopid;
        $changes_of{$stopid} = $result;

    } ## tidy end: foreach my $stopid (@stopids)

    return \%changes_of, \%stops_of_change;

} ## tidy end: sub compare_stops

sub compare_stop {
    my $oldroutes_r = shift;
    my $newroutes_r = shift;

    my ( @added, @removed, @unchanged );

    my $result_r = {};

  COMPONENT:
    foreach
      my $component ( Algorithm::Diff::sdiff( $oldroutes_r, $newroutes_r ) )
    {

        my ( $action, $a_elem, $b_elem ) = @{$component};

        if ( $action eq 'u' ) {
            push @unchanged, $a_elem;
        }

        if ( $action eq 'c' or $action eq q{-} ) {
            push @removed, $a_elem;
        }

        if ( $action eq 'c' or $action eq q{+} ) {
            push @added, $b_elem;
        }

    }    # COMPONENT

    my $result;

    if ( not @removed ) {
        $result = 'AL';
    }
    elsif ( not @added ) {
        $result = 'RL';
    }
    else {
        $result = 'CL';
    }

    my %results = (
        '?'  => $result,
        q{+} => \@added,
        q{-} => \@removed,
        q{=} => \@unchanged,
    );

    return \%results;

} ## tidy end: sub compare_stop

1;

__END__

