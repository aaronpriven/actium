# /Actium/Cmd/MRImport.pm

# Command-line access to import_to_repository in Actum::MapRepostory

# Subversion: $Id$

# Legacy status: 4

package Actium::Cmd::MRImport 0.001;

use 5.014;
use warnings;

use Actium::MapRepository (':all');
use Actium::Folder;

use Actium::Options(qw<add_option option>);
use Actium::Term ('output_usage');

use English '-no_match_vars';

add_option(
    'repository=s',
    'Location of repository in file system',
    '/Volumes/Bireme/Maps/Repository'
);
add_option( 'makeweb|mw!',
    'Create web files of maps (on by default; turn off with -no-makeweb)', 1 );
add_option( 'webfolder|wf=s',
        'Folder where web files will be created. '
      . 'Default is "web" in the folder where the maps already are' );
add_option(
    'move|mv!',
    'Move files into repository instead of copying '
      . '(on by default; turn off with -no-move)',
    1
);
#add_option( 'rename!',
#        'Rename the maps to have the same filenames as those '
#      . 'in the repository. Has no effect when moving instead of copying.' );
# never implemented

sub HELP {
    say 'actium.pl mr_import _folder_ _folder_...'
      or die "Can't display usage: $OS_ERROR";
    output_usage;
    return;
}

sub START {

    my @importfolders = @_;
    unless (@importfolders) {
        HELP();
        return;
    }
    my $move          = option('move');
    my $makeweb       = option('makeweb');
    my $webfolder_opt = option('webfolder');

    my $specified_webfolder_obj;

    if ( $makeweb and $webfolder_opt ) {
        $specified_webfolder_obj = Actium::Folder->new( option('webfolder') );
    }

    my $repository = Actium::Folder->new( option('repository') );

    foreach (@importfolders) {

        # import to repository
        my $importfolder   = Actium::Folder->new($_);
        my @imported_files = import_to_repository(
            repository   => $repository,
            move         => option('move'),
            importfolder => $importfolder
        );
        
        # make web files

        if ($makeweb) {
            my $webfolder_obj;

            if ($specified_webfolder_obj) {
                $webfolder_obj = $specified_webfolder_obj;
            }
            else {
                $webfolder_obj = $importfolder->subfolder('web');
            }

            make_web_maps(
                web_folder => $webfolder_obj,
                files      => \@imported_files
            );

        }

    } ## tidy end: foreach (@importfolders)

    return;

} ## tidy end: sub START

1;

__END__
