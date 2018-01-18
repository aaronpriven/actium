use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;

use Test::More 0.98;

BEGIN {
    note "These are tests of Actium::Storage::Ini.";
    use_ok 'Actium::Storage::Ini';
}

use Actium::Storage::File;

my $ini = <<EOT;
key = value
key2 = second value
[first_section]
another key = another value
key_with_underscores = whatever
15 = 15
[section2]
x%a = 15*3727
EOT

my $expected = {
    '_'             => { key => 'value', key2 => 'second value' },
    'first_section' => {
        'another key'        => 'another value',
        key_with_underscores => 'whatever',
        15                   => 15,
    },
    section2 => { 'x%a' => '15*3727' },
};

{
    note 'test from filename';

    my $tempname = tempfilename('.ini');
    my $tempfile = Actium::Storage::File->new($tempname);
    $tempfile->spew_text($ini);
    my $obj = Actium::Storage::Ini->new($tempname);
    isa_ok $obj, 'Actium::Storage::Ini', 'new object specified with filename';
    $tempfile->remove;

}

my $obj;
{
    note 'test from filename';

    my $tempname = tempfilename('.ini');
    my $tempfile = Actium::Storage::File->new($tempname);
    $tempfile->spew_text($ini);
    $obj = Actium::Storage::Ini->new($tempfile);
    isa_ok $obj, 'Actium::Storage::Ini',
      'new object specified with file object';

    my $allvalues = $obj->_values_r;
    is_deeply $allvalues, $expected,
      'Internal values hoh is the same as expected';

    $tempfile->remove;

}

note 'sections, section, value methods';

is_deeply [ $obj->sections ], [qw/_ first_section section2/],
  'sections(): Sections are as the same as expected';

is_deeply { $obj->section('first_section') }, $expected->{'first_section'},
  'section(): A section is the same as expected';

is $obj->value( key => 'key' ), 'value',
  'Value in default section the same as expected';

is $obj->value( key => 'x%a', section => 'section2' ), '15*3727',
  'Value in specified section the same as expected';

done_testing;

__END__


