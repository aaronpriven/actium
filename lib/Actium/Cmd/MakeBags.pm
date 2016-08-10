package Actium::Cmd::MakeBags 0.011;

# Makes service change bag decals

use Actium::Preamble;
use Actium::Bags;
use Actium::O::2DArray;

sub OPTIONS {
    return qw/actiumdb signup_with_old/;
}

sub START {

    my ( $class, $env ) = @_;
    my $config_obj = $env->config;

    my $signup    = $env->signup;
    my $oldsignup = $env->oldsignup;

    my $actium_db = $env->actiumdb;

    my ( $bagtexts_r, $baglist_r, $counts_r, $final_heights_r )
      = Actium::Bags::make_bags(
        signup    => $signup,
        oldsignup => $oldsignup,
        actium_db => $actium_db
      );

    my $bagtextdir = $signup->subfolder('bagtexts');

    $bagtextdir->write_files_from_hash( $bagtexts_r, 'service change bag',
        'txt' );
    my $baglist = Actium::O::2DArray->tsv($baglist_r);
    #my $baglist = Actium::Util::aoa2tsv($baglist_r);

    $bagtextdir->slurp_write( $baglist, 'baglist.txt' );

    my @counts_rs;
    foreach ( sort keys %{$counts_r} ) {
        push @counts_rs, [ $_, $counts_r->{$_} ];
    }
    #say u::joinlf ( @{ u::tabulate(@counts_rs) } );
    say Actium::O::2DArray->tabulated(\@counts_rs);

    say '---';
    my @heights_rs;
    foreach ( sort { $a <=> $b } keys %{$final_heights_r} ) {
        push @heights_rs, [ $_, $final_heights_r->{$_}{count} ];
    }
    #say u::joinlf( @{ u::tabulate(@heights_rs) } );
    say Actium::O::2DArray->tabulated(\@heights_rs);

    return;

} ## tidy end: sub START

1;

__END__
