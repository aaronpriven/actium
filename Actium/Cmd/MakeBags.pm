# /Actium/Cmd/MakeBags.pm
#
# Makes service change bag decals

package Actium::Cmd::MakeBags 0.010;

use Actium::Preamble;
use Actium::Bags;
use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Util('tabulate');

sub HELP {
    say 'Help not implemented.';
    return;
}

sub OPTIONS {
    return ( Actium::Cmd::Config::ActiumFM::OPTIONS(),
        [ 'oldsignup=s', 'Previous signup to compare this signup to' ] );
}

sub START {

    my ( $class, $env ) = @_;
    my $config_obj = $env->config;

    my $oldsignup_option = $env->option('oldsignup');
    die 'No oldsignup option specified' unless $oldsignup_option;

    my $signup = Actium::O::Folders::Signup->new();
    my $oldsignup
      = Actium::O::Folders::Signup->new( { signup => $oldsignup_option } );
    my $actium_db = actiumdb($env);

    my ( $bagtexts_r, $baglist_r, $counts_r, $final_heights_r )
      = Actium::Bags::make_bags(
        signup    => $signup,
        oldsignup => $oldsignup,
        actium_db => $actium_db
      );

    my $bagtextdir = $signup->subfolder('bagtexts');

    $bagtextdir->write_files_from_hash( $bagtexts_r, 'service change bag',
        'txt' );

    my $baglist = Actium::Util::aoa2tsv($baglist_r);
    $bagtextdir->slurp_write( $baglist, 'baglist.txt' );

    my @counts_rs;
    foreach ( sort keys %{$counts_r} ) {
        push @counts_rs, [ $_, $counts_r->{$_} ];
    }
    say jn ( @{ tabulate(@counts_rs) } );

    say '---';
    my @heights_rs;
    foreach ( sort { $a <=> $b } keys %{$final_heights_r} ) {
        push @heights_rs, [ $_, $final_heights_r->{$_}{count} ];
    }
    say jn( @{ tabulate(@heights_rs) } );

    return;

} ## tidy end: sub START

1;

__END__
