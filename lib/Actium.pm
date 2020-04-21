package Actium 0.014;    ## no critic 'ProhibitExcessMainComplexity'
# vimcolor: #132600

use utf8;
use 5.024;
use warnings;

use Carp;                                 ### DEP ###
use Const::Fast;                          ### DEP ###
use Module::Runtime('require_module');    ### DEP ###
use Import::Into;                         ### DEP ###
use Kavorka (qw/func multi/);             ### DEP ###

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

=head2 $EMPTY

The empty string.

=head2 $CRLF

A carriage return followed by a line feed ("\r\n").

=head2 $SPACE

A space.

=cut

const our $EMPTY => q[];
const our $CRLF  => qq{\cM\cJ};
const our $SPACE => q{ };

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

=item *

L<MooseX::XSAccessor|MooseX::XSAccessor>

=back

=head2 CLASSES (No XS)

In addition to modules listed later, the following module is imported
into modules that use Actium with the 'class-noxs' parameter. (I ran
into issues where L<MooseX::XSAccessor|MooseX::XSAccessor> caused
problems with methods being prematurely eliminated inside DEMOLISH
blocks.)

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

L<Actium::MooseX::BuilderShortcut|Actium::MooseX::BuilderShortcut>

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

=back

=head2 ALL MODULES

The following modules are imported into all modules, whether a class,
role, or other type of module.

=over

=item *

L<Carp|Carp>

=item *

L<Const::Fast|Const::Fast>

=item *

L<English|English>

Although it is not important in more recent perls, the '-no_match_vars'
parameter is specified when loading the English module.

=item *

L<Kavorka|Kavorka>

All modules will have the "multi" keyword imported, as well as the
function keyword -- imported as "func" rather than Kavorka's default
"fun." Classes and roles will also have the "method" keyword and all
method modifiers ("after", "around", "before", "augment", "override") .

(The reason for importing 'fun' as 'func' is twofold: first, Eclipse
supports the Method::Signatures keywords "func" and "method". Second, I
think it looks weird to have the abbreviation for one word to be
another word.)

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

use parent 'Exporter';
our @EXPORT = qw/$EMPTY $CRLF $SPACE env/;

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
        my $type  = shift // q{};
        $caller = caller;

        __PACKAGE__->export_to_level(1);
        # don't allow overriding exports, at least for now

        if ($type) {
            if ( $type eq 'class' ) {
                _do_import 'Moose';
                _do_import 'MooseX::XSAccessor';
            }
            elsif ( $type eq 'class-noxs' ) {
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
            _do_import 'Actium::MooseX::BuilderShortcut';
            _do_import 'Actium::MooseX::PredicateClearerShortcuts';
            _do_import 'Actium::MooseX::Rwp';
            _do_import 'Actium::MooseX::BuiltIsRo';
            _do_import 'MooseX::StrictConstructor';
            _do_import 'MooseX::SemiAffordanceAccessor';
            _do_import 'Kavorka', qw/func multi method -allmodifiers/;
        }
        else {
            _do_import( 'Kavorka', qw/func multi/ );
        }

        # MooseX::XSAccessor ### DEP ###
        # MooseX::MarkAsMethods ### DEP ###
        # MooseX::StrictConstructor ### DEP ###
        # MooseX::SemiAffordanceAccessor ### DEP ###
        # Moose ### DEP ###
        # Moose::Role ### DEP ###
        # MooseX::MarkAsMethods ### DEP ###
        # indirect ### DEP ###

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

    }

}

use HTML::Entities (qw[encode_entities]);                        ### DEP ###
use List::Util     (qw(all any first max min none sum uniq));    ### DEP ###
use List::MoreUtils 0.426 (qw(arrayify firstidx mesh natatime)); ### DEP ###
# List::MoreUtils::XS  ### DEP ###
use POSIX (qw/ceil floor/);                                      ### DEP ###
use Ref::Util                                                    ### DEP ###
  ( qw( is_arrayref is_blessed_ref is_coderef is_hashref
      is_ioref is_plain_arrayref is_plain_hashref is_ref)
  );
use Scalar::Util                                                 ### DEP ###
  (qw( blessed looks_like_number refaddr reftype ));
use Statistics::Lite (qw/mean stddevp/);                         ### DEP ###
use Text::Trim('trim');                                          ### DEP ###

=head1 SUBROUTINES

Except for C<env>, none of these subroutines are, or can be, exported.
They can be used with the fully qualified name, e.g. "Actium::byline".

The only subroutine that is exported is C<env>. It is always exported.

=head2 ACTIUM ENVIRONMENT

=head3 Environment object

=head4 env

This returns the object representing the environment in which the
program operates. (This is not to be confused with the system
environment variables represented by L<%ENV|perlvar/%ENV>, which is
only one part of the operating environment.)

At the moment this is always going to be an Actium::CLI object,
although at some point if other operating environments are created
(Web, GUI, etc.)  this may change.

=cut

my $env;

sub env () {
    return $env;
}

sub _set_env {
    $env = shift;
    return;
}

=head2 LISTS

=head3 Joining Lists into Strings

=head4 joincomma (@items)

Same as C<< joinseries(items => \@items) >>.  This uses the default,
which does not use the Oxford (serial) comma.

=cut

func joincomma (Str @items ) {
    return joinseries( items => \@items );
}

=head4 joinempty

Takes the list passed to it and joins it together as a simple string. A
quicker way to type "join ('' , @list)".

=cut

func joinempty ( Maybe[Str] @items ) {
    return join( q[], map { $_ // q[] } @items );
}

=head4 joinlf

Takes the list passed to it and joins it together, with each element
separated  by a line feed. A quicker way to type 'join ("\n" , @list)'.

=cut

func joinlf ( Maybe[Str] @items ) {
    return join( "\n", map { $_ // q[] } @items );
}

=head4 joinseries

This routine is designed to display a list as it should appear in
English.

For example:

 joinseries(items => [qw/Sally Carlos/]);
 # 'Sally and Carlos'
 joinseries(items => [qw/Fred Sally Carlos/]);
 # 'Fred, Sally and Carlos'
 joinseries(items => [qw/Mei Fred Sally Carlos/]);
 # 'Mei, Fred, Sally and Carlos'

There are four named parameters. Only "items" is mandatory.

=over

=item items

This is a reference to an array of the strings to be joined. They must
must be defined, scalar values.)

=item conjunction

The word used to connect the penultimate and last items in the list. If
passed 'undef' or if not specified, uses "and". Spaces are always
placed on either side of the conjunction.

 joinseries(  conjunction => 'or' , items => [ qw/Fred Sally Carlos/] );
 # 'Fred, Sally or Carlos'

=item oxford

A boolean value; if true, the separator (see below) is placed after the
penultimate item in the list. If passed 'undef' or not specified, it
will be treated as though a false value had been supplied, unless a
custom separator is supplied, in which case it will be treated as
though a true value had been supplied.

 joinseries(  oxford => '1' , items => [ qw/Fred Sally Carlos/] );
 # 'Fred, Sally, and Carlos'

=item separator

The punctuation used to separate the appropriate items.  If not
specified, uses a comma.  A trailing space is always added to the
separator.

Note that specifying this item changes the default value of "oxford,"
above.

 joinseries( { separator => ';' } , qw/Sasha Aisha Raj/);
 # 'Sasha; Aisha; and Raj'

=back

=cut

func joinseries (
   Str :@items is ref_alias,
   Str :$conjunction //= 'and',
   Bool :$oxford?,
   Str :$separator?,
   ) {

    # checking existence of keys in %_ distinguishes
    # an unspecified 'oxford' key from a specified "oxford => undef"
    my $oxford_specified = exists $_{oxford};

    if ( defined $separator ) {
        $oxford = 1 unless $oxford_specified;
        $separator =~ s/ *\z/ /;
    }
    else {
        $oxford    = 0 unless $oxford_specified;
        $separator = q[, ];
    }

    return $items[0]                          if 1 == @items;
    return "$items[0] $conjunction $items[1]" if 2 == @items;

    my @copied = @items;
    my $final  = pop @copied;
    if ($oxford) {
        return ( join( $separator, @copied, "$conjunction $final" ) );
    }
    else {
        return ( join( $separator, @copied ) . " $conjunction $final" );
    }

}

=head4 jointab

Takes the list passed to it and joins it together, with each element
separated  by tabs. A quicker way to type 'join ("\t" , @list)'.

=cut

func jointab ( Maybe[Str] @items ) {
    return join( "\t", map { $_ // q[] } @items );
}

=head3 Mathematics on Lists

=head4 max

L<< C<max> from List::Util|List::Util/max >>

=head4 mean

L<< C<mean> from Stastics::Lite|Statistics::Lite/mean >>

=head4 min

L<< C<min> from List::Util|List::Util/min >>

=head4 sum

L<< C<sum> from List::Util|List::Util/sum >>

=head3 Searching and Comparison of Lists

=head4 all

L<< C<all> from List::Util|List::Util/all >>

=head4 all_eq

Returns a boolean value: true if the first value is equal to all the
subsequent values (using C<eq>), false otherwise.

=cut

func all_eq (Str $first!, Str @rest!) {
    return all { $_ eq $first } @rest;
}

=head4 any

L<< C<any> from List::Util|List::Util/any >>

=head4 first

L<< C<first> from List::Util|List::Util/first >>.

=head4 firstidx

L<< C<firstidx> from List::MoreUtils|List::MoreUtils/firstidx >>.

=head4 folded_in

Returns true if first argument, when case-folded, is equal to the any
of the subsequent arguments, when those are case-folded. If the second
argument is an arrayref, compares the elements of that array.

See L<fc in perlfunc|perlfunc/fc> for more information about case
folding.

=cut

func folded_in (Str $element, Str @set) {
    my $folded = fc($element);
    return any { $folded eq fc($_) } @set;
}

=head4 in

Returns true if the first argument is equal to (using the C<eq>
operator) any of the subsequent arguments, or if the second argument is
a plain arrayref,  any of the elements of that array.

=cut

func in (Str $element, Str @set) {
    return any { $element eq $_ } @set;
}

=head4 none

L<< C<none> from List::Util|List::Util/none >>.

=head3 Sorting by Line

=head4 Description

The following functions sort lists of transit line designations in the
appropriate order.  This is a type of "natural" sort.  It works by
generating a key associated with each line, which when sorted gives the
proper "natural" sort.  See L<Implementation Details|/Implementation
Details> below.

The usual way of designating transit lines is to use a primary line
number followed by a secondary letter: for example, "42A" is the "A"
variant of line "42."  Alternatively, lines are often designated with a
main letter or pair of letters, followed by a secondary number: line
"A10" or "JX1".

When sorting lines that are designated in this fashion, they should be
sorted first by their main line number or letter(s), and then
secondarily by any secondary part. Because transit line designations
are a mixture of letters and numbers, a naive sort (purely alphabetical
or numerical) will yield inappropriate results.

This module can sort lines of arbitrary length and complexity, with
very long line names (AAAAAAAA...) and/or very high numbers of subline
designations (A1B2C3D4...).

Line designations beginning with numbers are sorted before lines
beginning with letters. The functions are is case-insensitive.

=head4 Implementation Details

The key for sorting by line is generated by taking all the alphabetical
parts and the numeric parts, changing the numeric portion so that it
sorts properly (by putting the number of digits in the number ahead of
the number), and then reassembling them, joined by NUL characters (\0).

Any characters that are not alphabetical or numerical (not A-Z or 0-9)
are dropped when creating the sort key.  The sortbyline() routine will
fall back on a standard (case-sensitive) string sort if two lines have
identical keys but are not themselves identical. The other routines
simply ignore these characters.

If there are international transit lines where letters like Å or Þ
are used, these routines will not handle them.

=head4 Acknowledgements

The line key generation code in this module is based on the CPAN module
L<<Sort::Key::Natural|Sort::Key::Natural>>, by Salvador Fandiño
García.

=cut

=head4 byline (I<line1>, I<line2>)

The byline() subroutine is typically called as the BLOCK part of a
L<sort|perlfunc/sort> function call:

  @lines = sort byline @lines;

As required by sort, byline() takes two arguments, which are then
compared.  It returns -1, 0, or 1, depending on whether the first line
should sort before, the same as, or after the second line.

It is mainly useful as part of a longer sort block:

 @sorted_lines =
    sort {
        $mode_of{$a} cmp $mode_of{$b}
        or byline($a, $b)
    } (@lines);

=cut

sub byline ($$) {    ## no critic ( Prototypes )
    my ( $aa, $bb ) = linekeys(@_);
    return $aa cmp $bb;
}

=head4 linekeys ( I<line1>, I<line2> [ , ...] )

This function returns keys that can be used to sort the lines that were
given, using "cmp" or another stringwise operator.  In this way you can
use the values for sorting in another program, or what have you.

=cut

func linekeys (Str @lines) {

    my @keys;
    foreach my $line (@lines) {

        # this is derived from Sort::Key::Natural

        my @parts = $line =~ /\d+|[[:alpha:]]+/gx;

        # @parts is $line, divided into digit parts or alphanumeric parts
        # e.g.,
        #   $line      @parts
        #   A          ( A )
        #   72         ( 72 )
        #   72M        ( 72 , M )
        #   MA1        ( MA , 1 )
        #   A11A        ( A  , 11 , A )

        for (@parts) {

            if (m/ \A 0+ \z/sx) {    # special case: if it's zero
                $_ = '10';
            }
            elsif (m/\A\d/sx) {      # otherwise, for digit parts,

                s/ \A 0+ //sx;       # remove leading zeroes

                my $len       = length($_);
                my $nines     = int( $len / 9 );    ## no critic (MagicNumbers)
                my $remainder = $len % 9;           ## no critic (MagicNumbers)

                $_ = ( '9' x $nines ) . $remainder . $_;

            # That adds a string representing the length of the number
            # to the front of the part.
            # So, it turns "1" into "11", "57" into "257", and so forth.
            # For numbers 9 or more digits long, it adds a 9 in front of the
            # length for each 9 digits: a 10-digit number will have "90"
            # added, an 11-digit number will have "91" added, an 18-digit number
            # will have "990", etc.

                # This ends up sorting, using the 'cmp' operator,
                # the same as a numeric comparison for the numeric parts,
                # while continuing to have a string comparison for the
                # non-numeric parts.

            }
            else {
                # alphabetic parts
                $_ = uc($_);
            }

        }

        push @keys, join( "\0", @parts );

    }

    return 1 == @keys ? $keys[0] : @keys;

}

=head4 sortbyline

Returns a list of lines, sorted properly by line. (If lines are not
identical but have identical sort keys -- for example, if they differ
by case, or one line has extra characters in it -- the sort routine
will fall back on a standard perl "cmp" sort.)

 @lines        = qw(N N1 NA NA1 1 1R 10 2 20 200 20A );
 @sorted_lines = sortbyline (@lines);
 # @sorted_lines is 1 1R 2 10 20 20A 200 N N1 NA NA1

=cut

func sortbyline (Str @lines) {
    my @vals = sort { byline( $a, $b ) or $a cmp $b } @_;
    return @vals;
}

=head3 Other List Functions

=head4 mesh

L<< C<mesh> from List::MoreUtils|List::MoreUtils/mesh >>.

=head4 natatime

L<< C<natatime> from List::MoreUtils|List::MoreUtils/natatime >>.

=head4 uniq

L<< C<uniq> from List::Util|List::Util/uniq >>.

=head2 FILES AND FOLDERS

=head3 Object Creation Functions

=head4 file

A function that returns a new Actium::Storage::File object. The same as
C<< Actium::Storage::File->new(...) >>. See
L<Actium::Storage::File|Actium::Storage::File> for more information.

=cut

sub file {
    require Actium::Storage::File;
    return Actium::Storage::File->new(@_);
}

=head4 folder

A function that returns a new Actium::Storage::Folder object. The same
as C<< Actium::Storage::Folder->new(...) >>. See
L<Actium::Storage::Folder|Actium::Storage::Folder> for more
information.

=cut

sub folder {
    require Actium::Storage::Folder;
    return Actium::Storage::Folder->new(@_);
}

=head2 STRINGS

=head3 Unicode Column Functions

These utilities are used when displaying text in a monospaced typeface,
to ensure that text with combining characters and wide characters are
shown taking up the proper width.

=head4 u_columns

This returns the number of columns in its first argument, as determined
by the L<Unicode::GCString|Unicode::GCString> module.

=cut

func u_columns (Str $str) {
    require Unicode::GCString;    ### DEP ###
    return Unicode::GCString->new("$str")->columns;
    # the quotes are necessary because GCString doesn't work properly
    # with variables Perl thinks are numbers. It doesn't automatically
    # stringify them.
}

=head4 u_pad

Pads a string with spaces to a number of columns. The are two named
arguments: "text", the string to pad, and "width", the number of
columns that should be the result.

 $y = u_pad(text => "x", width => 2);
 # returns  "x "
 $z = u_pad(text => "柱", width => 4);
 # returns ("柱  ");

Uses u_columns internally to determine the width of the text.

=cut

func u_pad (
    Str :$text, Int :$width where { $_ > 0 } ) {    ## no critic (Capitalization)
    my $textwidth = u_columns($text);
    return $text if $textwidth >= $width;
    my $spaces = ( q[ ] x ( $width - $textwidth ) );
    return ( $text . $spaces );
}

=head4 u_wrap

 my $wrapped = u_wrap ("message of many words",
     min_columns => 5,  max_columns => 64 );

Takes a string and word-wraps it to a number of columns, producing  a
series of shorter lines, using the
L<Unicode::Linebreak|Unicode::LineBreak> module. If the string has
embedded newlines, these are taken as separating paragraphs. Any
trailing newlines are removed.

The first argument should be the message to be word-wrapped.

There are four optional named parameters:

=over

=item min_columns

The minimum number of columns -- ColMin from Unicode::LineBreak. If not
present, 0 will be used.

=item max_columns

The maximum number of columns -- ColMax from Unicode::LineBreak. If not
present, 79 will be used.

=item indent

This is an integer, representing the number of spaces that the first
line should be indented.  If positive, the first line will be shortened
by that many columns. If negative, the first line will be lengthened by
that many columns. The default is 0, meaning no indenting will be done.

=item addspace

A boolean value, indicating whether spaces should be added before
indented lines. The number of spaces is that specified by the "indent"
value. (This value is ignored if "indent" zero or not supplied.)  If
addspace is true and indent is positive, then spaces will be added
before the first line. If true and indent is negative, then spaces will
be added before all the lines except the first line.

=back

=cut

const my $DEFAULT_LINE_LENGTH  => 79;
const my $DEFAULT_MINIMUM_LINE => 0;

func u_wrap ( Str $msg!,
             Int :min_columns($min) //= $DEFAULT_MINIMUM_LINE,
             Int :max_columns($max) //= $DEFAULT_LINE_LENGTH,
             Int :$indent //= 0 ,
	 Bool :$addspace //= 1,
	 ) {

    return $msg if $max < $min;
    my $indented_max = $max - $indent;
    my $indentspace  = $SPACE x abs($indent);

    require Unicode::LineBreak;    ### DEP ###

    state $breaker = Unicode::LineBreak::->new(
        Format  => 'TRIM',
        Urgent  => 'FORCE',
        Newline => $EMPTY,
    );
    $breaker->config( ColMax => $max, ColMin => $min ) unless $indent;

    # First split on newlines
    my @lines;
    foreach my $line ( split( /\n/, $msg ) ) {

        my $linewidth = u_columns($line);
        if ( $linewidth <= $indented_max ) {
            push @lines, $line;
        }
        else {
            if ($indent) {
                # indent first line, save rest of lines in $rest

                $breaker->config( ColMax => $indented_max, ColMin => $min );
                my @initially_broken_lines = $breaker->break($msg);
                my $firstline              = shift @initially_broken_lines;
                $firstline = $indentspace . $firstline
                  if $addspace and $indent > 0;
                push @lines, $firstline;
                my $rest = join( $SPACE, @initially_broken_lines );

                # break $rest
                $breaker->config( ColMax => $max );
                my @rest_of_the_lines = $breaker->break($rest);

                if ( $addspace and $indent < 0 ) {
                    $_ = $indentspace . $_ foreach @rest_of_the_lines;
                }
                push @lines, @rest_of_the_lines;
            }
            else {
                push @lines, $breaker->break($line);
            }

        }

    }
    foreach (@lines) {
        $_ = "$_";    # stringify -- eliminate overloaded objects
    }

    return wantarray ? @lines : joinlf(@lines);

}

=head4 u_trim_to_columns

Trims an input string to a particular number of columns.  Takes two
named arguments: 'string' (for the string) and 'columns' (for the
number of columns).

 $x = u_trim_to_columns(string => "Barney", columns => 4);
 # returns "Barn"

=cut

func u_trim_to_columns ( Str :$string!, Int :$columns! ) {

    require Unicode::GCString;    ### DEP ###

    my $gc = Unicode::GCString::->new("$string");
    # stringification of numbers bug means have to do so explicitly

    while ( $gc->columns > $columns ) {
        $gc->substr( -1, 1, q[] );
    }

    return $gc->as_string;
    #return $gc->as_string if $gc->columns == $columns;

    #return u_pad( text => $gc->as_string, width => $columns );
    # in case we trimmed off a double-wide character,
    # pad it to the right number of columns

}

=head3 Other String Functions

=head4 define

For each value passed to it, returns either that value, if defined, or
the empty string, if not.

In scalar context, returns the final value.

=cut

sub define {
    return List::MoreUtils::apply { $_ //= q[] } @_;
}

=head4 encode_entities

L<< C<encode_entities> from
HTML::Entities|HTML::Entities/encode_entities >>.

=head4 feq

Returns a boolean value:  true if, when case-folded (using C<fc>),  the
first argument is equal to its second; otherwise false.

=cut

func feq (Str $x, Str $y) {
    return fc($x) eq fc($y);
}

=head4 fne

Returns a boolean value:  true if, when case-folded (using C<fc>),  the
first argument is not equal to its second; otherwise false.

=cut

func fne (Str $x, Str $y) {
    return fc($x) ne fc($y);
}

=head4 trim

L<< C<trim> from Text::Trim|Text::Trim/trim >>.

=head2 NUMBERS

=head4 ceil

L<< C<ceil> from POSIX|POSIX/ceil >>.

=head4 display_percent (I<fraction>)

This is used to display a percentage. If two arguments are passed, the
first is taken as the numerator and the second is taken as the
denominator: the division is performed and then returned as a whole
percentage.  If only one argument is passed, the first number is
treated as a fraction itself and multiplied by 100 to get the
percentage.

(This violates the usual calling conventions, but it's unlikely that
the numerator and denominator of fractions will be confused.)

The string returned represents a whole percentage: e.g., if the value
is 0.252, will return "25%".

=cut

func display_percent (Num $val!, Num $total = 1) {
    ## no critic (ProhibitMagicNumbers)
    return sprintf( '%.0f%%', $val / $total * 100 );
    ## use critic
}

=head4 floor

L<< C<floor> from POSIX|POSIX/floor >>.

=head4 looks_like_number

L<< C<looks_like_number> from
Scalar::Util|Scalar::Util/looks_like_number >>.

=head2 REFERENCES

=head4 arrayify

L<< C<arrayify> from List::MoreUtils|List::MoreUtils/arrayify >>.

=head4 blessed

L<< C<blessed> from Scalar::Util|Scalar::Util/blessed >>.

=head4 hashref

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

=head4 is_arrayref

L<C<is_arrayref> from Ref::Util|Ref::Util/is_arrayref>.

=head4 is_blessed_ref

L<C<is_blessed_ref> from Ref::Util|Ref::Util/is_blessed_ref>.

=head4 is_coderef

L<C<is_coderef> from Ref::Util|Ref::Util/is_coderef>.

=head4 is_hashref

L<C<is_hashref> from Ref::Util|Ref::Util/is_hashref>.

=head4 is_ioref

L<C<is_ioref> from Ref::Util|Ref::Util/is_ioref>.

=head4 is_plain_arrayref

L<C<is_plain_arrayref> from Ref::Util|Ref::Util/is_plain_arrayref>.

=head4 is_plain_hashref

L<C<is_plain_hashref> from Ref::Util|Ref::Util/is_plain_hashref>.

=head4 is_ref

L<C<is_ref> from Ref::Util|Ref::Util/is_ref>.

=head4 refaddr

L<C<refaddr> from Scalar::Util|Scalar::Util/refaddr>.

=head4 reftype

L<C<reftype> from Scalar::Util|Scalar::Util/reftype>.

=head2 OTHER FUNCTIONS

=head4 dumpstr

This returns a string --  a dump from the Data::Printer module of the
passed data structure, suitable for displaying and debugging.

=cut

sub dumpstr (\[@$%&];%) {    ## no critic (Prototypes)
                              # prototype copied from Data::Printer::np
    require Data::Printer;    ### DEP ###
    return Data::Printer::np(
        @_,
        hash_separator => ' => ',
        class => { expand => 'all', parents => 0, show_methods => 'none', },
    );
}

=head4 immut

The B<immut> routine is designed to be used in place of the rather
unwieldy

    __PACKAGE__->meta->make_immutable

The C<immut> routine simply performs this on the calling package,
making the Moose class immutable. Any arguments are passed on to
make_immutable.

=cut

sub immut {
    my $package = caller;
    $package->meta->make_immutable(@_);
    return;
}

1;

__END__

=head1 DIAGNOSTICS

=over

=item *

Unknown module type $type

A module type other than 'class' or 'role' was passed in the 'use
Actium'  statement.

=item *

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

List::MoreUtils, version 0.426 or greater

=item *

Module::Runtime

=item *

Ref::Util

=item *

Statistics::Lite

=item *

Text::Trim

=back

When used for a Moose class or role, it requires the following
distributions:

=over

=item *

Actium::MooseX::BuiltIsRo

=item *

Actium::MooseX::PredicateClearerShortcuts

=item *

Actium::MooseX::BuilderShortuct

=item *

Actium::MooseX::Rwp

=item *

Moose

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

Actium::Storage::File

=item *

Actium::Storage::Folder

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

