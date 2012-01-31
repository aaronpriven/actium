# Actium/Files/TabDelimited.pm

# Class for reading Tab-Delimited files and returning them,
# line by line, to the caller.

# Subversion: $Id$

use warnings;
use 5.014;    # turns on features

package Actium::Files::TabDelimited 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Carp;
use English '-no_match_vars';
use Text::Trim;

use Actium::Signup;
use Actium::Term;
use Actium::Util('filename');

use Readonly;

Readonly my $LINES_BETWEEN_EMITTING_PERCENTAGES => 2000;

has folder => (
    is       => 'ro',
    isa      => 'Actium::Signup',
    required => 1,
);

has _passed_files_r => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    init_arg => 'files',
    traits   => ['Array'],
    default  => sub { [] },
    handles  => { _passed_files => 'elements', },
);

has glob_files => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    init_arg => 'glob_files',
    traits   => ['Array'],
    default  => sub { [] },
    handles  => { _globpatterns => 'elements', },
);

has _files_r => (
    isa     => 'ArrayRef[Str]',
    traits  => ['Array'],
    handles => {
        _files     => 'elements',
        _next_file => 'shift',
    },
    lazy    => 1,
    builder => '_build_files',
);

sub _build_files {
    my $self   = shift;
    my $folder = $self->folder;
    my @files  = $self->_passed_files;
    my @globs  = $self->_globpatterns;

    foreach (@files) {
        $_ = $folder->make_filespec($_);
    }

    foreach (@globs) {
        push @files, $folder->glob_plain_files($_);
    }

    if ( not scalar @files ) {
        my $path = $folder->display_path;
        emit_text( "No files found passed to " . __PACKAGE__ );
        emit_error;
        croak 'Files not found';

    }

    return \@files;
} ## tidy end: sub _build_files

has required_headers_r => (
    traits   => ['Array'],
    init_arg => 'required_headers',
    isa      => 'ArrayRef[Str]',
    is       => 'ro',
    required => 0,
    default  => sub { [] },
    handles  => { required_headers => 'elements' },
);

has _fh => (
    is      => 'rw',
    isa     => 'FileHandle',
    lazy    => 1,
    builder => '_first_fh',
);

has _current_file => (
    is  => 'rw',
    isa => 'Str',
);

has _linenum => (
    traits  => ['Counter'],
    is      => 'bare',
    isa     => 'Int',
    default => 0,
    handles => {
        _inc_linenum   => 'inc',
        _reset_linenum => 'reset',
    },
);

has _size => (
    is  => 'rw',
    isa => 'Int',
);

sub _first_fh {
    my $self = shift;
    my $fh   = $self->_open_fh();
    return $fh;
}

sub _next_fh {
    my $self         = shift;
    my $fh           = $self->_fh;
    my $current_file = $self->_current_file;
    emit_over "$current_file: 100%";
    emit_done;

    $self->close($fh);

    $fh = $self->_open_fh;
    return unless defined $fh;

    $self->_set_fh($fh);
    return $fh;
}

sub _open_fh {
    my $self = shift;
    my $file = $self->_next_file;

    return if not defined $file;

    my $current_file = filename($file);
    $self->_set_current_file($current_file);

    my $result = open my $fh, '<:encoding(UTF-8)', $file;

    if ( not $result ) {
        emit_error;
        croak "Can't open $file for reading: $OS_ERROR";
    }

    my $size = -s $file;
    $self->_set_size($size);
    $self->_reset_linenum;

    emit_over '$current_file: 0%';

    my $line = trim( scalar(<$fh>) );
    my @headers = split( "\t", $line );

    my @required_headers = $self->required_headers;
    if ( scalar @required_headers ) {
        foreach my $required_header (@required_headers) {
            if ( not $required_header ~~ @headers ) {
                emit_text
                  "Required header $required_header not found in file $file";
                emit_error;
                croak 'Required header not found';
            }
        }
    }

    $self->_set_headers_r( \@headers );

    return $fh;

} ## tidy end: sub _open_fh

has '_headers_r' => (
    # set by _next_fh
    traits  => ['Array'],
    is      => 'rw',
    handles => { _headers => 'elements' },
    isa     => 'ArrayRef[Str]',
);

sub next_line {
    my $self         = shift;
    my $fh           = $self->_fh;
    my $current_file = $self->_current_file;

    my $line;

    {
        return if not defined $fh;
        $line = readline($fh);
        if ( not defined $line ) {
            $fh = $self->_next_fh;
            redo;
        }
    }

    my $linenum = $self->_inc_linenum;
    if ( not $linenum % $LINES_BETWEEN_EMITTING_PERCENTAGES ) {
        emit_over( $current_file
              . sprintf( ': %.0f%%', tell($fh) / $self->_size * 100 ) )
          ;
    }

    my @headers = $self->_headers;
    my %value_of;
    @value_of{@headers} = trim( split( "\t", $line ) );

    return \%value_of;
} ## tidy end: sub next_line

sub close {
    my $self   = shift;
    my $fh     = $self->_fh;
    my $result = close $fh;

    if ( not $result ) {
        my $file = $self->_current_file;
        emit_error;
        croak "Can't close file for reading: $OS_ERROR";
    }

}

no Moose;
__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

__END__
