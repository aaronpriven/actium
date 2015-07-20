# /Actium/Cmd/AddDescriptionF.pm

# Adds the DescriptionF from the XML file to a stop list given, so that
# <stopid>\t<arbitrarytext>
# turns to
# <stopid>\t<DescriptionF>\t<arbitrarytext>

# Legacy status: well, 4, but not necessarily intended as a permanent thing

package Actium::Cmd::AddDescriptionF 0.010;

use 5.012;
use warnings;

use autodie;

use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup ('signup');
use Actium::Crier;

sub OPTIONS {
    my ($class, $env) = @_;
    return (Actium::Cmd::Config::ActiumFM::OPTIONS($env), 
    Actium::Cmd::Config::Signup::options($env));
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);

    my $signup = signup($env);

    my $cry = cry( 'Getting stop descriptions from FileMaker');

    my $stops_row_of_r
      = $actiumdb->all_in_columns_key(qw/Stops_Neue c_description_full/);

    $cry->done;

    my $file = shift @ARGV || '-';    # stdin

    open my $in, '<', $file;

    binmode STDOUT, ':encoding(UTF-8)';

    while (<$in>) {
        chomp;

        my ( $stopid, $text ) = split( /\t/s, $_, 2 );
        $text //= q[];
        my $desc = $stops_row_of_r->{$stopid}{c_description_full};
        if ( not defined $desc ) {
            if ( $stopid =~ /Stop\s*ID/is ) {
                $desc = 'c_description_full';
            }
            else {
                $desc = '** NOT FOUND **';
                warn "No description found for $stopid";
            }
        }
        say "$stopid\t$desc\t$text";

    }

    return;

} ## tidy end: sub START

1;
