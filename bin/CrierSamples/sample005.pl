#!/usr/bin/env perl 
use strict;
use warnings;
use Actium::Env::CLI::Crier;

our $VERSION = 0.005;

my $crier = Actium::Env::CLI::Crier::->new();

sub emit { $crier->cry(@_) }

{
    my $cry = emit "Watch the percentage climb";
    for ( 1 .. 10 ) {
        $cry->over( " " . ( $_ * 10 ) . "%" );
        select( undef, undef, undef, 0.100 );
    }
    $cry->over(q{});    # erase the percentage
    $cry->ok;
}

{
    my $cry = emit "Watch the dots move";
    for ( 1 .. 40 ) {
        $cry->prog( $_ % 10 ? '.' : ':' );
        select( undef, undef, undef, 0.100 );
    }
    $cry->ok;
}

{
    my $cry   = emit "Here's a spinner";
    my @spin = qw{| / - \\ | / - \\};
    for ( 1 .. 64 ) {
        $cry->over( $spin[ $_ % @spin ] );
        select( undef, undef, undef, 0.125 );
    }
    $cry->over;                                # remove spinner
    $cry->ok;
}
{
    my $cry = emit "Zig zags on parade";
    for ( 1 .. 200 ) {
        $cry->prog( $_ % 2 ? '/' : '\\' );
        select( undef, undef, undef, 0.025 );
    }
    $cry->ok;
}

{
    my $cry = emit "Making progress";
    for ( 1 .. 10 ) {
        $cry->over(" $_/10");
        select( undef, undef, undef, 0.100 );
    }
    $cry->ok;
}

{
    my $cry = emit "Engines on";
    for ( reverse( 1 .. 5 ) ) {
        $cry->prog(" $_ ");
        select( undef, undef, undef, 1.000 );
    }
    $cry->c("Gone!");
}

exit 0;
