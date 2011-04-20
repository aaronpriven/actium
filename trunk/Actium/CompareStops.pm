# /Actium/CompareStops.pm

# Takes the old and new stops and produces comparison lists.

# Subversion: $Id$

# Legacy status: 4 (still in progress...)

use 5.012;
use warnings;

package Actium::CompareStops 0.001;

use Carp;
use English ('-no_match_vars');

use Actium::Sorting(qw<sortbyline travelsort>);
use Actium::Constants;
use Actium::Term ('output_usage');
use Actium::Options (qw<add_option option>);
use Actium::Signup;
use Actium::Util (qw<jt jn>);

use Algorithm::Diff;

use Actium::Patterns::Stop;

use Readonly;

Readonly my $DEFAULT_SKIPLINES => '399,51S,BSH';

add_option( 'oldsignup', 'Previous signup to compare this signup to' );

Readonly my $SKIPLINES_DESC => <<"EOT";
Lines to skip during comparison. Separate lines with commas but without
spaces, e.g., -skiplines 40,M,382. The default is "$DEFAULT_SKIPLINES"
EOT

add_option( 'skiplines=s', $SKIPLINES_DESC,, $DEFAULT_SKIPLINES );

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

}    ## tidy end: sub HELP

sub START {

    my $newsignup = Actium::Signup->new();
    my $oldsignup = Actium::Signup->new( { signup => option('oldsignup') } );

    my $skipped_lines_r = [ split( /,/, option('skiplines') ) ];

    my $stops_row_of_r = get_xml_stops($newsignup);

    my %lines_of_stop =
      make_comparetext( $oldsignup, $newsignup, $stops_row_of_r,
        $skipped_lines_r );

    my @stopids = sort {
        lc( $stops_row_of_r->{$a}{CityF} ) cmp
          lc( $stops_row_of_r->{$b}{CityF} )
          or lc( $stops_row_of_r->{$a}{OnF} ) cmp
          lc( $stops_row_of_r->{$b}{OnF} )
          or lc( $stops_row_of_r->{$a}{AtF} ) cmp
          lc( $stops_row_of_r->{$b}{AtF} )
          or $a cmp $b
    } keys %lines_of_stop;

    my $compare_folder = $newsignup->subdir('compare');
    my $fh             = $compare_folder->open_write('comparestops.txt');
    say $fh comparetextline_headers();
    say $fh jn( @lines_of_stop{@stopids} );
    close $fh or die "Can't close comparestops.txt for writing: $OS_ERROR";

    return;

}

sub get_xml_stops {

    my $signup = shift;

    my $xml_db = $signup->load_xml;
    $xml_db->ensure_loaded('Stops');

    emit 'Getting stop descriptions from FileMaker export';
    my $dbh = $xml_db->dbh;

    my $stops_row_of_r =
      $xml_db->all_in_columns_key(qw/Stops CityF OnF AtF DescriptionCityF/);

    emit_done;

    return $stops_row_of_r;

}

sub compare_stops {

    my ( $oldsignup, $newsignup, $skipped_lines_r ) = shift;

    my %is_skipped;
    $is_skipped{$_} = 1 foreach @{$skipped_lines_r};

    my $oldpatternfolder = $oldsignup->subfolder('pattern');
    my $newpatternfolder = $newsignup->subfolder('pattern');

    my %old_stop_of = %{ $oldpatternfolder->retrieve('stops.storable') };
    my %new_stop_of = %{ $oldpatternfolder->retrieve('stops.storable') };

    my @stop_ids = uniq( sort ( keys %new_stop_of, keys %old_stop_of ) );

    my ( %changes_of, %stops_of_change );

  STOPID:
    foreach my $stop_ids (@stop_ids) {

        my @oldroutes = sort
          grep { not $is_skipped{$_} } $old_stop_of{$stop_ids}->routes;
        my @newroutes = sort

          grep { not $is_skipped{$_} } $new_stop_of{$stop_ids}->routes;

        next STOPID if ( "@oldroutes" eq "@newroutes" );

        # no changes

        my $result;

        if ( not exists $old_stop_of{$stop_ids} ) {
            $result = { '?' => 'AS', q{+} => \@newroutes };
        }
        elsif ( not exists $new_stop_of{$stop_ids} ) {
            $result = { '?' => 'RS', q{-} => \@oldroutes };
        }
        else {
            $result = compare_stop( \@oldroutes, \@newroutes );
        }

        push @{ $stops_of_change{ $result->{'?'} } }, $stop_ids;
        $changes_of{$stop_ids} = $result;

    }    ## tidy end: foreach my $stop_ids (@stop_ids)

    return \%changes_of, \%stops_of_change;

}    ## tidy end: sub compare_stops

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

}    ## tidy end: sub compare_stop

sub make_comparetext {
    my $oldsignup       = shift;
    my $newsignup       = shift;
    my $stops_row_of_r  = shift;
    my $skipped_lines_r = shift;

    my ( $changes_r, $stops_of_change_r ) =
      compare_stops( $oldsignup, $newsignup, $skipped_lines_r );

    my %text_of;

    while ( my ( $stop_id, $comparison_r ) = each %{$changes_r} ) {

        my @columns = (
            $comparison_r->{'?'}, $stop_id,
            $stops_row_of_r->{PhoneID}{DescriptionCityF}
        );

        foreach my $type (qw/+ - =/) {
            my @list = sortbyline @{ $comparison_r->{$type} };
            push @columns, scalar @list, "@list";
        }

        $text_of{$stop_id} = jt(@columns);
    }

    return \%text_of;

}

sub comparetextline_headers {
    my @columns = qw/Change Stop_ID Description
      NumAdded Added NumRemoved Removed NumUnchanged Unchanged/;
    return jt(@columns);

}

1;

__END__

