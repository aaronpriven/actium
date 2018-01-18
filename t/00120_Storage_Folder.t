use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;

use Test::More 0.98 tests => 58;

use File::Temp;
use Actium::Env::TestStub;
Actium::_set_env( Actium::Env::TestStub->new() );
use File::Spec;
use Actium::Mock::Class;

BEGIN {
    note "These are tests of Actium::Storage::Folder.";
    use_ok 'Actium::Storage::Folder';
}

Actium::_set_env(Actium::Env::TestStub::new);

sub tempname {
    my $temp = File::Temp::tmpnam();
    #note "tempname: $temp";
    return $temp;
}

note 'Object creation and inheritance';

{

    isa_ok( 'Actium::Storage::Folder', 'Path::Class::Dir' );

    is( Actium::Storage::Folder->file_class,
        'Actium::Storage::File', 'file_class is Actium::Storage::File' );

  # Note that File::Temp doesn't include any ways of getting a temporary
  # directory name that in a way that doesn't actually create the directory.
  # so this gets a filename instead from File::Temp::mktemp.
  # I'm not *aware* of
  # any filesystems where a directory can't have the same name as a file, but if
  # there are any, this will break.

    my $new_foldername = tempname;
    my $newfolder      = Actium::Storage::Folder->new($new_foldername);
    isa_ok $newfolder, 'Actium::Storage::Folder',
      'object for new, nonexistent folder';
    isa_ok $newfolder, 'Path::Class::Dir', 'object for new, nonexistent folder';
    ok( $newfolder->is_folder, 'is_folder() is correct' );

}

{
    note 'home';
    use File::HomeDir;

  SKIP: {
        my $home = File::HomeDir->my_home;
        skip( 'File::HomeDir not returning a valid home folder', 1 )
          if not defined $home;
        is( Actium::Storage::Folder->home->stringify,
            $home, 'Home folder found (default method to File::HomeDir)' );
    }

  SKIP: {
        my $data = File::HomeDir->my_data;
        skip( 'File::HomeDir not returning a valid data folder', 1 )
          if not defined $data;
        is( Actium::Storage::Folder->home('my_data')->stringify,
            $data, 'Data folder found (specifying a method to File::HomeDir)' );
    }

}

{
    note 'exists() and remove()';

    my $foldername = tempname;
    my $folder     = Actium::Storage::Folder->new($foldername);
    ok( not( $folder->exists ),
        'exists() shows that non-existent folder indeed does not exist' );
    mkdir $foldername or die $!;
    ok( ( $folder->exists ),
        'exists() shows that folder indeed does exist after being made' );

    $folder->remove();
    ok( !-e $folder, 'folder no longer exists after removal' );

    test_exception { $folder->remove }
    'Removing nonexistent folder throws exception', qr/No such/;

}

{
    note 'mkpath';

    my $foldername     = tempname;
    my @morecomponents = qw/some more components/;
    my $folder = Actium::Storage::Folder->new( $foldername, @morecomponents );
    $folder->mkpath;
    ok( $folder->exists, 'mkpath() made a deep path' );
    File::Path::rmtree($foldername);

}

{
    my $foldername     = tempname;
    my @morecomponents = qw/even more components/;
    my $folder = Actium::Storage::Folder->new( $foldername, @morecomponents );
    note $folder;
    # this captures verbose output in $verbosity
    open( local *STDOUT, ">", \my $verbosity ) or die "dup out to err: $!";
    my $sentmode = oct('700');
    $folder->mkpath( 1, $sentmode );
    ok $folder->exists, 'mkpath() made folder with verbosity and mode set';
    my $gotmode = $folder->stat->mode & 07777;
    cmp_ok $gotmode , '==', $sentmode, '...and mode is correct';
    note "$gotmode  $sentmode";
    like $verbosity, qr/mkdir $folder/, '...and output was verbose';
    File::Path::rmtree($foldername);

}

{

    my $foldername = tempname;
    mkdir $foldername or die "can't make folder $foldername";
    my @morecomponents = qw/still more components/;
    my $folder = Actium::Storage::Folder->new( $foldername, @morecomponents );
    chmod 0000, $foldername or die "can't make folder $foldername unreadable";
    test_exception { $folder->mkpath } 'mkpath() threw exception on error',
      qr/Permission denied/i;
    chmod 0755, $foldername or die $!;
    rmdir $foldername or die $!;

}

{

    note 'ensure_folder()';

    my $foldername = tempname;
    mkdir $foldername or die $!;

    my $folder = Actium::Storage::Folder->ensure_folder($foldername);
    isa_ok( $folder, 'Actium::Storage::Folder',
        "new folder object created with ensure_folder" );
    ok( ( $folder->exists ),
        'exists() shows that an existing folder '
          . 'continues to exist after being ensured'
    );
    rmdir $foldername;

    my $newfoldername = tempname;
    my $newfolder     = Actium::Storage::Folder->ensure_folder($newfoldername);
    isa_ok( $newfolder, 'Actium::Storage::Folder',
        "formerly nonexistent ensured folder" );
    ok( ( $newfolder->exists ),
        'exists() shows that formerly nonexistent folder '
          . 'indeed does exist after being ensured'
    );
    rmdir $newfoldername;

}

{
    note 'existing_folder()';

    my $foldername = tempname;
    mkdir $foldername or die $!;
    my $folder = Actium::Storage::Folder->existing_folder($foldername);
    isa_ok( $folder, 'Actium::Storage::Folder',
        'folder object from existing_folder' );
    rmdir $foldername;

    my $nonexistentname = tempname;
    test_exception {
        Actium::Storage::Folder->existing_folder($nonexistentname)
    }
    'existing_folder throws exception with nonexistent folder',
      qr/does not exist/;

}

{
    note 'rmtree';

    my $folder    = Actium::Storage::Folder->ensure_folder(tempname);
    my $subfolder = $folder->ensure_subfolder(qw/still even more components/);
    die $! unless $folder->exists;
    die $! unless $subfolder->exists;
    # already tested ensure_folder...
    $folder->rmtree;
    ok( ( not $folder->exists ), 'rmtree() deleted a deep path tree' );

}

{
    my $folder    = Actium::Storage::Folder->ensure_folder(tempname);
    my $subfolder = $folder->ensure_subfolder('component');
    # this captures verbose output in $verbosity
    open( local *STDOUT, ">", \my $verbosity ) or die "dup out to err: $!";
    $folder->rmtree(1);
    ok !$folder->exists,
      'rmtree deleted deep path tree with verbosity specified';
    like $verbosity, qr/rmdir component/, '...and output was verbose';

}

{
    note 'subfolder()';
    my $foldername   = '/a/folder';
    my $subcomponent = 'sub';
    my $folder       = Actium::Storage::Folder->new($foldername);
    my $subfolder    = $folder->subfolder($subcomponent);
    my $expected     = File::Spec->catdir( $foldername, $subcomponent );
    is $subfolder->stringify, $expected, 'subfolder() gives expected result';
}

{
    note 'ensure_subfolder()';

    my $foldername   = tempname;
    my $subcomponent = 'subby';
    my $folder       = Actium::Storage::Folder->ensure_folder($foldername);
    my $subfolder    = $folder->ensure_subfolder($subcomponent);
    my $expected     = File::Spec->catdir( $foldername, $subcomponent );
    is $subfolder->stringify, $expected,
      'ensure_subfolder() gives expected result';
    ok $subfolder->exists, 'and subfolder is created';

    my $newsubcomponent = 'sub2';
    my $newexpected = File::Spec->catdir( $foldername, $newsubcomponent );
    die "Subfolder that shouldn't exist already exists" if -e $newexpected;
    my $newsubfolder = $folder->ensure_subfolder($newsubcomponent);
    ok $newsubfolder->exists,
      'ensure_subfolder creates previously nonexistent folder';

}

{
    note 'existing_subfolder()';

    my $foldername   = tempname;
    my $folder       = Actium::Storage::Folder->ensure_folder($foldername);
    my $subcomponent = 'sub3';
    my $ensured      = $folder->ensure_subfolder($subcomponent);
    my $subfolder    = $folder->existing_subfolder($subcomponent);
    is $subfolder->stringify, $ensured->stringify,
      'existing_subfolder() gies expected result';

    test_exception {
        Actium::Storage::Folder->existing_subfolder('doesnt_exist')
    }
    'existing_subfolder throws exception with nonexistent folder',
      qr/does not exist/;

}

{
    note 'remove';

    my $folder = Actium::Storage::Folder->ensure_folder(tempname);
    $folder->remove;
    ok( !$folder->exists, 'remove() removed the folder' );

    my $notafolder = Actium::Storage::Folder->new('/tmp/nope/notafolder');
    test_exception { $folder->remove }
    'remove() throws exception with an error', qr/No such/;

}

{
    note 'open';
    my $folder = Actium::Storage::Folder->ensure_folder(tempname);
    isa_ok( $folder->open, 'IO::Dir', "the open handle of a folder" );

    my $subfolder = $folder->subfolder('doesntexist');
    test_exception { $subfolder->open } 'open throws on error',
      qr/Can't open folder/;
    $folder->remove;

}

{

    # subfolders for grep and glob

    my $folder = Actium::Storage::Folder->new(tempname);
    my ( %child_folders, %child_files );
    foreach my $child_name (qw/sub1 sub2 othersub/) {
        $child_folders{$child_name} = $folder->ensure_subfolder($child_name);
    }
    foreach my $child_name (qw/file1 file2 otherfile/) {
        my $file = $folder->file($child_name);
        $file->touch;
        $child_files{$child_name} = $file;
    }

    {
        note 'grep';

        my @results = $folder->grep (qr/other/);
        my @result_strs = sort map { $_->basename } @results;
        is_deeply( \@result_strs, [qw/otherfile othersub/],
            'grep returns correct results' );
        isa_ok( $results[0], 'Actium::Storage::File', 'file returned by grep' );
        isa_ok( $results[1], 'Actium::Storage::Folder',
            'folder returned by grep' );
    }

    {

        note 'glob';
        my @results = $folder->glob('other*');
        my @result_strs = sort map { $_->basename } @results;
        is_deeply( \@result_strs, [qw/otherfile othersub/],
            'glob with pattern returns correct results' );
        isa_ok( $results[0], 'Actium::Storage::File', 'file returned by glob' );
        isa_ok( $results[1], 'Actium::Storage::Folder',
            'folder returned by glob' );
        @results = $folder->glob();
        @result_strs = sort map { $_->basename } @results;
        is_deeply(
            \@result_strs,
            [qw/file1 file2 otherfile othersub sub1 sub2/],
            'glob with no pattern returns correct results'
        );

    }

    note 'glob_files';
    {
        my @results = $folder->glob_files();
        my @result_strs = sort map { $_->basename } @results;
        is_deeply(
            \@result_strs,
            [qw/file1 file2 otherfile/],
            'glob_files with no pattern returns correct results'
        );
        isa_ok( $results[0], 'Actium::Storage::File',
            'file returned by glob_files' );
        @results = $folder->glob_files('file?');
        @result_strs = sort map { $_->basename } @results;
        is_deeply( \@result_strs, [qw/file1 file2/],
            'glob_files with pattern returns correct results' );
    }

    note 'glob_folders';
    {
        my @results = $folder->glob_folders();
        my @result_strs = sort map { $_->basename } @results;
        is_deeply( \@result_strs, [qw/othersub sub1 sub2/],
            'glob_folders with no pattern returns correct results' );
        isa_ok( $results[0], 'Actium::Storage::Folder',
            'file returned by glob_folders' );
        @results = $folder->glob_folders('sub?');
        @result_strs = sort map { $_->basename } @results;
        is_deeply( \@result_strs, [qw/sub1 sub2/],
            'glob_folders with pattern returns correct results' );
    }

}

note 'spew_from_method';

my $sampletext = Actium::Mock::Class->sampletext;

my @objects = map { Actium::Mock::Class->new( 'x' . $_ ) } 1 .. 3;
my @layerobjects
  = map { Actium::Mock::Class::WithLayers->new( 'x' . $_ ) } 1 .. 3;

{

    my $folder = Actium::Storage::Folder->ensure_folder(tempname);
    $folder->spew_from_method( objects => \@objects, method => 'meth' );
    my @expected = ($sampletext) x 3;
    my @got;
    for ( 1 .. 3 ) {
        my $file = $folder->file( 'x' . $_ );
        push @got, scalar $file->slurp_text;
    }
    is_deeply( \@got, \@expected, 'spew_from_method writes correctly' );
    $folder->rmtree;

}

{

    my $folder = Actium::Storage::Folder->ensure_folder(tempname);
    $folder->spew_from_method( objects => \@layerobjects, method => 'meth' );
    my @expected = ($sampletext) x 3;
    my @got;
    for ( 1 .. 3 ) {
        my $file = $folder->file( 'x' . $_ );
        push @got, scalar $file->slurp( iomode => '<:encoding(iso-8859-15)' );
    }
    is_deeply( \@got, \@expected,
        'spew_from_method writes correctly with layers' );
    $folder->rmtree;

}

{
    note 'spew_from_hash';
    my %hash = ( a => $sampletext, b => $sampletext, c => $sampletext );
    my $folder = Actium::Storage::Folder->ensure_folder(tempname);
    $folder->spew_from_hash( hash => \%hash );
    my @expected = ($sampletext) x 3;
    my @got;
    for (qw/a b c/) {
        my $file = $folder->file($_);
        push @got, scalar $file->slurp_text;
    }
    is_deeply( \@got, \@expected, 'spew_from_hash writes correctly' );
    $folder->rmtree;

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

