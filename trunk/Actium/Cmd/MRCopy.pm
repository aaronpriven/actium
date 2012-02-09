# /Actium/Cmd/MRCopy.pm

# Command-line access to copylatest in Actum::MapRepostory

# Subversion: $Id$

# Legacy status: 4

package Actium::Cmd::MRCopy 0.001;

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
add_option( 'web!',
    'Create web files of maps (on by default; turn off with -no-web)', 1 );
add_option( 'fullnames!',
    'Copy files with their full names (on by default; turn off with -no-web)',
    1, );
add_option(
    'linesnames!',
    'Copy files using the lines and token as the name only '
      . '(on by default; turn off with -no-web)',
    1,
);

add_option( 'webfolder|wf=s',
        'Folder where web files will be created. '
      . 'Default is "_web" in the repository' );
add_option( 'linesfolder|lf=s',
        'Folder to where lines and tokens files will be copied. '
      . 'Default is "_linesnames" in the repository' );
add_option( 'fullfolder|lf=s',
        'Folder to where full names will be copied. '
      . 'Default is "_fullnames" in the repository' );

sub HELP {
    say 'actium.pl mr_copy (options) ...'
      or die "Can't display usage: $OS_ERROR";
    output_usage;
    return;
}

sub START {

    my $repository = Actium::Folder->new( option('repository') );

    my $webfolder  = option_folder( 'web',       'webfolder',  '_web' );
    my $fullfolder = option_folder( 'fullnames', 'fullfolder', '_fullnames' );
    my $linesfolder
      = option_folder( 'linesnames', 'linesfolder', '_linesnames' );

    copylatest(
        repository => $repository,
        fullname   => $fullfolder,
        linesname  => $linesfolder,
        web        => $webfolder,
    );

    return;

}

sub option_folder {
    my ( $option, $folderoption, $default ) = @_;

    my $folder_obj;

    if ( option($option) ) {
        if ( option($folderoption) ) {
            $folder_obj = Actium::Folder->new( option($folderoption) );
        }
        else {
            $folder_obj = Actium::Folder->new($default);
        }
    }

    return $folder_obj;

}

1;

__END__
