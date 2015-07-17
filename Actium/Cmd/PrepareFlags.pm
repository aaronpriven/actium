# Actium/Cmd/PrepareFlags.pm

# Prepare artwork so that flags are built

# legacy stage 4

package Actium::Cmd::PrepareFlags 0.010;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup   ('signup');
use Actium::Flags;
use Actium::Term;
use Actium::Util('file_ext');
use Actium::O::2DArray;

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        Actium::Cmd::Config::Signup::options($env),
    );
}

sub START {
    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);
    my @argv     = $env->argv;

    emit 'Creating flag assignments';

    my $input_file = shift @argv;
    my ( $output_file, @stopids );

    if ( defined $input_file ) {
        emit "Getting stop IDs from file $input_file";
        ( $output_file, undef ) = file_ext($input_file);
        $output_file .= '-assignments.txt';

        my $in_sheet = Actium::O::2DArray->new_from_file($input_file);
        @stopids = $in_sheet->col(0);
        @stopids = grep {/\A \d+ \z/sx} @stopids;
        emit_ok;
    }
    else {
        emit 'Getting stop IDs from database';
        emit_ok;
    }

    my $tabbed = Actium::Flags::flag_assignments_tabbed( $actiumdb, @stopids );

    unless ($tabbed) {
        emit_error;
        return;
    }

    if ( defined $output_file ) {
        require File::Slurp::Tiny;    ### DEP ###
        File::Slurp::Tiny::write_file( $output_file, $tabbed,
            binmode => ':utf8' );
    }
    else {
        my $signup = signup($env);
        $signup->slurp_write( $tabbed, 'flag_assignments.txt' );
    }

    emit_done;
    return;

} ## tidy end: sub START

1;

__END__
