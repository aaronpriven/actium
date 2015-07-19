package Actium::Crier 0.010;

use 5.022;
use warnings;

# Avoiding Actium::Preamble because that module will probably load this one

use Const::Fast;
use Carp;
use Module::Runtime ('require_module');

# Actium::O::Crier is require'd at runtime to avoid a circular dependency
# in Actium::Preamble, which is used by Actium::O::Crier.

const my $CRIERCLASS => 'Actium::O::Crier';

use Sub::Exporter -setup => {
    exports => [
        'cry',
        'cry_text',
        'default_crier' => \&_build_default_crier,
    ]
};
# Sub::Exporter ### DEP ###

my $default_crier;

sub _build_default_crier {
    my ( $class, $name, $arg ) = @_;

    require_module($CRIERCLASS);

    if ( defined $arg and scalar keys %{$arg} ) {
        if ($default_crier) {
            croak 'Arguments given in '
              . q{"use }
              . __PACKAGE__
              . q{ (default_crier => {args})"}
              . q{ but the default crier has already been initialized};
        }

        $default_crier = $CRIERCLASS->new($arg);
        return sub {
            return $default_crier;
        };
    }

    return sub {
        $default_crier = $CRIERCLASS->new()
          if not $default_crier;
        return $default_crier;
      }

} ## tidy end: sub _build_default_crier

sub cry {
    if ( not $default_crier ) {
        require_module($CRIERCLASS);
        $default_crier = $CRIERCLASS->new();
    }
    $default_crier->cry(@_);
}

sub cry_text {
    if ( not $default_crier ) {
        require_module($CRIERCLASS);
        $default_crier = $CRIERCLASS->new();
    }
    return $default_crier->text(@_);
}

1;

__END__
