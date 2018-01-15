use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

use Test::More 0.98 tests => 36;

use File::Temp;
use Path::Class();
use JSON;
use Storable;
use Actium::Env::TestStub;
use Array::2D;
use File::Spec;

BEGIN {
    note "These are tests of Actium::Storage::File.";
    use_ok 'Actium::Storage::File';
}

my $tmpdir = File::Spec->tmpdir();

sub tempname {
    my $suffix = shift;
    my $tempname;
    my $template = 'Actium_testing_XXXXXXXXXX';
    my %args = ( OPEN => 0, DIR => $tmpdir );
    $args{SUFFIX} = $suffix if defined $suffix;

    {
        no warnings;
        ( undef, $tempname ) = File::Temp::tempfile( $template, %args );
    }

    #note $tempname;
    return $tempname;
}

Actium::_set_env(Actium::Env::TestStub::new);

note 'Object creation and inheritance';

isa_ok( 'Actium::Storage::File', 'Path::Class::File' );

is( Actium::Storage::File->dir_class,
    'Actium::Storage::Folder', 'dir_class is Actium::Storage::Folder' );

my $tempname_for_exists = tempname;

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

note 'delete()';

my $delname = tempname;
my $del_asf = Actium::Storage::File->new($delname);
$del_asf->touch;
$del_asf->delete;
ok( !-e $delname, 'delete() removed the file' );

my $ne_delname = tempname;
my $ne_del_asf = Actium::Storage::File->new($ne_delname);
test_exception { $ne_del_asf->delete }
"delete() throws exception with nonexistent file", qr/Can\'t delete/;

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
    my $filename = tempname;
    my $asf      = Actium::Storage::File->new($filename);
    my $pcf      = Path::Class::File->new($filename);
    return ( $asf, $pcf );
}

my ( $spew_asf, $spew_pcf ) = storage_test_objs();
$spew_asf->spew_text($text_data);
my $spewtext_result = $spew_pcf->slurp( iomode => '<:encoding(UTF-8)' );
$spew_asf->delete;
is $text_data, $spewtext_result, 'spew_text() saves data correctly';

my ( $slurp_asf, $slurp_pcf ) = storage_test_objs();
$slurp_pcf->spew( iomode => '>:encoding(UTF-8)', $text_data );
my $slurptext_result = $slurp_asf->slurp_text();
$slurp_asf->delete;
is $text_data, $slurptext_result, 'slurp_text() reads data correctly';

note "slurp_binary and spew_binary";

my ( $spewb_asf, $spewb_pcf ) = storage_test_objs();
$spewb_asf->spew_binary($binary_data);
my $spewb_result = $spewb_pcf->slurp( iomode => '<:raw' );
$spewb_asf->delete;
is $binary_data, $spewb_result, 'spew_binary() saves data correctly';

my ( $slurpb_asf, $slurpb_pcf ) = storage_test_objs();
$slurpb_pcf->spew( iomode => '>:raw', $binary_data );
my $slurpb_result = $slurpb_asf->slurp_binary();
$slurpb_asf->delete;
is $slurpb_result, $binary_data, 'slurp_binary() reads data correctly';

note 'json_store and json_retrieve';
my $json_text = JSON::to_json( $deep_data, { pretty => 1, canonical => 1 } );

my $js_asf = Actium::Storage::File->new(tempname);
$js_asf->json_store($deep_data);
my $js_retrieved = JSON::from_json( scalar $js_asf->slurp_text );
is_deeply( $js_retrieved, $deep_data, 'json_store() writes data correctly' );
$js_asf->delete;

my $jr_asf = Actium::Storage::File->new(tempname);
$jr_asf->spew_text( JSON::to_json($deep_data) );
my $jr_retrieved = $jr_asf->json_retrieve;
is_deeply( $jr_retrieved, $deep_data, 'json_retrieve() reads data correctly' );
$jr_asf->delete;

note 'Storable store and retrieve';

my $ss_filename = tempname;
my $ss_asf      = Actium::Storage::File->new($ss_filename);
$ss_asf->store($deep_data);
my $ss_retrieved = Storable::retrieve($ss_filename);
is_deeply( $ss_retrieved, $deep_data, 'store() writes data correctly' );
$ss_asf->delete;

my $sr_filename = tempname;
my $sr_asf      = Actium::Storage::File->new($sr_filename);
Storable::nstore( $deep_data, $sr_filename );
my $sr_retrieved = $sr_asf->retrieve;
is_deeply( $sr_retrieved, $deep_data, 'retrieve() reads data correctly' );
$sr_asf->delete;

note 'sheet_retrieve()';

my $sheet_filename = tempname('.xlsx');
my $sheet_asf      = Actium::Storage::File->new($sheet_filename);
my $array2d = Array::2D->new( [ [qw /a b c/], [qw/d e f/], [ 1, 2, 3 ] ] );
$array2d->xlsx( output_file => $sheet_filename );
my $retrieved_array = $sheet_asf->sheet_retrieve;
is_deeply( $retrieved_array, $array2d, 'Retrieved Array::2D obj from sheet' );
$sheet_asf->delete;

note 'spew_from_method';

my $sampletext = <<EOT;
This Is the Title of This Story, Which Is Also Found Several Times in the Story
Itself.\N{EURO SIGN}
EOT

package Actium::Mock::Class {

    sub new {
        my $class = shift;
        return bless {}, $class;
    }

    sub meth {
        my $self = shift;
        my $text = $sampletext;
        $text .= "Arguments: @_\n" if @_;
        return $text;
    }

}

package Actium::Mock::Class::WithLayers {
    our @ISA = 'Actium::Mock::Class';
    sub meth_layers {':encoding(iso-8859-15)'}
}

my $sm_filename = tempname;
my $sm_asf      = Actium::Storage::File->new($sm_filename);
my $mock        = Actium::Mock::Class->new;
$sm_asf->spew_from_method( method => 'meth', object => $mock );
my $sm_result = $sm_asf->slurp_text;
is $sm_result, $sampletext, 'spew_with_method writes correctly';
$sm_asf->delete;

my $sma_filename = tempname;
my $sma_asf      = Actium::Storage::File->new($sm_filename);
$sma_asf->spew_from_method(
    method => 'meth',
    object => $mock,
    args   => [qw/some arguments/]
);
my $sma_result = $sm_asf->slurp_text;
is $sm_result, $sampletext, 'spew_with_method writes correctly with arguments';
$sm_asf->delete;

my $mocklayers = Actium::Mock::Class::WithLayers->new;

my $sml_filename = tempname;
my $sml_asf      = Actium::Storage::File->new($sml_filename);
$sml_asf->spew_from_method(
    method => 'meth',
    object => $mocklayers,
);
my $sml_result = $sml_asf->slurp( iomode => '<:encoding(iso-8859-15)' );
is $sml_result, $sampletext, 'spew_with_method writes correctly with layers';
$sml_asf->delete;

my $smla_filename = tempname;
my $smla_asf      = Actium::Storage::File->new($smla_filename);
$smla_asf->spew_from_method(
    method => 'meth',
    object => $mocklayers,
    args   => [qw/some arguments/]
);
my $smla_result = $smla_asf->slurp( iomode => '<:encoding(iso-8859-15)' );
is $smla_result, $sampletext . "Arguments: some arguments\n",
  'spew_with_method writes correctly with layers and arguments';
$smla_asf->delete;

note 'openr_binary, openr_text, openw_binary, openw_text';

my $orr_filename = tempname;
my $orr_asf      = Actium::Storage::File->new($orr_filename);
$orr_asf->spew( iomode => '>:raw', $binary_data );
my $orr_fh = $orr_asf->openr_binary;
read $orr_fh, my $orr_result, length($binary_data);
is( $orr_result, $binary_data, "openr_raw opens file in raw mode" );
$orr_asf->delete;

my $ort_filename = tempname;
my $ort_asf      = Actium::Storage::File->new($orr_filename);
$ort_asf->spew( iomode => '>:encoding(UTF-8)', $text_data );
my $ort_fh = $ort_asf->openr_text;
read $ort_fh, my $ort_result, length($text_data);
is( $ort_result, $text_data, "openr_text opens file in utf8 encoding" );
$ort_asf->delete;

my $owr_filename = tempname;
my $owr_asf      = Actium::Storage::File->new($owr_filename);
my $owr_fh       = $owr_asf->openw_binary;
print $owr_fh $binary_data;
$owr_fh->close;
my $owr_result = $owr_asf->slurp_binary;
is $owr_result, $binary_data, "openw_binary opens file in binary mode";
$owr_asf->delete;

my $owt_filename = tempname;
my $owt_asf      = Actium::Storage::File->new($owt_filename);
my $owt_fh       = $owt_asf->openw_text;
print $owt_fh $text_data;
$owt_fh->close;
my $owt_result = $owt_asf->slurp_text;
is $owt_result, $text_data, "openw_text opens file in utf encoding";
$owt_asf->delete;

done_testing;

