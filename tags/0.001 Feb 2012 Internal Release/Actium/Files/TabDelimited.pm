# Actium/Files/TabDelimited.pm

# Class for reading Tab-Delimited files and returning them to the caller.

# Subversion: $Id$

use warnings;
use 5.014;    # turns on features

package Actium::Files::TabDelimited 0.001;

use Carp;
use English '-no_match_vars';
use Text::Trim;

use Params::Validate (':all');

use Actium::Folders::Signup;
use Actium::Term;
use Actium::Util('filename');

use Readonly;
Readonly my $LINES_BETWEEN_EMITTING_PERCENTAGES => 5000;

use Sub::Exporter -setup => { exports => [qw(read_tab_files)] };

sub read_tab_files {

    my %params = validate(
        @_,
        {   folder => {
                can => [
                    'make_filespec', 'glob_plain_files',
                    'open_read',     'display_path'
                ]
            },
            files            => { type => ARRAYREF, default => [] },
            globpatterns     => { type => ARRAYREF, default => [] },
            required_headers => { type => ARRAYREF, default => [] },
            callback         => { type => CODEREF },
        },

    );

    my $folder             = $params{folder};
    my $passed_files_r     = $params{files};
    my $globpatterns_r     = $params{globpatterns};
    my $required_headers_r = $params{required_headers};
    my $callback_r         = $params{callback};

    my @files = _expand_files( $passed_files_r, $globpatterns_r, $folder );

    foreach my $file (@files) {

        emit "Loading $file";

        my $fh = $folder->open_read($file);

        my @headers = _verify_headers( $fh, $file, $required_headers_r );

        my $size    = -s $fh;
        #my $size    = -s $folder->make_filespec($file);
        my $linenum = 0;

        emit_over ' 0%';

        while ( my $line = <$fh> ) {

            $linenum++;
            if ( not $linenum % $LINES_BETWEEN_EMITTING_PERCENTAGES ) {
                emit_over( sprintf( ' %.0f%%', tell($fh) / $size * 100 ) );
            }

            my %value_of;
            @value_of{@headers} = trim( split( "\t", $line ) );

            $callback_r->( \%value_of );

        }

        emit_over ' 100%';

        close $fh or croak "Can't close $file for writing";

        emit_done;

    } ## tidy end: foreach my $file (@files)

} ## tidy end: sub read_tab_files

sub _expand_files {

    my ( $files_r, $globpatterns_r, $folder ) = @_;

    my @files = @{$files_r};

    foreach (@$globpatterns_r) {
        push @files, filename( $folder->glob_plain_files($_) );
    }

    if ( not scalar @files ) {
        my $path = $folder->display_path;
        croak("No files found in $path passed to read_tab_files ");
    }

    return @files;

}

sub _verify_headers {

    my $fh               = shift;
    my $file             = shift;
    my @required_headers = @{ +shift };

    my $headerline = trim( scalar(<$fh>) );
    my @headers = split( "\t", $headerline );

    if ( scalar @required_headers ) {
        foreach my $required_header (@required_headers) {
            if ( not $required_header ~~ @headers ) {
                croak
                  "Required header $required_header not found in file $file";
            }
        }
    }

    return @headers;

} ## tidy end: sub _verify_headers

__END__
