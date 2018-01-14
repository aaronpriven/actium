use strict;
use utf8;
use Test::More 0.98;

my $builder = Test::More->builder;
binmode $builder->output,         ":encoding(utf8)";
binmode $builder->failure_output, ":encoding(utf8)";
binmode $builder->todo_output,    ":encoding(utf8)";

use File::Temp('tmpnam');
use Path::Class();
use JSON;
use Storable;
use Actium::Env::TestStub;

BEGIN {
    note "These are tests of Actium::Storage::File.";
    use_ok 'Actium::Storage::File';
}

Actium::_set_env(Actium::Env::TestStub::cry);

note 'Object creation and inheritance';

isa_ok( 'Actium::Storage::File', 'Path::Class::File' );

is( Actium::Storage::File->dir_class,
    'Actium::Storage::Folder', 'dir_class is Actium::Storage::Folder' );

my $tempname_for_exists = tmpnam();

my $newfile = Actium::Storage::File->new($tempname_for_exists);
isa_ok $newfile, 'Actium::Storage::File', 'object for new, nonexistent file';
isa_ok $newfile, 'Path::Class::File',     'object for new, nonexistent file';

note 'exists()';

ok( not( $newfile->exists ),
    'exists() shows that non-existent file indeed does not exist' );
my $pc_file_for_exists = Path::Class::File->new($tempname_for_exists);
$pc_file_for_exists->touch;
ok( ( $newfile->exists ),
    'exists() shows that file indeed does exist after being touched' );
$pc_file_for_exists->remove;

note 'is_folder()';

my $not_in_filesystem
  = Actium::Storage::File->new('/tmp/anotherfolder/notreallyafile.txt');
ok( not( $not_in_filesystem->is_folder ), 'is_folder() is correct' );

note 'folder()';

my $folder = $not_in_filesystem->folder;
isa_ok $folder, 'Actium::Storage::Folder', 'result of folder()';
is $folder,     '/tmp/anotherfolder',      'result of folder() is correct';

note 'add_before_extension()';

my $not_in_filesystem_also = $not_in_filesystem->add_before_extension('also');
isa_ok $not_in_filesystem_also, 'Actium::Storage::File',
  'object from add_before_extension';
is $not_in_filesystem_also, '/tmp/anotherfolder/notreallyafile-also.txt',
  'result of add_before_extension() is correct';

note 'basename_ext';

my ( $basename, $ext ) = $not_in_filesystem->basename_ext;
is $basename, 'notreallyafile', 'basename from basename_ext() is correct';
is $ext,      'txt',            'extension from basename_ext() is correct';

my $noextension = Actium::Storage::File->new('/tmp/anotherfolder/athirdfile');
( $basename, $ext ) = $noextension->basename_ext;
is $basename, 'athirdfile',
  'basename from basename_ext() is correct where there\'s no extension';
is $ext, '',
  'extension from basename_ext() is empty where there\'s no extension';

note 'slurp_text and spew_text';

my $text_data
  = "So happy to be using UTF-8! \x{1F603}\nI hope this works! \x{1F633}\n";
my $binary_data = join( '', map {chr} 0 .. 255 );
my $deep_data = [
    'scalar', [qw/a subarray/], { a => 'hash', utf8value => "\x{1F914}" },
    $text_data, $binary_data
];

sub storage_test_objs {
    my $filename = tmpnam();
    my $asf      = Actium::Storage::File->new($filename);
    my $pcf      = Path::Class::File->new($filename);
    return ( $asf, $pcf );
}

my ( $spew_asf, $spew_pcf ) = storage_test_objs();
$spew_asf->spew_text($text_data);
my $spewtext_result = $spew_pcf->slurp( iomode => '<:encoding(UTF-8)' );
$spew_pcf->remove;
is $text_data, $spewtext_result, 'spew_text() saves data correctly';

my ( $slurp_asf, $slurp_pcf ) = storage_test_objs();
$slurp_pcf->spew( iomode => '>:encoding(UTF-8)', $text_data );
my $slurptext_result = $slurp_asf->slurp_text();
$slurp_pcf->remove;
is $text_data, $slurptext_result, 'slurp_text() reads data correctly';

note 'json_store and json_retrieve';
my $json_text = JSON::to_json( $deep_data, { pretty => 1, canonical => 1 } );

my $js_asf
  = Actium::Storage::File->new( $ENV{HOME} . "/test.json" ); #scalar tmpnam() );
$js_asf->json_store($deep_data);
my $json_retrieved = JSON::from_json( scalar $js_asf->slurp_text );
is_deeply( $json_retrieved, $deep_data, 'json_store() writes data correctly' );

done_testing;

