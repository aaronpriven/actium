package Actium::Env::TestStub 0.014;

my $object = bless {}, 'Actium::Env::TestStub';

### crier stubs

sub cry { return $object }
sub new { return $object }

sub prog {return}
sub over {return}
sub wail {return}
sub done {return}
sub ok   {return}

sub system_name {'stub'}

### sysenv stubs

my %sysenv;

sub _t_set_sysenv {
    my $invocant = shift;
    %sysenv = (@_);
}

sub sysenv {
    my $invocant = shift;
    my $key      = shift;
    return $sysenv{$key};
}

### config stubs

my $config;

sub _t_set_config {
    my $invocant = shift;
    $config = shift;
}

sub config {$config}

1;
