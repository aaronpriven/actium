# /Actium/Cmd/MakeBags.pm
#
# Makes service change bag decals

package Actium::Cmd::MakeBags 0.010;

use Actium::Preamble;
use Actium::Bags;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup   (qw<signup oldsignup>);
use Actium::Util('tabulate');

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        Actium::Cmd::Config::Signup::options_with_old($env)
    );
}

sub START {

    my ( $class, $env ) = @_;
    my $config_obj = $env->config;

    my $signup    = signup($env);
    my $oldsignup = oldsignup($env);

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
