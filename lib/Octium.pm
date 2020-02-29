package Octium 0.016;

use Actium;

# imported into the caller's namespace
#
use parent 'Exporter';
our @EXPORT = qw/@TRANSBAY_NOLOCALS @DIRCODES cry last_cry/;

const our @TRANSBAY_NOLOCALS =>
  (qw/BF3 FS G H J L LA LC NX NX1 NX2 NX3 NX4 NXC OX P S SB U V W Z/);

const our @DIRCODES => qw( NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN  A  B );
#  Hastus                 0  1  3  2  4  5  6  7  8  9  10 11 12 13 14 15

sub cry      { goto &Actium::cry; }
sub last_cry { goto &Actium::last_cry; }

# duplicating Actium into Octium

use List::Util       (qw(max min none sum uniq));    ### DEP ###
use Params::Validate (qw(validate));                 ### DEP ###
use Ref::Util                                        ### DEP ###
  ( qw( is_arrayref is_blessed_ref is_coderef is_hashref
      is_ioref is_plain_arrayref is_plain_hashref is_ref)
  );
use Scalar::Util                                     ### DEP ###
  (qw( blessed looks_like_number refaddr reftype ));
use Text::Trim('trim');                              ### DEP ###
use Statistics::Lite (qw/mean/);                     ### DEP ###

sub joinlf { goto &Actium::joinlf }

sub jointab { goto &Actium::jointab }

sub in        { goto &Actium::in }
sub folded_in { goto &Actium::folded_in }

sub population_stdev {

    my @popul = is_plain_arrayref( $_[0] ) ? @{ $_[0] } : @_;

    my $themean = mean(@popul);
    return sqrt( mean( [ map { $_**2 } @popul ] ) - ( $themean**2 ) );
}

sub add_before_extension {

    my $input_path = shift;
    my $addition   = shift;

    my ( $volume, $folders, $filename ) = File::Spec->splitpath($input_path);
    my ( $filepart, $ext ) = file_ext($filename);

    my $output_path
      = File::Spec->catpath( $volume, $folders, "$filepart-$addition.$ext" );

    return ($output_path);

}

sub filename {

    my $filespec = shift;
    my $filename;
    ( undef, undef, $filename ) = File::Spec->splitpath($filespec);
    return $filename;
}

sub file_ext {
    my $filespec = shift;                 # works on filespecs or filenames
    my $filename = filename($filespec);
    my ( $filepart, $ext )
      = $filename =~ m{(.*)    # as many characters as possible
                      [.]     # a dot
                      ([^.]+) # one or more non-dot characters
                      \z}sx;
    return ( $filepart, $ext );
}

=back

=head3 Unicode Column Functions

These utilities are used when displaying text in a monospaced typeface,
to ensure that text with combining characters and wide characters are 
shown taking up the proper width.

=over

=item u_columns

This returns the number of columns in its first argument, as determined
by the L<Unicode::GCString|Unicode::GCString> module.

=cut

sub u_columns { goto &Actium::u_columns }

sub u_pad {
    my $text  = shift;
    my $width = shift;
    return Actium::u_pad( text => $text, width => $width );
}

sub u_wrap {
    my ( $msg, $min, $max ) = @_;
    return Actium::u_wrap( $msg, min_columns => $min, max_columns => $max );
}

sub u_trim_to_columns {
    my $text        = shift;
    my $max_columns = shift;
    return Actium::u_trim_to_columns(
        string  => $text,
        columns => $max_columns
    );
}

sub define { goto &Actium::define; }

sub feq { goto &Actium::feq }
sub fne { goto &Actium::fne }

sub display_percent { goto &Actium::display_percent }

sub flatten {

    my @results;

    while (@_) {
        my $element = shift @_;
        if ( is_plain_arrayref($element) ) {
            unshift @_, @{$element};
        }
        else {
            push @results, $element;
        }
    }

    return wantarray ? @results : \@results;

}

1;
