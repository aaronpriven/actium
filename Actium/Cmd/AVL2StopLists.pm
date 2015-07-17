package Actium::Cmd::Avl2StopLists 0.010;

use Actium::Preamble;
# avl2stoplists - see POD documentation below

use sort ('stable');

# add the current program directory to list of files to include

use Carp;          ### DEP ###
use Storable();    ### DEP ###

use Actium::Union('ordered_union');
use Actium::DaysDirections ('dir_of_hasi');
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup ('signup');
use Actium::Term;

# don't buffer terminal output

sub HELP {

    my $helptext = <<'EOF';
avl2stoplists reads the data written by readavl and turns it into lists
of stops in order for each pattern and each route. These routes are stored in
the "slists" directory in the signup directory.
See "perldoc avl2stoplists" for more information.
EOF

    say $helptext;
    return;
}

sub OPTIONS {
    my ($class, $env) = @_;
    return (Actium::Cmd::Config::ActiumFM::OPTIONS($env), 
    Actium::Cmd::Config::Signup::options($env));
}

my $quiet;

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);

    $quiet = $env->option('quiet');

    my $signup = signup($env);
    chdir $signup->path();

    # retrieve data

    my $slistsfolder  = $signup->subfolder('slists');
    my $patfolder     = $slistsfolder->subfolder('pat');
    my $linefolder    = $slistsfolder->subfolder('line');
    my $linewinfolder = $slistsfolder->subfolder('line-win');

    my %pat;
    my %tps;

    my %stops;

    $actiumdb->load_tables(
        requests => {
            Stops_Neue => {
                hash        => \%stops,
                index_field => 'h_stp_511_id',
                fields      => [qw[h_stp_511_id c_description_full ]],
            },
        }
    );

    {                                                                  # scoping
# the reason to do this is to release the %avldata structure, so Affrus
# (or, presumably, another IDE)
# doesn't have to display it when it's not being used. Of course it saves memory, too

        my $avldata_r = $signup->retrieve('avl.storable');

        %pat = %{ $avldata_r->{PAT} };

    }

    my $count = 0;

    my %liststomerge;

  PAT:
    foreach my $key ( keys %pat ) {

        my $dir = $pat{$key}{DirectionValue};
        next unless dir_of_hasi($dir);
        $dir = dir_of_hasi($dir);

        my $route = $pat{$key}{Route};

        my $filekey;
        ( $filekey = $key ) =~ s/$KEY_SEPARATOR/-$dir-/g;

        open my $fh, '>:utf8', "slists/pat/$filekey.txt"
          or die "Cannot open slists/pat/$filekey.txt for output";

        unless ($quiet) {
            printf "%13s", $filekey;
            $count++;
            print "\n" unless $count % 6;
        }

        print $fh join( "\t",
            $route, $dir, $pat{$key}{Identifier},
            $pat{$key}{Via}, $pat{$key}{ViaDescription} );
        print $fh "\n";

        my @thesestops;

        foreach my $tps_r ( @{ $pat{$key}{TPS} } ) {
            my $stopid = $tps_r->{StopIdentifier};

            push @thesestops, $stopid;

            print $fh $stopid, "\t",
              $stops{$stopid}{c_description_full} // $EMPTY_STR, "\n";
        }

        push @{ $liststomerge{$route}{$dir} }, \@thesestops;

        close $fh;

    } ## tidy end: PAT: foreach my $key ( keys %pat)

    print "\n\n";

    $count = 0;

    my %stops_of_line;

    foreach my $route ( keys %liststomerge ) {
        foreach my $dir ( keys %{ $liststomerge{$route} } ) {

            unless ($quiet) {
                printf "%13s", "$route-$dir";
                $count++;
                print "\n" unless $count % 6;
            }

            my @union = @{ ordered_union( @{ $liststomerge{$route}{$dir} } ) };
            $stops_of_line{"$route-$dir"} = \@union;

            {
                open my $fh, '>:utf8', "slists/line/$route-$dir.txt"
                  or die "Cannot open slists/line/$route-$dir.txt for output";
                print $fh jt( $route, $dir ), "\n";
                foreach (@union) {

                    my $desc = $stops{$_}{c_description_full} // $EMPTY_STR;
                    #utf8::decode($desc);

                    print $fh "$_\t$desc\n";
                    #print $fh jt($_, $stops{$_}{c_description_full}) , "\n";
                }
                close $fh;
            }

            {
                open my $fh, '>:utf8', "slists/line-win/$route-$dir.txt"
                  or die
                  "Cannot open slists/line-win/$route-$dir.txt for output";
                print $fh jt( $route, $dir ), "\r\n";
                foreach (@union) {
                    print $fh jt( $_, $stops{$_}{c_description_full} ), "\r\n";
                }
                close $fh;
            }

        } ## tidy end: foreach my $dir ( keys %{ $liststomerge...})
    } ## tidy end: foreach my $route ( keys %liststomerge)

    print "\n\n";

    Storable::nstore( \%stops_of_line, "slists/line.storable" );

} ## tidy end: sub START

1;

=head1 NAME

avl2stoplists - Make stop lists by pattern and route from AVL files.

=head1 DESCRIPTION

avl2stoplists reads the data written by readavl and turns it into lists of 
stops by pattern and by route.  First it produces a list for each pattern 
(files in the form <route>-<direction>-<patternnum>.txt) and then one for 
each route (in the form <route>-<direction>.txt. Lists for each pattern are
merged using the Algorithm::Diff routine. 

=head1 AUTHOR

Aaron Priven

=cut

