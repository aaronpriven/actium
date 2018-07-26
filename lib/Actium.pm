package Actium 0.014;

use utf8;
use 5.024;
use warnings;

BEGIN {
    # make the 'u' package an alias to this package
    *u:: = \*Actium::;
}

use Carp;                                 ### DEP ###
use Const::Fast;                          ### DEP ###
use Module::Runtime('require_module');    ### DEP ###
use Import::Into;                         ### DEP ###
use Kavorka ( fun => { -as => 'func' } ); ### DEP ###

use experimental ('refaliasing');

# The preamble to Actium perl modules.
# Imports things that are common to (many) modules.
# inspired by http://www.perladvent.org/2012/2012-12-16.html

## no critic (RequirePodAtEnd)

=encoding utf8

=head1 NAME

Actium - Common routines and imports for Actium programs

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Actium; # in a procedural module or non-Moose class

 use Actium ('class'); # in a Moose class

 use Actium ('role'); # in a Moose role

=head1 DESCRIPTION

Actium.pm provides the boilerplate code that should be common to all
Actium modules. It contains a number of utility routines, exports a
number of constants, and further imports symbols from a number of other
modules into each namespace.

=cut

=head1 CONSTANTS

The following constants are exported into the namespace of each module.

=over

=item $EMPTY

The empty string.

=item $CRLF

A carriage return followed by a line feed ("\r\n").

=item $SPACE

A space.

=item $KEY_SEPARATOR

This contains the C<^]> character (ASCII 29, "Group Separator"), which
is used by FileMaker to separate entries in repeating fields. It is
also used by various Actium routines to separate values, e.g., the
Hastus Standard AVL routines use it in hash keys when two or more
values are needed to uniquely identify a record. (This is the same
basic idea as that intended by perl's C<$;> variable [see
L<perlvar/$;>].)

=item $MINS_IN_12HRS

The number of minutes in 12 hours (12 times 60, or 720).

=item @DIRCODES

Alphabetic two-character direction codes (NB representing northbound, 
SB representing southbound, etc.)  The original few were based on
transitinfo.org directions, but have been extended to include kinds of
directions that didn't exist back then.

This should be moved to Actium::O::Dir when other modules not using it
are changed.

=item @TRANSBAY_NOLOCALS

Transbay lines where local riding is prohibited.

This should no longer be used, and instead the appropriate field from
the Lines table in the Actium database used instead.

=back

=cut

const my $EMPTY         => q[];
const my $CRLF          => qq{\cM\cJ};
const my $SPACE         => q{ };
const my $KEY_SEPARATOR => "\c]";
const my $MINS_IN_12HRS => ( 12 * 60 );
const my @TRANSBAY_NOLOCALS =>
  (qw/B FS G H J L LA LC NX NX1 NX2 NX3 NX4 NXC OX P S SB U V W Z/);

const my @DIRCODES => qw( NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN  A  B );
#  Hastus                 0  1  3  2  4  5  6  7  8  9  10 11 12 13 14 15

=head1 IMPORTED MODULES

Unless otherwise specified, the modules below are imported into the
calling module using the default parameters, i.e., as if it were a
plain "use Module".

=head2 CLASSES

In addition to modules listed later, the following module is imported
into modules that use Actium with the 'class' parameter.

=over

=item *

L<Moose|Moose>

=back

=head2 ROLES

In addition to modules listed later, the following module is imported
into modules that use Actium with the 'role' parameter.

=over

=item *

L<Moose::Role|Moose::Role>

=back

=head2 CLASSES OR ROLES

In addition to modules listed later, the following module is imported
into modules that use Actium with either the 'class' or the 'role'
parameter.

=over

=item *

L<MooseX::MarkAsMethods|MooseX::MarkAsMethods>

MooseX::MarkAsMethods is imported with parameters "autoclean => 1".

=item *

L<Actium::MooseX::BuildTriggerShortcuts|Actium::MooseX::BuildTriggerShortcuts>

=item *

L<Actium::MooseX::PredicateClearerShortcuts|Actium::MooseX::PredicateClearerShortcuts>

=item *

L<Actium::MooseX::Rwp|Actium::MooseX::Rwp>

=item *

L<Actium::MooseX::BuiltIsRo|Actium::MooseX::BuiltIsRo>

=item *

L<MooseX::StrictConstructor|MooseX::StrictConstructor>

=item *

L<MooseX::SemiAffordanceAccessor|MooseX::SemiAffordanceAccessor>

=item *

L<Moose::Util::TypeConstraints|Moose::Util::TypeConstraints>

=back

=head2 All modules

The following modules are imported into all modules, whether a class,
role, or other type of module.

=over

=item *

L<Kavorka|Kavorka>

All modules will have the function keyword imported as "func" rather
than Kavorka's default "fun." Classes and roles will also have the
"method" keyword and all method modifiers ("after", "around" and
"before").

(The reason for importing 'fun' as 'func' is twofold: first, Eclipse
supports the Method::Signatures keywords "func" and "method". Second, I
think it looks weird to have the abbreviation for one word to be
another word.)

=item *

L<Actium::Crier|Actium::Crier>

The "cry" and "last_cry" subroutines will be exported into the 
caller's namespace.

=item *

L<Carp|Carp>

=item *

L<Const::Fast|Const::Fast>

=item *

L<English|English>

Although it is not important in more recent perls, the '-no_match_vars'
 parameter is specified when loading the English module.

=item *

L<autodie|autodie>

=item *

L<feature|feature>

The ":5.24" feature bundle is loaded into each module, as well as  the
"refaliasing" and "postderef_qq" features.

=item *

L<indirect|indirect>

The indirect module will behave as though "no indirect" had been used 
in the calling module.

=item *

L<open|open>

The ':utf8' parameter is passed, as well as the ':std' parameter  to
ensure that STDIN, STDOUT, and STDERR are treated as UTF-8 also.

=item *

L<strict|strict>

=item *

L<utf8|utf8>

=item *

L<warnings|warnings>

The default warnings are used, except that the following warnings are 
turned off: 'experimental::refaliasing' and 'experimental::postderef'.

=back

=cut

{

    my $caller;

    sub _do_import {
        my $module = shift;
        require_module($module);
        $module->import::into( $caller, @_ );
        return;
    }

    sub _do_unimport {
        my $module = shift;
        require_module($module);
        $module->unimport::out_of( $caller, @_ );
        return;
    }

    sub import {
        my $class = shift;
        my $type = shift || q{};
        $caller = caller;

        # constants and exported routines
        {
            ## no critic (ProhibitProlongedStrictureOverride)
            no strict 'refs';
            *{ $caller . '::EMPTY' }             = \$EMPTY;
            *{ $caller . '::CRLF' }              = \$CRLF;
            *{ $caller . '::SPACE' }             = \$SPACE;
            *{ $caller . '::MINS_IN_12HRS' }     = \$MINS_IN_12HRS;
            *{ $caller . '::KEY_SEPARATOR' }     = \$KEY_SEPARATOR;
            *{ $caller . '::TRANSBAY_NOLOCALS' } = \@TRANSBAY_NOLOCALS;
            *{ $caller . '::DIRCODES' }          = \@DIRCODES;
            *{ $caller . '::env' }               = \&env;
            ## use critic
        }

        if ($type) {
            if ( $type eq 'class' ) {
                _do_import 'Moose';
            }
            elsif ( $type eq 'role' ) {
                _do_import 'Moose::Role';
            }
            else {
                croak "Unknown module type $type";
            }

            # either class or role

            _do_import 'MooseX::MarkAsMethods', autoclean => 1;
            _do_import 'Actium::MooseX::BuildTriggerShortcuts';
            _do_import 'Actium::MooseX::PredicateClearerShortcuts';
            _do_import 'Actium::MooseX::Rwp';
            _do_import 'Actium::MooseX::BuiltIsRo';
            _do_import 'MooseX::StrictConstructor';
            _do_import 'MooseX::SemiAffordanceAccessor';
            _do_import 'Moose::Util::TypeConstraints';
            _do_import 'Kavorka',
              fun => { -as => 'func' },
              'method', '-allmodifiers';
        } ## tidy end: if ($type)
        else {
            _do_import( 'Kavorka', fun => { -as => 'func' } );
        }

        # MooseX::MarkAsMethods ### DEP ###
        # MooseX::StrictConstructor ### DEP ###
        # MooseX::SemiAffordanceAccessor ### DEP ###
        # Moose ### DEP ###
        # Moose::Role ### DEP ###
        # MooseX::MarkAsMethods ### DEP ###
        # indirect ### DEP ###

        _do_import 'Actium::Crier', qw/cry last_cry/;
        _do_import 'Carp';
        _do_import 'Const::Fast';
        _do_import 'English', '-no_match_vars';

        _do_import 'autodie';
        _do_import 'feature', qw/:5.24 refaliasing postderef_qq/;
        _do_unimport 'indirect';
        _do_import 'open', qw/:std :utf8/;
        _do_import 'strict';
        _do_import 'utf8';
        _do_import 'warnings';
        _do_unimport 'warnings', 'experimental::refaliasing',
          'experimental::postderef';

        return;

    } ## tidy end: sub import

}

use Actium::Sorting::Line(qw/byline sortbyline/);
use HTML::Entities (qw[encode_entities]);                        ### DEP ###
use List::Util     (qw(all any first max min none sum uniq));    ### DEP ###
use List::MoreUtils                                              ### DEP ###
  (qw(firstidx mesh natatime));
# List::MoreUtils::XS  ### DEP ###
use POSIX            (qw/ceil floor/);                           ### DEP ###
use Params::Validate (qw(validate));                             ### DEP ###
use Ref::Util                                                    ### DEP ###
  ( qw( is_arrayref is_blessed_ref is_coderef is_hashref
      is_ioref is_plain_arrayref is_plain_hashref is_ref)
  );
use Scalar::Util                                                 ### DEP ###
  (qw( blessed looks_like_number refaddr reftype ));
use Text::Trim('trim');                                          ### DEP ###

=head1 SUBROUTINES 

Except for C<env>, none of these subroutines are, or can be, exported 
into the caller's namespace. They are accessible using the fully
qualified name, e.g. "Actium::byline".

The only subroutine that is exported is C<env>. It is always exported.

As a convenience, the package "u" was made an alias for the "Actium"
package, so the routines are also accessible using, e.g., "u::byline."
This usage has now been deprecated and will eventually go away. It's
not that much harder to type "Actium::byline", especially if "Actium::"
is bound to a key in your editor.

=head2 ACTIUM ENVIRONMENT

=cut

my $env;

sub env () {
    return $env;
}

sub _set_env {
    $env = shift;
    return;
}

=over

=item env

This returns the object representing the environment in which the
program operates. (This is not to be confused with the system
environment variables represented by L<%ENV|perlvar/%ENV>, which is
only one part of the operating environment.)

At the moment this is always going to be an Actium::CLI object,
although at some point if other operating environments are created
(Web, GUI, etc.)  this may change.

=back

=head2 LISTS

=head3 Joining Lists into Strings

=over

=item joinempty

Takes the list passed to it and joins it together as a simple string. 
A quicker way to type "join ('' , @list)".

=cut

sub joinempty {
    return join( q[], map { $_ // q[] } @_ );
}

=item joinkey

Takes the list passed to it and joins it together, with each element
separated  by the C<$KEY_SEPARATOR> value. A quicker way to type "join
($KEY_SEPARATOR , @list)".

=cut

sub joinkey {
    return join( $KEY_SEPARATOR, map { $_ // q[] } @_ );
}

=item joinlf

Takes the list passed to it and joins it together, with each element
separated  by a line feed. A quicker way to type 'join ("\n" , @list)'.

=cut 

sub joinlf {
    return join( "\n", map { $_ // q[] } @_ );
}

=item jointab

Takes the list passed to it and joins it together, with each element
separated  by tabs. A quicker way to type 'join ("\t" , @list)'.

=cut

sub jointab {
    return join( "\t", map { $_ // q[] } @_ );
}

=item joinseries ( [ I<hashref>, ] I<list>)

This routine is designed to display a list as it should appear in
English. (All items passed to joinseries must be defined, scalar values.)

 joinseries(qw/Sally Carlos/);
 # 'Sally and Carlos'
 joinseries(qw/Fred Sally Carlos/);
 # 'Fred, Sally and Carlos'
 joinseries(qw/Mei Fred Sally Carlos/);
 # 'Mei, Fred, Sally and Carlos'
   
If the first is a hash reference, the keys and values are treated as options.
Valid options are:

=over

=item conjunction

The word used to connect the penultimate and last items in the list.
If passed 'undef' or if not specified, uses "and".
Spaces are always placed on either side of the conjunction.

 joinseries( { conjunction => 'or' } , qw/Fred Sally Carlos/);
 # 'Fred, Sally or Carlos'
 
=item oxford

A boolean value; if true, the separator (see below) is placed after the
penultimate item in the list. If passed 'undef' or not specified, it
will be treated as though a false value had been supplied, unless a
custom separator is supplied, in which case it will be treated as though
a true value had been supplied. 

 joinseries( { oxford => '1' } , qw/Fred Sally Carlos/);
 # 'Fred, Sally, and Carlos'
 
=item separator

The punctuation used to separate the appropriate items.  If not
specified, uses a comma.  A trailing space is always added to the
separator.

Note that specifying this item changes the default value of
"oxford," above.

 joinseries( { separator => ';' } , qw/Sasha Aisha Raj/);
 # 'Sasha; Aisha; and Raj'
 
=cut

sub joinseries {
    my %options;
    if ( is_hashref( $_[0] ) ) {
        %options = shift->%*;
    }

    state $subname = __PACKAGE__ . '::joinseries';

    my ( $separator, $oxford, $conjunction );

    $separator = delete $options{separator};
    if ( defined $separator ) {
        $oxford = delete $options{oxford} // 1;
        $separator .= $SPACE;
    }
    else {
        $oxford = delete $options{oxford} // 0;
        $separator = q[, ];
    }

    $conjunction = delete $options{conjunction} // 'and';

    croak 'Invalid options ('
      . joinseries( keys %options )
      . ") passed to $subname"
      if %options;

    croak "No items passed to $subname" unless @_;
    croak "Reference passed to $subname"
      if List::Util::any { is_ref($_) } @_;
    croak "Undefined value passed to $subname"
      unless List::Util::all { defined($_) } @_;

    return $_[0] if 1 == @_;
    return "$_[0] $conjunction $_[1]" if 2 == @_;

    my $final = pop;
    if ($oxford) {
        return ( join( $separator, @_ ) . " $conjunction $final" );
    }
    else {
        return ( join( $separator, @_, "$conjunction $final" ) );
    }

} ## tidy end: sub joinseries

=item joinseries_with (I<conjunction> , I<item>, I<item>, ...)

B<Deprecated.> Like C<joinseries>, but instead of an optional hashref,
the first argument is always the conjunction.

   joinseries_with('or' , qw(Sasha Aisha Raj)); 
   # 'Sasha, Aisha or Raj'

=cut

func joinseries_with (Str $conjunction!, Str @things!) {
    return joinseries( { conjunction => $conjunction }, @things );
}

=back

=head3 Mathematics on Lists

=over

=item max

L<C<max> from List::Util|List::Util/max>

=item mean

The arithmetic mean of its arguments, or if the first argument is an
array ref, of the members of that array.

=cut

sub mean {

    if ( is_plain_arrayref( $_[0] ) ) {
        return sum( @{ $_[0] } ) / scalar( @{ $_[0] } );
    }

    return sum(@_) / scalar(@_);
}

=item min

L<C<min> from List::Util|List::Util/min>

=item population_stdev

The population standard deviation of its arguments, or if the first 
argument is an array ref, of the members of that array.

=cut

sub population_stdev {

    my @popul = is_plain_arrayref( $_[0] ) ? @{ $_[0] } : @_;

    my $themean = mean(@popul);
    return sqrt( mean( [ map { $_**2 } @popul ] ) - ( $themean**2 ) );
}

=item sum

L<C<sum> from List::Util|List::Util/sum>

=back

=head3 Searching and Comparison of Lists

=over

=item all

L<C<all> from List::Util|List::Util/all>

=item all_eq

Returns a boolean value: true if the first value is equal to all the
subsequent values (using C<eq>), false otherwise.

=cut

sub all_eq {
    my $first = shift;
    my @rest  = @_;
    return all { $_ eq $first } @rest;
}

=item any

L<C<any> from List::Util|List::Util/any>

=item first

L<C<first> from List::Util|List::Util/first>.

=item firstidx

L<C<firstidx> from List::MoreUtils|List::MoreUtils/firstidx>.

=item folded_in

Returns true if first argument, when case-folded, is equal to the any
of the subsequent arguments, when those are case-folded. If the second
argument is an arrayref, compares the elements of that array.

See L<fc in perlfunc|perlfunc/fc> for more information about case
folding.

=cut

sub folded_in {

    my $item = fc(shift);
    if ( is_plain_arrayref( $_[0] ) ) {
        return any { $item eq fc($_) } @{ $_[0] };
    }
    return any { $item eq fc($_) } @_;
}

=item in

Returns true if the first argument is equal to (using the C<eq>
operator) any of the subsequent arguments, or if the second argument is
a plain arrayref,  any of the elements of that array.

=cut

sub in {

    # is-an-element-of (stringwise)

    my $item = shift;
    if ( is_plain_arrayref( $_[0] ) ) {
        return any { $item eq $_ } @{ $_[0] };
    }

    return any { $item eq $_ } @_;

}

=item none

L<C<none> from List::Util|List::Util/none>.

=back

=head3 Other List Functions

=over

=item byline

L<C<byline> from Actium::Sorting::Line|Actium::Sorting::Line/byline>

=item mesh

L<C<mesh> from List::MoreUtils|List::MoreUtils/mesh>.

=item natatime

L<C<natatime> from List::MoreUtils|List::MoreUtils/natatime>.

=item sortbyline

L<C<sortbyline> from
Actium::Sorting::Line|Actium::Sorting::Line/sortbyline>

=item uniq

L<C<uniq> from List::Util|List::Util/uniq>.

=back

=head2 STRINGS

=head3 Filename Functions

=over

=item add_before_extension

Treats the first argument as a file specification and adds the second
argument to it, prior to the extension, separated from it by a hyphen.
So:

 $file = add_before_extension("sam.txt", "fred");
 # $file is "sam-fred.txt"

=cut

sub add_before_extension {

    my $input_path = shift;
    my $addition   = shift;

    my ( $volume, $folders, $filename ) = File::Spec->splitpath($input_path);
    my ( $filepart, $ext ) = file_ext($filename);

    my $output_path
      = File::Spec->catpath( $volume, $folders, "$filepart-$addition.$ext" );

    return ($output_path);

}

=item filename

Treats the first argument as a file specification and returns the 
filename portion (as determined by File::Spec->splitpath ).

=cut

sub filename {

    my $filespec = shift;
    my $filename;
    ( undef, undef, $filename ) = File::Spec->splitpath($filespec);
    return $filename;
}

=item file_ext

Treats the first argument as a file specification and returns two
strings: the filename without extension, and the extension.

=cut

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

sub u_columns {
    my $str = shift;
    require Unicode::GCString;    ### DEP ###
    return Unicode::GCString->new("$str")->columns;
    # the quotes are necessary because GCString doesn't work properly
    # with variables Perl thinks are numbers. It doesn't automatically
    # stringify them.
}

=item u_pad

Pads a string with spaces to a number of columns. The first argument
should be the string, and the second the number of columns.

 $y = u_pad("x", 2);
 # returns  "x "
 $z = u_pad("柱", 4);
 # returns ("柱  ");

Uses u_columns internally to determine the width of the text.

=cut

sub u_pad {
    my $text  = shift;
    my $width = shift;

    my $textwidth = u_columns($text);

    return $text if $textwidth >= $width;

    my $spaces = ( q[ ] x ( $width - $textwidth ) );

    return ( $text . $spaces );

}

=item u_wrap (I<string>, I<min_columns>, I<max_columns>)

Takes a string and wraps it to a number of columns, producing  a series
of shorter lines, using the  L<Unicode::Linebreak|Unicode::LineBreak>
module. If the string has embedded newlines, these are taken as
separating paragraphs.

The first argument is the string to wrap.

The second argument, if present, is the minimum number of columns --
ColMin from Unicode::LineBreak. If not present, 0 will be used.

The third argment, if present, is the maximum number of columns --
ColMax from Unicode::LineBreak. If not present, 79 will be used.

=cut

const my $DEFAULT_LINE_LENGTH  => 79;
const my $DEFAULT_MINIMUM_LINE => 3;

sub u_wrap {
    my ( $msg, $min, $max ) = @_;

    return unless defined $msg;

    $min //= 0;
    $max ||= $DEFAULT_LINE_LENGTH;

    return $msg
      if $max < $DEFAULT_MINIMUM_LINE or $min > $max;

    require Unicode::LineBreak;    ### DEP ###

    state $breaker = Unicode::LineBreak::->new();
    $breaker->config( ColMax => $max, ColMin => $min );

    # First split on newlines
    my @lines;
    foreach my $line ( split( /\n/, $msg ) ) {

        my $linewidth = u_columns($line);
        if ( $linewidth <= $max ) {
            push @lines, $line;
        }
        else {
            push @lines, $breaker->break($line);
        }

    }
    foreach (@lines) {
        s/\s+\z//;
    }

    return wantarray ? @lines : joinlf(@lines);

} ## tidy end: sub u_wrap

=item u_trim_to_columns

Trims an input string to a particular number of columns.

 $x = u_trim_to_columns("Barney", 4);
 # returns "Barn"

=cut

sub u_trim_to_columns {
    my $text        = shift;
    my $max_columns = shift;

    require Unicode::GCString;    ### DEP ###

    my $gc = Unicode::GCString::->new("$text");
    # stringification of numbers bug means have to do so explicitly

    while ( $gc->columns > $max_columns ) {
        $gc->substr( -1, 1, q[] );
    }

    return $gc->as_string if $gc->columns == $max_columns;

    return u_pad( $gc->as_string, $max_columns );
    # in case we trimmed off a double-wide character,
    # pad it to the right number of columns

} ## tidy end: sub u_trim_to_columns

=back

=head3 Other String Functions

=over
 
=item define
 
For each value passed to it, returns either that value, if defined, or
the empty string, if not.

In scalar context, returns the final value.

=cut

sub define {
    return List::MoreUtils::apply { $_ //= q[] } @_;
}

=item encode_entities

L<C<encode_entities> from
HTML::Entities|HTML::Entities/encode_entities>.

=item feq

Returns a boolean value:  true if, when case-folded (using C<fc>),  the
first argument is equal to its second; otherwise false.

=cut

sub feq {
    my ( $x, $y ) = @_;
    return fc($x) eq fc($y);
}

=item fne

Returns a boolean value:  true if, when case-folded (using C<fc>),  the
first argument is not equal to its second; otherwise false.

=cut

sub fne {
    my ( $x, $y ) = @_;
    return fc($x) ne fc($y);
}

=item trim

L<C<trim> from Text::Trim|Text::Trim/trim>.

=back

=head2 NUMBERS

=over

=item ceil

L<C<ceil> from POSIX|POSIX/ceil>.

=item display_percent

Returns the first argument as a whole percentage: e.g., if the value is
0.252, will return "25%".

=cut

sub display_percent {
    my $val   = shift;
    my $total = shift;
    ## no critic (ProhibitMagicNumbers)
    return sprintf( ' %.0f%%', $val / $total * 100 );
    ## use critic
}

=item floor

L<C<floor> from POSIX|POSIX/floor>.

=item looks_like_number

L<C<looks_like_number> from
Scalar::Util|Scalar::Util/looks_like_number>.


=back

=head2 REFERENCES

=over

=item blessed

L<C<blessed> from Scalar::Util|Scalar::Util/blessed>.

=item hashref

Returns its argument if there is only one argument and it is a plain
hashref. Otherwise creates a hash from its arguments. Useful in
accepting either a hashref or a plain hash as arguments to a function.

=cut

sub hashref {
    return $_[0] if is_plain_hashref( $_[0] ) and 1 == @_;
    croak 'Odd number of elements passed to ' . __PACKAGE__ . '::hashref'
      if @_ % 2;
    return {@_};
}

=item flatten

Takes a list and flattens any (unblessed) array references in it, 
ensuring that the contents of any lists of lists are returned as
individual items.

So

 @list =  ( 'A' , [ 'B1' , 'B2', [ 'B3A' , 'B3B' ], ] ) ; 

 $array_ref = flatten(@list);
 @flatarray = flatten(@list);
 # $array_ref = [ 'A', 'B1', 'B2', 'B3A', 'B3B' ]
 # @flatarray = ('A', 'B1', 'B2', 'B3A', 'B3B') 

Returns its result as an array reference in scalar context, but as a
list in list context.

=cut 

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

=item is_arrayref

L<C<is_arrayref> from Ref::Util|Ref::Util/is_arrayref>.

=item is_blessed_ref

L<C<is_blessed_ref> from Ref::Util|Ref::Util/is_blessed_ref>.

=item is_coderef

L<C<is_coderef> from Ref::Util|Ref::Util/is_coderef>.

=item is_hashref

L<C<is_hashref> from Ref::Util|Ref::Util/is_hashref>.

=item is_ioref

L<C<is_ioref> from Ref::Util|Ref::Util/is_ioref>.

=item is_plain_arrayref

L<C<is_plain_arrayref> from Ref::Util|Ref::Util/is_plain_arrayref>.

=item is_plain_hashref

L<C<is_plain_hashref> from Ref::Util|Ref::Util/is_plain_hashref>.

=item is_ref

L<C<is_ref> from Ref::Util|Ref::Util/is_ref>.

=item refaddr

L<C<refaddr> from Scalar::Util|Scalar::Util/refaddr>.

=item reftype

L<C<reftype> from Scalar::Util|Scalar::Util/reftype>.

=back

=head2 OTHER FUNCTIONS

=over

=item dumpstr

This returns a string --  a dump from the Data::Printer module of the
passed data structure, suitable for displaying and debugging.

=cut

sub dumpstr (\[@$%&];%) {    ## no critic (ProhibitSubroutinePrototypes)
                              # prototype copied from Data::Printer::np
    require Data::Printer;    ### DEP ###
    return Data::Printer::np(
        @_,
        hash_separator => ' => ',
        class => { expand => 'all', parents => 0, show_methods => 'none', },
    );
}

=item immut

The B<immut> routine is designed to be used in place of the rather
unwieldy

    __PACKAGE__->meta->make_immutable

The C<immut> routine simply performs this on the calling package,
making the Moose class immutable.

=cut

sub immut {
    my $package = caller;
    $package->meta->make_immutable;
    return;
}

=item validate

L<C<validate> from Params::Validate|Params::Validate/validate>.

=cut

1;

__END__

=back

=head1 DIAGNOSTICS

=over

=item *

Unknown module type $type

A module type other than 'class' or 'role' was passed in the 'use
Actium'  statement.

=item *

No arguments passed to Actium::joinseries

The joinseries function was called without any valid arguments. Supply
strings to join.

Odd number of elements passed to Actium::hashref

The hashref function was called with an odd number of arguments (other
than a single hashref argument), so cannot be made into hash reference.

=back

=head1 DEPENDENCIES

Actium.pm requires the following modules or distributions to be
present:

=over

=item *

Perl 5.24 or greater

=item *

Actium::Crier

=item *

Actium::Sorting::Line

=item *

Const::Fast

=item *

HTML::Entities

=item *

indirect

=item *

Import::Into

=item *

Kavorka

=item *

List::MoreUtils

=item *

Module::Runtime

=item *

Params::Validate

=item *

Ref::Util

=item *

Text::Trim

=back

When used for a Moose class or role, it requires the following
distributions:

=over

=item *

Moose (and its accompanying modules)

=item *

Actium::MooseX::BuiltIsRo

=item *

Actium::MooseX::PredicateClearerShortcuts

=item *

Actium::MooseX::BuildTriggerShortcuts

=item *

Actium::MooseX::Rwp

=item *

MooseX::MarkAsMethods

=item *

MooseX::SemiAffordanceAccessor

=item *

MooseX::StrictConstructor

=back

Certain subroutines also require the following:

=over

=item *

Data::Printer

=item *

Unicode::GCString

=item *

Unicode::LineBreak

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

