# /Actium/O/Files/Ini.pm

# Class for reading .ini files.
# At the moment, and possibly permanently, a thin wrapper around
# Config::Tiny, but could be more later. Maybe.

# Subversion: $Id$

# Legacy status: 4

package Actium::O::Files::Ini 0.003;

use Actium::Moose;
use Actium::Types ('ActiumFolderLike');

use Config::Tiny;

has 'filename' => (
	isa => 'Str',
	is  => 'ro',
);

around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;

	my %args;

	# one arg, hashref: args are in hashref
	# one arg, not hashref: one arg is filename
	# more than one arg: args are hash

	if ( @_ == 1 ) {
		if ( reftype $_[0] eq 'HASH' ) {
			%args = %{ $_[0] };
		}
		else {
			%args = ( file => $_[0] );
		}
	}
	else {
		%args = (@_);
	}

	$args{folder} //= $ENV{HOME};

	return $class->$orig(%args);

};

has 'folder' => (
	isa    => 'ActiumFolderLike',
	is     => 'ro',
	#coerce => 1,
);

has 'filespec' => (
	is       => 'ro',
	init_arg => undef,
	builder  => '_build_filespec',
);

sub _build_filespec {
	my $self     = shift;
	my $folder   = $self->folder;
	my $filespec = $folder->make_filespec( $self->filename );
	return $filespec;
}

has '_values_r' => (
	is      => 'ro',
	isa     => 'HashRef[HashRef[Str]]',
	lazy    => 1,
	builder => '_build_values',
);

sub _build_values {
	my $self    = shift;
	my $ini_hoh = Config::Tiny->read( $self->filespec );
	return $ini_hoh;
}

sub value {
	my $self     = shift;
	my $section  = shift // '_';
	my $property = shift;
	my $ini_hoh  = $self->_values_r;
	return $ini_hoh->{$section}{$property};
}

sub section {
	my $self    = shift;
	my $section = shift // '_';
	my $ini_hoh = $self->_values_r;
	if ( exists $ini_hoh->{$section} ) {
		return %{ $ini_hoh->{$section} };
	}
	return;
}

sub sections {
	my $self    = shift;
	my $ini_hoh = $self->_values_r;
	return keys %{$ini_hoh};
}

1;

__END__
