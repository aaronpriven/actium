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

use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Term;

sub HELP { say 'Help not implemented'; return; }

sub OPTIONS {
    return Actium::Cmd::Config::ActiumFM::OPTIONS();
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);

    my $signup = Actium::O::Folders::Signup->new;

    emit 'Getting stop descriptions from FileMaker';

    my $stops_row_of_r
      = $actiumdb->all_in_columns_key(qw/Stops_Neue c_description_full/);

    emit_done;

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
