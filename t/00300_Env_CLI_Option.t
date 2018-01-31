use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;

use Test::More 0.98 tests => 13;

use constant AECO => 'Actium::Env::CLI::Option';

BEGIN {
    note "These are tests of Actium::Env::CLI::Option.";
    use_ok 'Actium::Env::CLI::Option';
}

use Actium::Env::TestStub;
use Actium;
Actium::_set_env( Actium::Env::TestStub->new() );

{
    # create config and sysenv stubs

    my %sysenv = ( STUB_THIRD => 'env_default', STUB_FIFTH => 'set_from_env' );
    env->_t_set_sysenv(%sysenv);

#<<<
my $ini = <<'EOT';
fourth = config_default
[sample]
fifth = set from config
key_with_underscores = whatever
15 = 15
[section2]
x%a = 15*3727
EOT
#>>>

    require Actium::Storage::File;
    require Actium::Storage::Ini;
    my $tempname = tempfilename('.ini');
    my $tempfile = Actium::Storage::File->new($tempname);
    $tempfile->spew_text($ini);
    my $config_obj = Actium::Storage::Ini->new($tempname);
    $tempfile->remove;
    env->_t_set_config($config_obj);

}

note 'First sample object';

{

    my $option1 = AECO->new(
        spec        => 'sample',
        description => 'Sample option',
        order       => 1
    );

    isa_ok( $option1, AECO, 'first sample object' );
    is( $option1->name, 'sample',
        'Name of first sample object is as expected' );
    is( $option1->description,
        'Sample option',
        'Description of first sample object is as expected'
    );
    is( $option1->order, 1, 'Order of first sample object is as expected' );

}

note 'Sample object with alias';

{

    my $option2 = AECO->new(
        spec        => 'second|alias|anotheralias',
        description => 'Sample with aliases',
        order       => 2
    );

    isa_ok( $option2, AECO, 'sample with aliases' );

    is $option2->name, 'second', 'name of sample with aliases is as expected';
    is_deeply(
        [ $option2->aliases ],
        [qw/alias anotheralias/],
        'aliases are as expected'
    );

}

note 'Option with environment variable default';

{
    my $option3 = AECO->new(
        spec        => 'third',
        description => 'option with environment variable default',
        order       => 3,
        envvar      => 'THIRD',
    );
    is( $option3->default, 'env_default',
        'environment variable default is as expected' );

}

note 'Option with config default';

{
    my $option = AECO->new(
        spec        => 'fourth',
        description => 'option with config default',
        order       => 4,
        config_key  => 'fourth',
        envvar      => 'FOURTH',
    );
    is( $option->default, 'config_default', 'config default is as expected' );

}

note 'Option with both envvar and config';

{
    my $option = AECO->new(
        spec           => 'fifth',
        description    => 'option with both envvar and config default',
        order          => 5,
        config_key     => 'fifth',
        config_section => 'sample',
        envvar         => 'FIFTH',
    );
    is( $option->default, 'set_from_env',
        'default with both envvar and config is as expected' );

}

note 'Option with fallback';
{
    my $option = AECO->new(
        spec           => 'sixth',
        description    => 'option with fallback',
        order          => 6,
        config_key     => 'sixth',
        config_section => 'sample',
        envvar         => 'SIXTH',
        fallback       => 'sixth_fallback',
    );
    is( $option->default, 'sixth_fallback',
        'default with fallback is as expected' );

}

note 'Option with fallback and default in description ';
{
    my $option = AECO->new(
        spec            => 'seventh',
        description     => 'option with fallback and default in description',
        order           => 7,
        config_key      => 'seventh',
        config_section  => 'sample',
        display_default => 1,
        envvar          => 'SEVENTH',
        fallback        => 'seventh_fallback',
    );
    is( $option->description,
        'option with fallback and default in description. '
          . 'If not specified, will use "seventh_fallback"',
        'description with default displayed is as expected'
    );

}

done_testing;

__END__

