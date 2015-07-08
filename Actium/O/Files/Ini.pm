# /Actium/O/Files/Ini.pm

# Class for reading .ini files.
# At the moment, and possibly permanently, a thin wrapper around
# Config::Tiny, but could be more later. Maybe.

# Legacy status: 4

package Actium::O::Files::Ini 0.010;

use Actium::Moose; ### DEP ###
use Actium::Types ('ActiumFolderLike');

use File::HomeDir; ### DEP ###
use Config::Tiny; ### DEP ###

around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;
	
	my %args;

	# one arg, hashref: args are in hashref
	# one arg, not hashref: one arg is filename
	# more than one arg: args are hash
	
	if ( @_ == 1 ) {
		if ( reftype $_[0] and reftype $_[0] eq 'HASH' ) {
			%args = %{ $_[0] };
		}
		else {
			%args = ( filename => $_[0] );
		}
	}
	else {
		%args = (@_);
	}

	#$args{folder} //= $ENV{HOME};
	$args{folder} //= File::HomeDir::->my_home;

	return $class->$orig(%args);

};

has 'filename' => (
   isa => 'Str',
   is => 'ro',
);

has 'folder' => (
	isa    => ActiumFolderLike,
	is     => 'ro',
	coerce => 1,
);

has 'filespec' => (
	is       => 'ro',
	init_arg => undef,
	builder  => '_build_filespec',
	lazy => 1,
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
	my $config = Config::Tiny::->read( $self->filespec );
	if (not defined $config) {
	    my $errstr = Config::Tiny::->errstr ;
	    if ($errstr =~ /does not exist/i or $errstr =~ /no such file/i) {
	       return +{ '_' => +{} }
	    }
	    croak $errstr;
	}
	my $ini_hoh = { %{$config} };
	# shallow clone, in order to get an unblessed copy
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
		return wantarray ? %{ $ini_hoh->{$section} } : $ini_hoh->{$section};
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

=head1 BUGS

Sections and keys are case-sensitive.
