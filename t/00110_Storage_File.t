use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;
use Actium::Mock::Class;

use Test::More 0.98 tests => 70;

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

{

    isa_ok( 'Actium::Storage::File', 'Path::Class::File' );

    is( Actium::Storage::File->dir_class,
        'Actium::Storage::Folder', 'dir_class is Actium::Storage::Folder' );

    my $tempname_for_exists = tempname;
    my $newfile             = Actium::Storage::File->new($tempname_for_exists);
    isa_ok $newfile, 'Actium::Storage::File',
      'object for new, nonexistent file';
    isa_ok $newfile, 'Path::Class::File', 'object for new, nonexistent file';

    note 'exists()';

    ok( not( $newfile->exists ),
        'exists() shows that non-existent file indeed does not exist' );
    my $pc_file_for_exists = Path::Class::File->new($tempname_for_exists);
    $pc_file_for_exists->touch;
    ok( ( $newfile->exists ),
        'exists() shows that file indeed does exist after being touched' );
    $pc_file_for_exists->remove;

}

note 'remove()';

{

    my $delname = tempname;
    my $del_asf = Actium::Storage::File->new($delname);
    $del_asf->touch;
    my $result = $del_asf->remove;
    ok( !-e $delname, 'remove() removed the file' );
    ok $result, '... and the result is true';
}

{
    my $ne_name = tempname;
    my $ne_asf  = Actium::Storage::File->new($ne_name);
    my $result  = $ne_asf->remove;
    ok( ( not $result ), 'remove() returned false for nonexistent file' );
}

{
    my $bad_delname = tempname;
    mkdir $bad_delname or die $!;
    my $bad_del_asf = Actium::Storage::File->new($bad_delname);
    test_exception { $bad_del_asf->remove }
    "remove() throws exception when remove gives error", qr/Can\'t remove/;
}

note 'is_folder()';

my $nif_name = File::Spec->catfile(qw/tmp anotherfolder notreallyafile.txt/);
my $not_in_filesystem = Actium::Storage::File->new($nif_name);

{
    ok( not( $not_in_filesystem->is_folder ), 'is_folder() is correct' );

    note 'folder()';

    my $folder   = $not_in_filesystem->folder;
    my $expected = File::Spec->catfile(qw/tmp anotherfolder/);
    isa_ok $folder, 'Actium::Storage::Folder', 'result of folder()';
    is $folder, $expected, 'result of folder() is correct';
}

note 'add_before_extension()';

{
    my $not_in_filesystem_also
      = $not_in_filesystem->add_before_extension('also');
    isa_ok $not_in_filesystem_also, 'Actium::Storage::File',
      'object from add_before_extension';
    my $expected
      = File::Spec->catfile(qw/tmp anotherfolder notreallyafile-also.txt/);
    is $not_in_filesystem_also, $expected,
      'result of add_before_extension() is correct';
}

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
$spew_asf->remove;
is $text_data, $spewtext_result, 'spew_text() saves data correctly';

my ( $slurp_asf, $slurp_pcf ) = storage_test_objs();
$slurp_pcf->spew( iomode => '>:encoding(UTF-8)', $text_data );
my $slurptext_result = $slurp_asf->slurp_text();
$slurp_asf->remove;
is $text_data, $slurptext_result, 'slurp_text() reads data correctly';

note "slurp_binary and spew_binary";

my ( $spewb_asf, $spewb_pcf ) = storage_test_objs();
$spewb_asf->spew_binary($binary_data);
my $spewb_result = $spewb_pcf->slurp( iomode => '<:raw' );
$spewb_asf->remove;
is $binary_data, $spewb_result, 'spew_binary() saves data correctly';

my ( $slurpb_asf, $slurpb_pcf ) = storage_test_objs();
$slurpb_pcf->spew( iomode => '>:raw', $binary_data );
my $slurpb_result = $slurpb_asf->slurp_binary();
$slurpb_asf->remove;
is $slurpb_result, $binary_data, 'slurp_binary() reads data correctly';

note 'json_store and json_retrieve';
my $json_text = JSON::to_json( $deep_data, { pretty => 1, canonical => 1 } );

my $js_asf = Actium::Storage::File->new(tempname);
$js_asf->json_store($deep_data);
my $js_retrieved = JSON::from_json( scalar $js_asf->slurp_text );
is_deeply( $js_retrieved, $deep_data, 'json_store() writes data correctly' );
$js_asf->remove;

my $jr_asf = Actium::Storage::File->new(tempname);
$jr_asf->spew_text( JSON::to_json($deep_data) );
my $jr_retrieved = $jr_asf->json_retrieve;
is_deeply( $jr_retrieved, $deep_data, 'json_retrieve() reads data correctly' );
$jr_asf->remove;

note 'Storable store and retrieve';

my $ss_filename = tempname;
my $ss_asf      = Actium::Storage::File->new($ss_filename);
$ss_asf->store($deep_data);
my $ss_retrieved = Storable::retrieve($ss_filename);
is_deeply( $ss_retrieved, $deep_data, 'store() writes data correctly' );
$ss_asf->remove;

my $sr_filename = tempname;
my $sr_asf      = Actium::Storage::File->new($sr_filename);
Storable::nstore( $deep_data, $sr_filename );
my $sr_retrieved = $sr_asf->retrieve;
is_deeply( $sr_retrieved, $deep_data, 'retrieve() reads data correctly' );
$sr_asf->remove;

note 'sheet_retrieve()';

my $sheet_filename = tempname('.xlsx');
my $sheet_asf      = Actium::Storage::File->new($sheet_filename);
my $array2d = Array::2D->new( [ [qw /a b c/], [qw/d e f/], [ 1, 2, 3 ] ] );
$array2d->xlsx( output_file => $sheet_filename );
my $retrieved_array = $sheet_asf->sheet_retrieve;
is_deeply( $retrieved_array, $array2d, 'Retrieved Array::2D obj from sheet' );
$sheet_asf->remove;

note 'spew_from_method';

my $sampletext = Actium::Mock::Class->sampletext;

my $sm_filename = tempname;
my $sm_asf      = Actium::Storage::File->new($sm_filename);
my $mock        = Actium::Mock::Class->new;
$sm_asf->spew_from_method( method => 'meth', object => $mock );
my $sm_result = $sm_asf->slurp_text;
is $sm_result, $sampletext, 'spew_with_method writes correctly';
$sm_asf->remove;

my $sma_filename = tempname;
my $sma_asf      = Actium::Storage::File->new($sm_filename);
$sma_asf->spew_from_method(
    method => 'meth',
    object => $mock,
    args   => [qw/some arguments/]
);
my $sma_result = $sm_asf->slurp_text;
is $sm_result, $sampletext, 'spew_with_method writes correctly with arguments';
$sm_asf->remove;

my $mocklayers = Actium::Mock::Class::WithLayers->new;

my $sml_filename = tempname;
my $sml_asf      = Actium::Storage::File->new($sml_filename);
$sml_asf->spew_from_method(
    method => 'meth',
    object => $mocklayers,
);
my $sml_result = $sml_asf->slurp( iomode => '<:encoding(iso-8859-15)' );
is $sml_result, $sampletext, 'spew_with_method writes correctly with layers';
$sml_asf->remove;

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
$smla_asf->remove;

my $impossible_file
  = Actium::Storage::File->new( File::Spec->catfile( tempname, 'nope' ) );

{
    note 'open';

    my $open_filename = tempname;
    my $open_asf      = Actium::Storage::File->new($open_filename);
    $open_asf->spew( iomode => '>:raw', $binary_data );
    my $open_fh = $open_asf->open('<:raw');
    read $open_fh, my $open_result, length($binary_data);
    is( $open_result, $binary_data, "open opens file" );
    $open_asf->remove;

    test_exception { $impossible_file->open('<:raw') }
    "open() throws exception with nonexistent file", qr/Can\'t open/;

}

note 'openr_binary, openr_text, openw_binary, openw_text';

my $orr_filename = tempname;
my $orr_asf      = Actium::Storage::File->new($orr_filename);
$orr_asf->spew( iomode => '>:raw', $binary_data );
my $orr_fh = $orr_asf->openr_binary;
read $orr_fh, my $orr_result, length($binary_data);
is( $orr_result, $binary_data, "openr_raw opens file in raw mode" );
$orr_asf->remove;

test_exception { $impossible_file->openr_binary }
"openr_binary() throws exception with nonexistent file", qr/Can\'t read/;

my $ort_filename = tempname;
my $ort_asf      = Actium::Storage::File->new($orr_filename);
$ort_asf->spew( iomode => '>:encoding(UTF-8)', $text_data );
my $ort_fh = $ort_asf->openr_text;
read $ort_fh, my $ort_result, length($text_data);
is( $ort_result, $text_data, "openr_text opens file in utf8 encoding" );
$ort_asf->remove;

test_exception { $impossible_file->openr_text }
"openr_text() throws exception with nonexistent file", qr/Can\'t read/;

my $owr_filename = tempname;
my $owr_asf      = Actium::Storage::File->new($owr_filename);
my $owr_fh       = $owr_asf->openw_binary;
print $owr_fh $binary_data;
$owr_fh->close;
my $owr_result = $owr_asf->slurp_binary;
is $owr_result, $binary_data, "openw_binary opens file in binary mode";
$owr_asf->remove;

test_exception { $impossible_file->openw_binary }
"openw_binary() throws exception with nonexistent file", qr/Can\'t write/;

my $owt_filename = tempname;
my $owt_asf      = Actium::Storage::File->new($owt_filename);
my $owt_fh       = $owt_asf->openw_text;
print $owt_fh $text_data;
$owt_fh->close;
my $owt_result = $owt_asf->slurp_text;
is $owt_result, $text_data, "openw_text opens file in utf encoding";
$owt_asf->remove;

test_exception { $impossible_file->openw_binary }
"openw_text() throws exception with nonexistent file", qr/Can\'t write/;

note 'copy_to';

{
    my $fromname = tempname;
    my $toname   = tempname;
    my $from     = Actium::Storage::File->new($fromname);
    $from->spew_binary($binary_data);
    my $to = $from->copy_to($toname);
    is "$to", $toname, 'copy_to() returned correct result';
    my $to_data = $to->slurp_binary;
    is $to_data, $binary_data, '... and copy contained the same data';

    $from->remove;
    $to->remove;

    my $ne_from = Actium::Storage::File->new(tempname);
    test_exception { $ne_from->copy_to(tempname) }
    'Copy with error throws exception', qr/Couldn't copy/;

}

note 'move_to';

{
    my $fromname = tempname;
    my $toname   = tempname;
    my $from     = Actium::Storage::File->new($fromname);
    $from->spew_binary($binary_data);
    my $to = $from->move_to($toname);
    is "$to",   $toname, 'move_to() returned correct result';
    is "$from", $toname, '... and changed the original file object';
    my $to_data = $to->slurp_binary;
    is $to_data, $binary_data, '... and contained the same data';

    $to->remove;

    my $ne_from = Actium::Storage::File->new(tempname);
    test_exception { $ne_from->move_to(tempname) }
    'Move with error throws exception', qr/Couldn't move/;

}

note 'openr, openw, opena';

{
    my $asf = Actium::Storage::File->new(tempname);
    $asf->touch;
    test_exception { $asf->openr } 'openr() throws exception',
      qr/Disallowed method openr/;
    test_exception { $asf->openw } 'openw() throws exception',
      qr/Disallowed method openw/;
    test_exception { $asf->opena } 'opena() throws exception',
      qr/Disallowed method opena/;
    $asf->remove;
}

note 'touch()';

# tested here because relies on openw_binary

{
    # test the time change
    my $filename = tempname;
    my $asf      = Actium::Storage::File->new($filename);
    $asf->openw_binary;    # open but immediately close file, so it exists
    utime 0, 0, $filename; # set time to zero
    my $zeromtime = ( stat $filename )[8];
    die "Couldn't modify time" unless $zeromtime == 0;
    $asf->touch;
    my ( $atime, $mtime ) = ( stat $filename )[ 8, 9 ];
    ok( $mtime != 0, 'touch() modified the modification time' );
    ok( $atime != 0, 'touch() modified the access time' );
    $asf->remove;
}

# test the file creation

{
    my $filename = tempname;
    my $asf      = Actium::Storage::File->new($filename);
    $asf->touch;
    ok( -e $filename, 'touch created a file' );
    $asf->remove;
}

# test the errors

{
    my $filename
      = File::Spec->catfile( File::Spec->tmpdir, 'nope', 'doesnt', 'exist' );
    my $asf = Actium::Storage::File->new($filename);
    test_exception { $asf->touch }
    'touch() throws exception with error', qr/No such/;

}

note 'ini_retrieve()';

{
    my $file = Actium::Storage::File->new( tempname('.ini') );
    my $ini  = $file->ini_retrieve;
    isa_ok( $ini, 'Actium::Storage::Ini', 'result from ini_retrieve()' );

}

done_testing;

__END__

=head1 COPYRIGHT & LICENSE

Copyright 2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

