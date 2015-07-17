# Actium/Term.pm
# Terminal output routines for Actium

# legacy status 3

use strict; ### DEP ###
use warnings; ### DEP ###

package Actium::Term 0.010;

use 5.010;    # turns on features

use Actium::Constants;

use Term::Emit ( qw<:all !emit_over !emit_prog>, { -fh => *STDERR } );
# Term::Emit ### DEP ###

use Actium::Options qw(option set_option add_option);
use Carp; ### DEP ###
use Term::ReadKey; ### DEP ###
use Text::Wrap; ### DEP ###
use List::Util('max'); ### DEP ###
use POSIX qw(ceil floor); ### DEP ###
use Scalar::Util qw(reftype); ### DEP ###

use English qw<-no_match_vars>; ### DEP ###

# TODO - regularize when STDERR is used vs. STDOUT.
# Fix documentation, which is incorrect on this

use Exporter;
our @ISA    = qw<Exporter>;
our @EXPORT = qw<emit_over emit_prog>;
our @EXPORT_OK
  = qw(term_readline get_width print_in_columns columnize);
our %EXPORT_TAGS = ( all => [ @EXPORT_OK, @EXPORT ] );

$SIG{'WINCH'} = \&set_width;
$SIG{'INT'}   = \&_terminate;

set_width();

{
    my $previous_default = select(STDOUT);    # save previous default
    $OUTPUT_AUTOFLUSH++;                      # autoflush STDOUT
    select(STDERR);
    $OUTPUT_AUTOFLUSH++;                      # autoflush STDERR, to be sure
    select($previous_default);                # restore previous default
}

sub emit_over {

    return unless option('progress');

    no warnings('once');
    if ($Actium::Eclipse::is_under_eclipse) {
        Term::Emit::emit_prog( join( $SPACE, @_ ) . $SPACE );
    }
    else {
        Term::Emit::emit_over(@_);
    }
}

sub emit_prog {
    return unless option('progress');
    Term::Emit::emit_prog(@_);
}

sub set_term_pos {
    my $position = shift;
    Term::Emit::setopts( '-pos' => $position );
}

sub import {

    my $caller = caller();

    set_width();

    my @term_emit_imports
      = grep { $_ ne 'emit_over' and $_ ne 'emit_prog' } @Term::Emit::EXPORT_OK;

    eval "package $caller; Term::Emit->import(qw<"
      . join( $SPACE, @term_emit_imports ) . '> );';

    # note, this forces all the Term::Emit imports... it would be nice
    # to be able to pick and choose.

    #    Term::Emit::setopts( { -closestat => 'ERROR', -width => $width } );

    Actium::Term->export_to_level( 1, @_ );

}    ## <perltidy> end sub import

add_option( 'quiet!', 'Does not display unnecessary information.',
    \&_option_quiet );

add_option(
    'progress!',
'Displays dynamic progress indications. On by default. Use -noprogress to turn off.',
    1,
);

sub _option_quiet {
    return unless $_[0];
    Term::Emit::setopts( -maxdepth => 0 );
    return;
}

sub be_quiet {
    set_option( 'quiet', 1 );
    _option_quiet (1);
}

sub set_width {
    my $width = get_width();
    Term::Emit::setopts( { -closestat => 'ERROR', -width => $width } );
}

sub _terminate {
    my $signal = shift;
    emit_text("Caught SIG$signal... Aborting program.");
    emit_done('ABORT');
    exit 1;
}

sub get_width {
    my $width = (
        eval {
            local ( $SIG{__DIE__} ) = 'IGNORE';
            ( Term::ReadKey::GetTerminalSize() )[0];

            # Ignore errors from GetTerminalSize
        }

          #or $Actium::Eclipse::is_under_eclipse ? 132 : 80
          or 80
    );
    return $width;
}

### General stuff

sub term_readline {

    require IO::Prompter; ### DEP ###

    my $prompt = shift;
    my $hide   = shift;

    my $val;
    
    my $emit = Term::Emit::base();
    # have to break Term::Emit encapsulation to get position...

    print "\n" if $emit->{pos}; # new line unless position is 0
    
    if ($hide) {
        $val = IO::Prompter::prompt( $prompt, -echo => '*' , '-hNONE', '-stdio');
    }
    else {
        $val = IO::Prompter::prompt($prompt, '-stdio' );
    }
    
    Term::Emit::setopts (-pos => 0);

    return "$val"; 
    # stringify what would otherwise be a weird Contextual::Return value,
    # thank you Mr. Conway

} ## tidy end: sub term_readline

# TODO: Document columnize and print_in_columns
sub columnize {

    my $screenwidth = get_width();
    my $padding     = 1;

    if ( reftype( $_[0] ) eq 'HASH' ) {
        my %args = %{ +shift };
        $padding = $args{PADDING} || $padding;
    }

    my $results = '';

    my @list = @_;

    my $colwidth = $padding + max( map {length} @list );

    @list = map { sprintf( "%*s", -($colwidth), $_ ) } @list;

    my $cols = floor( $screenwidth / ($colwidth) ) || 1;
    my $rows = ceil( @list / $cols );

    push @list, ( " " x $colwidth ) x ( $cols * $rows - @list );

    for my $y ( 0 .. $rows - 1 ) {
        for my $x ( 0 .. $cols - 1 ) {
            $results .= $list[ $x * $rows + $y ];
        }
        $results .= "\n";
    }

    return $results;

} ## tidy end: sub columnize

sub print_in_columns {
    print columnize(@_);
}

1;
__END__

=head1 NAME

Actium::Term - Terminal output routines for the Actium system

=head1 VERSION

This documentation refers to Actium::Term version 0.001

=head1 SYNOPSIS

 use Actium::Term;
 use Term::Emit qw(:all);
 emit 'Doing something cool...';
 # doing it
 emit_ok;
   
=head1 DESCRIPTION

Actium::Term contains routines for terminal output. 

At the moment its main funciton is to support a command-line option to suppress 
unnecessary (but desirable) output. This option is '-quiet'.
Actium::Term has several routines that display their output only when 
-quiet is not set, and at the time the options are set, tells
L<Term::Emit> not to display any output.

In addition, during options processing, Actium::Term determines the width of the
current terminal window (by using Term::Readkey) and tells Term::Emit to use
this width.

Actium::Term acts on the currently selected file handle. See
L<perlfunc/select>. (NO IT DOESN'T -- IT DEPENDS. MUST FIX THIS)

=head1 OPTIONS

=over

=item -quiet

-quiet suppresses infomation that would be displayed through
Actium::Term or L<Term::Emit>.

During options processing (using Actium::Options), Actium::Term
tells Term::Emit that it should send no information for the currently
selected filehandle (setting the -maxdepth attribute to 0; see L<Term::Emit/-maxdepth>).

=back

=head1 SUBROUTINES

=item B<set_term_pos($position)>

This routine is designed to allow regular output (print, say, etc.) to be mixed with
Actium::Term output. It tells Term::Emit to set the current cursor position to $position.
See L<Term::Emit/Mixing Term::Emit with print�ed Output>.

=back

=head1 DIAGNOSTICS

=over

=item "Can't say: $!"; 

=item "Can't print: $!"; 

The say or print statements returned an error.

=back

=head1 DEPENDENCIES

=over

=item *
perl 5.10

=item *
Actium::Options

=item *
Term::Emit

=item *

Term::Readkey

=back

=head1 BUGS AND LIMITATIONS

Actium::Term is inconsistent in its use of the currently selected filehandle
vs. STDERR. 

Actium::Term uses Term::Readkey to set the width of the display.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
