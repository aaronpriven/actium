# /Actium/Cmd/AddDescriptionF.pm

# Adds the DescriptionF from the XML file to a stop list given, so that
# <stopid>\t<arbitrarytext>
# turns to
# <stopid>\t<DescriptionF>\t<arbitrarytext>

# Subversion: $Id$

# Legacy status: well, 4, but not necessarily intended as a permanent thing

package Actium::Cmd::AddDescriptionF 0.005;

use 5.012;
use warnings;

use autodie;

use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Term;

sub HELP { say "Help not implemented"; }

sub START {

    my $class  = shift;
    my %params = @_;

    my $config_obj = $params{config};

    my $signup   = Actium::O::Folders::Signup->new;
    my $actiumdb = actiumdb($config_obj);

    emit 'Getting stop descriptions from FileMaker';

    my $stops_row_of_r
      = $actiumdb->all_in_columns_key(qw/Stops_Neue c_description_full/);

    emit_done;

    my $file = shift @ARGV || '-';    # stdin

    open my $in, '<', $file;

    binmode STDOUT, ":utf8";

    while (<$in>) {
        chomp;

        my ( $stopid, $text ) = split( /\t/, $_, 2 );
        $text //= q[];
        my $desc = $stops_row_of_r->{$stopid}{c_description_full};
        if ( not defined $desc ) {
            if ( $stopid =~ /Stop\s*ID/i ) {
                $desc = "DescriptionCityF";
            }
            else {
                $desc = "** NOT FOUND **";
                warn "No description found for $stopid";
            }
        }
        say "$stopid\t$desc\t$text";

    }

} ## tidy end: sub START

1;
