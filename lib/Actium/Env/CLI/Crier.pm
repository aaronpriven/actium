package Actium::Env::CLI::Crier 0.015;
# vimcolor: #000026

# Print with indentation, status, and closure
# Based on Term::Emit by Steve Roscio

use Actium ('class');
use Actium::Env::CLI::Crier::Cry;
use Actium::Types(qw/CrierImportance CrierStatus/);
use Scalar::Util;
use Type::Utils('class_type');
use Types::Standard (
    qw/Undef Str Bool Maybe Int ArrayRef CodeRef Tuple FileHandle ScalarRef/);

use MooseX::SingleArg;
no warnings 'experimental::refaliasing';
# MooseX::SingleArg turns this on, irritatingly

##############
## Constants

const my $MAX_TAG_WIDTH => 5;
const my $RIGHT_INDENT  => $MAX_TAG_WIDTH + 3;
# includes brackets and a leading space.
const my $MIN_SPAN_FACTOR => ( 2 / 3 );
# sets ColMin in Unicode::LineBreak

const my $CRY_CLASS => 'Actium::Env::CLI::Crier::Cry';

###############
## Filehandle

single_arg 'fh';

has fh => (
    is  => 'ro',
    isa => FileHandle->plus_coercions(
        ScalarRef,
        sub {
            open my $fh, '>', $_ or die "Opening crier to memory: $!";
            return $fh;
        },
    ),
    coerce  => 1,
    default => sub { *STDERR{IO} },
);

######################
## WIDTH AND POSITION

# position is the current cursor position.

has 'position' => (
    is      => 'ro',
    writer  => '_set_raw_position',
    isa     => Int,
    default => 0,
);

# prog_cols is the number of columns emitted by the prog() or over() calls
# which is to say, the number of columns to backspace in the *next* over()
# call.

has '_prog_cols' => (
    is      => 'rw',
    isa     => Int,
    default => 0,
);

# except from within prog(), when the position is set, it should
# reset the prog_cols so it doesn't try to backspace over anything
# other than prog() output.
method set_position ($position) {
    $self->_set_raw_position($position);
    $self->_set_prog_cols(0);
    my $deepest_open_cry = $self->_deepest_open_cry;
    $deepest_open_cry->_mark_position_changed if $deepest_open_cry;
    return;
}

const my $DEFAULT_COLUMN_WIDTH => 80;

has 'column_width' => (
    is      => 'rw',
    isa     => Int->where( sub { 40 <= $_ } ),
    default => $DEFAULT_COLUMN_WIDTH,
);

#############################
### DISPLAY FEATURES

has 'ellipsis' => (
    is      => 'rw',
    isa     => Str,
    default => '...',
);

has 'timestamp' => (
    is      => 'rw',
    isa     => Bool | CodeRef,
    default => undef,
);

has 'trailer' => (
    is      => 'rw',
    isa     => Str->where( sub { Actium::u_columns($_) == 1 } ),
    default => '.',
);

has 'colorize' => (
    isa     => Bool,
    is      => 'ro',
    default => 0,
    traits  => ['Bool'],
    handles => {
        use_color => 'set',
        no_color  => 'unset',
    },
);

has 'shows_progress' => (
    isa     => Bool,
    is      => 'ro',
    default => 1,
    traits  => ['Bool'],
    handles => {
        show_progress => 'set',
        hide_progress => 'unset',
    },
);

has 'backspace' => (
    isa     => Bool,
    is      => 'ro',
    default => 1,
    traits  => ['Bool'],
    handles => {
        use_backspace => 'set',
        no_backspace  => 'unset',
    },
);

#########################
## BULLETS, INDENTATION

has 'bullets_r' => (
    is       => 'bare',
    isa      => ( ArrayRef [Str] )->plus_coercions( Str, sub { [$_] } ),
    init_arg => 'bullets',
    reader   => '_bullets_r',
    writer   => '_set_bullets_r',
    coerce   => 1,
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        bullets       => 'elements',
        _bullet_count => 'count',
        bullet        => 'get',
    },
    trigger => \&_alter_bullet_width,
);

sub set_bullets {
    my $self    = shift;
    my @bullets = Actium::arrayify(@_);
    $self->_set_bullets_r( \@bullets );
}

method _bullet_for_level (Int $level is copy) {
    my $count = $self->_bullet_count;
    return $EMPTY unless $count;

    $level = $count if $level > $count;
    return $self->bullet( $level - 1 );
    # level is 1-based, bullet is zero-based
}

has '_bullet_width' => (
    is       => 'rw',
    isa      => Int,
    init_arg => undef,
    builder  => '_build_bullet_width',
    lazy     => 1,
);

method _build_bullet_width {
    my $bullets_r = $self->_bullets_r;
    return 0 if @{$bullets_r} == 0;
    my $width = Actium::max( map { Actium::u_columns($_) } @{$bullets_r} );
    return $width;
}

method _alter_bullet_width ($bullets_r, ...) {

    return unless @$bullets_r;

    my $bullet_width = $self->_bullet_width;
    my $newbullet_width
      = Actium::max( map { Actium::u_columns($_) } @{$bullets_r} );

    return if $newbullet_width <= $bullet_width;

    $self->_set_bullet_width($newbullet_width);

    return;

}

const my $DEFAULT_STEP => 2;

has 'step' => (
    is      => 'rw',
    isa     => Int,
    default => $DEFAULT_STEP,
);

###############################
## STATUS / IMPORTANCE / LEVEL
#
# There are three axes.
# Importance - how important the item is; how much it's a niggling detail
# Status - how good or bad the result is
# Level - how deep it is, nested

{
    # these are here as methods instead of being just hashes in the Cry object
    # mainly so that someday they can be configured -- should that be desirable
    # in the future

    my %COLOR_OF_STATUS = (
        7  => 'bold blue on_bright_white',
        6  => 'bold bright_white on_blue',
        5  => 'bold black on_bright_green',
        4  => 'bold black on_green',
        3  => 'bold',
        2  => 'bold bright_cyan on_black',
        1  => 'bold bright_green on_black',
        -1 => 'bold bright_red on_black',
        -2 => 'bold bright_yellow on_black',
        -3 => 'bold black on_bright_yellow',
        -4 => 'bold red on_white',
        -5 => 'bold bright_white on_red',
        -6 => 'bold blink black on_bright_yellow',
        -7 => 'bold blink bright_white on_red',
    );

    const my %TAG_OF_STATUS => (
        7  => 'BLISS',
        6  => 'CALM',
        5  => 'PASS',
        4  => 'VALID',
        3  => 'DONE',
        2  => 'INFO',
        1  => 'YES',
        0  => 'OK',
        -1 => 'NO',
        -2 => 'WARN',
        -3 => 'ABORT',
        -4 => 'ERROR',
        -5 => 'FAIL',
        -6 => 'ALERT',
        -7 => 'PANIC',
    );

    const my %STATUS_OF_TAG => ( reverse %TAG_OF_STATUS );

    method _color_of_status ( CrierStatus $status ) {
        return $COLOR_OF_STATUS{$status};
    }

    method _tag_of_status ( CrierStatus $status ) {
        return $TAG_OF_STATUS{$status};
    }

    method _status_of_tag ( Str $tag ) {
        return exists $STATUS_OF_TAG{$tag} ? $STATUS_OF_TAG{$tag} : 0;
    }

}

has always_show_status_above => (
    is => 'rw',

    # if this works (!), it should coerce an integer to a pair of integers, and
    # coerce a pair of integers in the wrong order to one that is in the right
    # order.
    #
    isa => (
        Maybe [
            (   Tuple [
                    Int->where( sub { -7 <= $_ and $_ <= 0 } ),
                    Int->where( sub { 0 <= $_  and $_ <= 7 } ),
                ]
            )
        ]
      )->plus_coercions(
        Int,
        sub {
            [ -( abs($_) ), abs($_) ];
        },
        Tuple [
            Int->where( sub { 0 <= $_  and $_ <= 7 } ),
            Int->where( sub { -7 <= $_ and $_ <= 0 } ),
        ],
        sub { [ $_->[1], $_->[0] ] },
      ),
    coerce  => 1,
    default => undef,
);

has 'filter_above_level' => (
    is      => 'rw',
    isa     => Maybe [ Int->where( sub { $_ >= 0 } ) ],
    default => undef,
);

has 'filter_below_importance' => (
    is      => 'rw',
    isa     => CrierImportance,
    default => 0,
);

# the idea is that the filters are applied first, and then if the status
# is really high, then the filters are overridden

const my $FALLBACK_STATUS => -3;
# the default status is -3, or "abort", indicating that the
# cry object was demolished unexpectedly
const my $FALLBACK_IMPORTANCE => 3;
# default importance is middling-importance 3

has 'default_status' => (
    is      => 'rw',
    isa     => Int->plus_coercions( Undef, $FALLBACK_STATUS ),
    default => $FALLBACK_STATUS,
    coerce  => 1,
);

has default_importance => (
    is      => 'rw',
    isa     => CrierImportance->plus_coercions( Undef, $FALLBACK_IMPORTANCE ),
    default => $FALLBACK_IMPORTANCE,
);

###########################
### CRIES AND LEVELS

has '_cries_r' => (
    is      => 'ro',
    isa     => ArrayRef [ class_type($CRY_CLASS) ],
    traits  => ['Array'],
    handles => {
        _pop_cry   => 'pop',
        _cry_count => 'count',
        _first_cry => [ get => 0 ],
        last_cry   => [ get => -1 ],
    },
    default => sub { [] },
);

method _deepest_open_cry {
    for my $cry ( reverse $self->_cries_r->@* ) {
        next unless $cry;
        return $cry if $cry->_is_opened;
    }
    return undef;
}

method _push_cry {
    my $cry     = shift;
    my $cries_r = $self->_cries_r;
    push @{$cries_r}, $cry;
    Scalar::Util::weaken( ${$cries_r}[-1] );
}

method cry0  { $self->cry( @_, { importance => 0 } ) }
method cry1 { $self->cry( @_, { importance => 1 } ) }
method cry2 { $self->cry( @_, { importance => 2 } ) }
method cry3 { $self->cry( @_, { importance => 3 } ) }
method cry4 { $self->cry( @_, { importance => 4 } ) }
method cry5 { $self->cry( @_, { importance => 5 } ) }
method cry6 { $self->cry( @_, { importance => 6 } ) }
method cry7 { $self->cry( @_, { importance => 7 } ) }

method cry {
    ( \my %opts, \my @args ) = $self->_opts_and_args(@_);

    if ( @args == 1 and Actium::is_arrayref( $args[0] ) ) {
        my @pair = @{ +shift @args };
        $opts{opentext}  = $pair[0];
        $opts{closetext} = $pair[1];
    }
    else {
        my $separator = $OUTPUT_FIELD_SEPARATOR // $EMPTY;
        $opts{opentext} = join( $separator, @args );
    }

    # if no opentext, use the caller's subroutine name
    unless ( $opts{opentext} ) {
        my $msg;
        ( undef, undef, undef, $msg ) = caller(1);
        $msg =~ s{\Amain::}{}sxm;
        $opts{opentext} = $msg;
    }

    if ( defined $opts{bullet} ) {
        $self->_alter_bullet_width( [ $opts{bullet} ] );
    }

    my $cry = $CRY_CLASS->new(
        %opts,
        _crier => $self,
        _level => ( $self->_cry_count + 1 )
    );

    return undef unless $cry->_built_without_error;

    $self->_push_cry($cry);

    return $cry if defined wantarray;

    $cry->warn( { reason => 'Cry error (cry object not saved)' } );
    # void context - close immediately
    return;
}

sub _close_up_to {
    my $self          = shift;
    my $cry           = shift;
    my @original_args = @_;

    my $this_cry = $self->_pop_cry;

    while ( $this_cry and $this_cry != $cry ) {

        if ( not $this_cry->_is_closed ) {
            return undef unless $this_cry->_close();
            # using status and options set in cry
        }
        $this_cry = $self->_pop_cry;
    }

    return $cry->_close(@original_args);

}

sub _open_below {
    my $self = shift;
    my $cry  = shift;

    foreach my $this_cry ( $self->_cries_r->@* ) {
        next unless $this_cry;
        last if $this_cry == $cry;
        #$this_cry->_open unless $this_cry->_is_opened;
    }
    return;
}

method DEMOLISH {
    if ( defined $self->_first_cry ) {
        $self->_close_up_to( $self->_first_cry );
    }
    return;
}

#######################
## prog, over, and wail

method prog {
    $self->_do_prog( 'prog', @_ );
}

method over {
    $self->_do_prog( 'over', @_ );
}

method _do_prog ($type, @texts) {

    return 1 unless $self->shows_progress;

    my $cry;
    my $left_indent_cols = 0;
    if ( $self->_cry_count ) {
        $cry              = $self->last_cry;
        $left_indent_cols = $cry->_left_indent_cols;
        return 1 if $cry->_silent or $cry->muted;
    }

    # if no backspace (in braindead consoles like Eclipse's),
    # then treats everything as a forward-progress.

    my $prog_cols = $self->_prog_cols;

    if ( $type eq 'over' and $self->backspace and $prog_cols ) {

        my $backspaces = "\b" x $prog_cols;
        my $spaces     = $SPACE x $prog_cols;

        return undef unless $self->_print( $backspaces, $spaces, $backspaces );
        $self->set_position( $self->position - $prog_cols );
        $prog_cols = 0;

    }

    my $msg = join( $OUTPUT_FIELD_SEPARATOR // $EMPTY, Actium::define(@texts) );

    # Start a new line?
    my $columns_available
      = $self->column_width - $self->position - $RIGHT_INDENT;
    my $msgcolumns = Actium::u_columns($msg);

    my $position = $self->position;

    if ( $msgcolumns > $columns_available ) {

        my $spaces = $SPACE x $left_indent_cols;
        return undef unless $self->_print( "\n", $spaces );

        $position  = $left_indent_cols;
        $prog_cols = 0;
        $self->_set_raw_position($position);
        $self->_set_prog_cols($prog_cols);
        $cry->_mark_position_changed if $cry;
    }

    return undef unless $self->_print($msg);

    $self->_set_raw_position( $position + $msgcolumns );
    $self->_set_prog_cols( $prog_cols + $msgcolumns );

    return 1;

}

method wail {

    # note that the indent of wailing is set to be one more on each side
    # than the cry it belongs to

    my $text = join( $OUTPUT_FIELD_SEPARATOR // $EMPTY, @_ );

    my $left_indent_cols  = 0;
    my $right_indent_cols = 0;
    if ( $self->_cry_count ) {
        my $cry = $self->last_cry;
        return 1 if $cry->_silent or $cry->muted;
        $left_indent_cols  = $cry->_left_indent_cols + 1;
        $right_indent_cols = $RIGHT_INDENT + 1;
    }

    return $self->_display_wail(
        text              => $text,
        left_indent_cols  => $left_indent_cols,
        right_indent_cols => $right_indent_cols
    );

}

# note that the indent of wailing is set to be one more on each side
# than the cry it belongs to

method _display_wail (:$text, :$left_indent_cols, :$right_indent_cols) {
    # _display_wail is also used to display the "reason" from the cry close

    return undef unless $self->_ensure_start_of_line;

    my $span_max
      = $self->column_width - ( $left_indent_cols + $right_indent_cols );
    my $span_min = int( $span_max * $MIN_SPAN_FACTOR );

    my @lines = Actium::u_wrap(
        $text,
        min_columns => $span_min,
        max_columns => $span_max,
    );

    my $indentspace = $SPACE x $left_indent_cols;
    foreach my $line (@lines) {
        return undef unless $self->_print( $indentspace, $line, "\n" );
    }
    $self->set_position(0);

    return 1;

}

#########################
## arg handling utility routines

method _opts_and_args {
    my ( %opts, @args );
    foreach (@_) {
        if ( Actium::is_hashref($_) ) {
            %opts = ( %opts, %{$_} );
        }
        else {
            push @args, $_;
        }
    }
    return \%opts, \@args;
}

#########################
## print utility routines

method _print {
    local $OUTPUT_FIELD_SEPARATOR  = undef;
    local $OUTPUT_RECORD_SEPARATOR = undef;
    return print { $self->fh } @_;
}

method _ensure_start_of_line {
    return 1 unless $self->position;
    $self->set_position(0);
    return $self->_print("\n");
}

1;

__END__

=encoding utf8

=head1 NAME

Actium::Env::CLI::Crier - Terminal notification with indentation, status, and
closure

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use Actium::Env::CLI::Crier;

 my $crier = Actium::Env::CLI::Crier::->new();

 my $task_cry = $crier->cry("Main Task");
 ...
 my $subtask_cry = $crier->cry("First Subtask");
 ...
 $subtask_cry->ok;
 ...
 my $another_subtask_cry = $crier->cry("Second Subtask");
 ...
 $another_subtask_cry->ok;
 ...
 $task_cry->ok;

This results in this output to STDOUT:

 Main task...
     First Subtask..............................................[OK]
     Second Subtask.............................................[OK]
 Main task......................................................[OK]

=head1 DESCRIPTION

Actium::Env::CLI::Crier is used to to output balanced and nested messages with
a completion status.  These messages indent easily within each other, are
easily parsed, may be bulleted, can be filtered, and even can show status in
color.

For example, you write code like this:

    use Actium::Env::CLI::Crier;
    our $crier = Actium::Env::CLI::Crier::->new()
    my $cry = $crier->cry("Performing the task");
    first_subtask();
    second_subtask();
    $cry->done;

It begins by outputting:

    Performing the task...

Then it does the first subtask and the second subtask. When these are
complete, it adds the rest of the line: a bunch of dots and the [OK].

    Performing the task......................................... [DONE]

Your subroutines first_subtask() and second_subtasks() may also issue a
cry about what they're doing, and indicate success or failure or
whatever, so you can get nice output like this:

    Performing the task...
      Performing a subtask ..................................... [WARN]
      A second subtask...
        Second subtask, phase one............................... [OK]
        Second subtask, phase two............................... [ERROR]
      Wrapup of second subtask.................................. [OK]
    Performing the task......................................... [DONE]

A series of examples will make Actium::Env::CLI::Crier easier to understand.

The name "Crier" refers to town criers, who traditionally made public
announcements in medieval towns. This module makes announcements, so the name
seemed appropriate. (Not coincidentally, "cry" is a short word and thus easy to
type.)

=head2 Basics

Here is a basic example of usage:

    use Actium::Env::CLI::Crier;
    my $crier = Actium::Env::CLI::Crier::->new();
    my $cry = $crier->cry("Performing a task");
    sleep 1; # simulate task performance
    $cry->c(0); # close with status 0

First this outputs:

    Performing a task...

Then after the task process is complete, the line is continued so it
looks like this:

    Performing a task........................................... [OK]

The C<c> method closes the method using the numeric status. It can be easier to
use the method associated with the equivalent status tag, which in this case
would be C<ok>. There are a number of different methods used for closing a
message, all of which are just shortcuts for calling C<c> with an option set.
There are also a number used for opening a message, all of which are equivalent
to <cry> with an option set.

Actium::Env::CLI::Crier works by creating two sets of objects. The I<crier>
represents the destination of the cries, such as the terminal, or an
output file. The I<cry> object represents a single cry, such as a cry
about one particular task or subtask.  Methods on these objects are
used to issue cries and complete them.

The crier object is created by the C<new> class method of
C<Actium::Env::CLI::Crier>. The cry object is created by the C<cry> object
method of the crier object.

Note that the L<Actium|Actium> module has procedural shortcuts for accessing
the crier located in the Actium environment object. See that module for more
information.

=head2 Completion upon destruction

In the above example, we end with a C<ok> call to indicate that the thing we
told about (I<Performing a task>) is complete.  However, in the event of an
error in the program, the C<ok> call may not be made. In that event, an
automatic closure will be made, and the result will be "ABORT".

    Performing a task........................................... [ABORT]

It is possible to change this default using the attribute I<default_status>.

=head2 Completion Status

There's many ways a task can complete.  It can be simply DONE, or it
can complete with an ERROR, or it can be OK, etc.  

Actium::Env::CLI::Crier uses both numeric I<status> and a displayed I<tag> to
indicate the result of a task.

The status is a number betwen -7 and 7. A negative status is intended to
represent bad results, while positive status are intended to represent good
results.   The status is returned as the result of the call that closes the
cry, and is also used for determining the default color. The tag is the text
that is actually displayed. It must be a string; it will be trimmed to be five
columns or fewer.

Each numeric status has a predefined tag:

        7  => BLISS        -7 => PANIC
        6  => CALM         -6 => ALERT
        5  => PASS         -5 => FAIL
        4  => VALID        -4 => ERROR
        3  => DONE         -3 => ABORT
        2  => INFO         -2 => WARN
        1  => YES          -1 => NO
                  0  => OK

But arbitrary tags can be used using the C<tag> option or specifying a string
as the first argument to the C<c> method.

The tags are chosen such that, for the most part, the positive and negative
tags for the same absolute value mean the opposite of each other.  (The utility
of this is, admittedly, rather low for values 6 and 7.)

Each of the predefined tags has a method that closes the cry with the
particular tag: C<bliss>, C<panic>, etc. 

The various methods that close tags return with the status number, unless
there's an error in which case it returns undef (in scalar context) or nothing
(in list context). Note that 0, while Perl considers this a false value, is not
an error.

As a convienence, it's easier to use methods that incorporate the tag, such as
C<ok> or C<fail>. See L<Convenience synonyms for "c"|/Convenience synonyms for
"c"> below for a complete list.

We'll change our simple example to give a FAIL completion:

    use Actium::Env::CLI::Crier;
    my $crier = Actium::Env::CLI::Crier::->new();
    my $cry = $crier->cry("Performing a task");
    sleep 1; # simulate task performance
    $cry->fail;

Here's how it looks:

    Performing a task........................................... [FAIL]

Unless specified explicitly using a status-specific close method or the
I<status> option, the status will be -3 (which corresponds to 'ABORT'). This is
so that, if the cry object isn't closed explitly using a close method, it will
be automatically closed with an appropriate message for uncaught exceptions.

=head3 Status Colors

One feature of C<Actium::Env::CLI::Crier> is that you can enable colorization
of the severity tags.  That means that the severity code inside the square
brackets is output in color, so it's easy to see. The module Term::ANSIColor is
used to do the colorization. It also makes the type bold for most statuses.

Here are the colors that are used:

         7        bold blue on bright white
         6        bold bright white on blue
         5        bold black on bright green
         4        bold black on green
         3        bold (but not in color)
         2        bold bright cyan on black
         1        bold bright green on black
         0        (no colorization)
        -1        bold bright red on black
        -2        bold bright yellow on black
        -3        bold black on bright yellow
        -4        bold red on white
        -5        bold bright white on red
        -6        bold blink black on bright yellow
        -7        bold blink bright white on red

To use colors, pass 'colorize => 1' as an option to the
C<new> method call:

    my $crier = Actium::Env::CLI::Crier::->new({colorize => 1});

Or, invoke the use_color method on the crier, once it's created:

    $crier->use_color;

A cry can also be given a custom color for its tag using the I<tag_color>
option.

=head2 Nested Messages

Nested cries will automatically indent with each other. You do this:

    use Actium::Env::CLI::Crier;
    my $crier = Actium::Env::CLI::Crier::->new();
    my $aaa = $crier->cry("Aaa")
    my $bbb = $crier->cry("Bbb")
    my $ccc = $crier->cry("Ccc")
    $ccc->ok;
    $bbb->ok;
    $aaa->ok;

and you'll get output like this:

    Aaa...
      Bbb...
        Ccc.......................... [OK]
      Bbb............................ [OK]
    Aaa.............................. [OK]

Notice how "Bbb" is indented within the "Aaa" item, and that "Ccc" is
within the "Bbb" item.  Note too how the Bbb and Aaa items were
repeated because their initial lines were interrupted by more-inner
tasks.

You can control the indentation with the I<step> attribute, and you may turn
off or alter the repeated text (Bbb and Aaa) as you wish.  

Also, messages deeper than a certain level can be filtered out (see
L<Filtering, below|/Filtering>.

=head2 Importance

Regardless of how deep a message may be, or what its ultimate status might be,
some messages are just inherently more important than others. Each message can
thus be given an importance value, from 0 to 7.  This can be done using the
I<importance> option to the C<cry> method, or using the specific methods
C<cry0>, C<cry1>, C<cry2>, etc., through C<cry7>.  Unless specified explicitly,
the importace is set to 3.  

The value of this is that messages with lesser importance can be filtered out
(see L<Filtering, below|/Filtering>.

=head2 Closing with Different Text

Suppose you want the opening and closing messages to be different. Such
as I<"Beginning task"> and I<"Ending task">.

To do this, use the I<closetext> attribute or C<set_closetext> method:

    my $cry = $crier->cry(
         "Beginning task" ,
         {closetext => "Ending task"},
      );

Or:

    $cry->set_closetext("Ending task");

Or:

    $cry->ok({closetext => "Ending task"});

Now, instead of the start message being repeated at the end, you get
custom end text.

A convienent shorthand notation for I<closetext> is to instead call
C<cry> with a pair of strings as an array reference, like this:

    my $cry=$crier->cry( ["Start text", "End text"] );

Using the array reference notation is easier, and it will override the
closetext option if you use both.  So don't use both.

=head2 Closing with Different Statuses

So far our examples have been rather boring.  They're not vey
real-world. In a real script, you'll be doing various steps, checking
status as you go, and bailing out with an error status on each failed
check.  It's only when you get to the bottom of all the steps that you
know it's succeeded. Here's where completion upon destruction becomes
more useful:

    #!/usr/bin/env perl

    use warnings;
    use strict;

    use Actium::Env::CLI::Crier;

    my $crier = Actium::Env::CLI::Crier::->new();
    primary_task();

    sub primary_task {

       $main_cry = $crier->cry( "Primary task");
       return
           if !do_a_subtask();
       return
           if !do_another_subtask();
       $fail_reason = do_major_cleanup();
       return $main_cry->warn ({reason => $fail_reason})
            if $fail_reason;
       $main_cry->ok;

    }

(Note that "$crier" is set at file scope, which means it is available
to subroutines further in the same file.)

This takes advantage of the default closing status being -3, "ABORT." This
means that if any cry object is destroyed, presumably because the cry variable
went out of scope without doing a close method (or its equivalents), C<abort>
will automatically be called.

Next we do_a_subtask and do_another_subtask (whatever these are!). If
either fails, we simply return.  Automatically then, the C<abort>
will be called to close out the context.

In the third step, we do_major_cleanup().  If that fails, we explicitly
close out with a warning (the C<warn>), and we pass some reason text.

If we get through all three steps, we close out with an OK.

=head2 Filtering

Often a script will have a verbosity option (-v usually), that allows a
user to control how much output to see.  

Actium::Env::CLI::Crier allows filtering out of messages in two ways.  First,
it can remove all those messages that are lower than a particular importance.
Second, it can remove all those messages that are nested more deeply than a
particular level.

=head3 Filtering by importance

If the I<filter_below_importance> attribute is set to a number between 1 and 7,
then messages lower than that importance will not be shown.

 my $crier = Actium::Env::CLI::Crier->new(filter_below_importance => 5);
 my $x = $crier->cry6("A quite important cry"); # will be shown
 my $y = $crier->cry5("A moderately important cry"); # will be shown
 my $z = $crier->cry4("A less important cry"); # will not be shown

Cries that are unimportant are not shown, and they do not add to the 
nesting level. So, something like this:

 my $crier = Actium::Env::CLI::Crier->new(filter_below_importance => 2);
 my $x = $crier->cry3("A normal cry"); # will be shown
 my $y = $crier->cry1("A trivial cry");  # will not be shown
 my $z = $crier->cry1("A generally unimportant cry");  # will be shown
 $z->ok;
 $y->ok;
 $x->ok;

Would appear as 

 A normal cry...
    A generally unimportant cry............................[OK]
 A normal cry..............................................[OK]

whereas, if "filter_below_importance" were not set, it would appear as 

 A normal cry...
   A trivial cry...
       A generally unimportant cry.........................[OK]
   A trivial cry...........................................[OK]
 A normal cry..............................................[OK]

=head3 Filtering by level

If the I<filter_above_level> attribute is set to a number, then
cries that are deeper than that level will not be shown.

 $crier->Actium::Env::CLI::Crier->new(filter_above_level => 2);
 $crier->cry("A cry at the first level"); # will be shown
 $crier->cry("A cry at the second level"); # will be shown
 $crier->cry("A cry at the third level"); # will not be shown

Set the I<filter_above_level> to 0 to mute all output.

If both options are set, then cries need to pass both criteria to be shown.

One common use for this would be with a "-verbose" option to a script.

=head3 But Show Severe Statuses

If you're filtering messages, sometimes you still want to see a message
regardless of the filtering -- for example, a severe error. To set this, use
the always_show_status_above option. 

The name is a little misleading -- "above" refers to the absolute value of the
status, not the status itself. It is possible to set the positive and negative
values separately:

 $crier->always_show_status_above([-5, 4])

This will show, regardless of the filter settings, any status with numeric
value less than -5 (-6 or -7), or greater than 4 (5, 6, or 7).

Or, it is possible to set a single value, which is taken to be an absolute
value. 

  $crier->always_show_status_above(3) 

This is the same as C<< $crier->always_show_status_above([-3, 3]) >>. 

See L<Completion Status|/Completion Status> above for the severity numbers.

=head2 Output to Other File Handles

By default, Actium::Env::CLI::Crier writes its output to STDERR. You can tell
it to use another file handle like this:

    open (my $fh, '>', 'some_file.txt') or die;
    my $crier = Actium::Env::CLI::Crier::->new({fh => $fh});

Alternatively, if you pass a scalar reference in the fh attribute, the
output will be appended to the string at the reference:

    my $output = "Cry output:\n";
    my $crier = Actium::Env::CLI::Crier::->new({fh => \$output});

If there is only one argument to C<new>, it is taken as the "fh"
attribute:

    open ($fh, '>', 'some_file.txt') or die;
    my $crier = Actium::Env::CLI::Crier::->new($fh);
    # same as ->new({ fh => $fh })

The output destination is determined at the creation of the crier
object, and cannot be changed.

=head2 Return Status

Methods that attempt to write to the output (including C<cry> and C<c> and
their equivalents) return a defined value on success and undef on failure.
Failure can occur, for example, when attempting to write to a closed
filehandle. Note that a test should be made for defined-ness rather than truth,
since "0" is a valid status meaning "ok".

=head2 Message Bullets

You may preceed each message with a bullet. A bullet is usually a
single character such as a dash or an asterisk, but may be multiple
characters. You probably want to include a space after each bullet,
too.

The width used for bullets is the same for all bullets, whatever is
specified. If bullets are shorter than the maximum width, they are
padded out with spaces.

You may have a different bullet for each nesting level. Levels deeper
than the number of defined bullets will use the last bullet.

Bullets can be set by passing an array reference of the bullet strings
as the I<bullets> attribute, or to the C<set_bullets> method, to the
crier.

If you want the bullet to be the same for all levels, just pass the
string.  Here's some popular bullet definitions:

    bullets => "* "
    bullets => [" * ", " + ", " - ", "   "]

Also, a bullet can be changed for a particular cry with the I<bullet> attribute
to C<cry> or the C<set_bullet> method on the cry object (although the method
can only affect the object after it is opened).

Here's an example with bullets turned on:

 * Loading system information...
 +   Defined IP interface information......................... [OK]
 +   Running IP interface information......................... [OK]
 +   Web proxy definitions.................................... [OK]
 +   NTP Servers.............................................. [OK]
 +   Timezone settings........................................ [OK]
 +   Internal clock UTC setting............................... [OK]
 +   sshd Revocation settings................................. [OK]
 * Loading system information................................. [OK]
 * Loading current CAS parameters............................. [OK]
 * RDA CAS Setup 8.10-2...
 +   Updating configuration...
 -     System parameter updates............................... [OK]
 -     Updating CAS parameter values...
         Updating default web page index...................... [OK]
 -     Updating CAS parameter values.......................... [OK]
 +   Updating configuration................................... [OK]
 +   Forced stopping web server............................... [OK]
 +   Restarting web server.................................... [OK]
 +   Loading crontab jobs...remcon............................ [OK]
 * RDA CAS Setup 8.10-2....................................... [DONE]

If not all bullets are the same width (according to the Unicode::GCString
module), the bullets will be made the same width by adding spaces to the right.

=head2 Mixing Actium::Env::CLI::Crier with other output

Internally, Actium::Env::CLI::Crier keeps track of the output cursor position.
It only knows about what it has sent to the output destination. If you mix
C<print> or C<say> statements, or other output methods, with your
Actium::Env::CLI::Crier output, then things will likely get screwy.  So, you'll
need to tell Actium::Env::CLI::Crier where you've left the cursor.  Do this by
using  C<set_position>:

    $cry = $crier->cry("Doing something");
    print "\nHey, look at me, I'm printed output!\n";
    $cry->set_position(0);  # Tell where we left the cursor

(Using C<set_position> will skip the backspacing of the next C<over>.)

=head1 SUBROUTINES, METHODS, ATTRIBUTES REFERENCE

=head2 Class Method

=head3 Actium::Env::CLI::Crier->new()

This is the C<new> constructor inherited from Moose by
Actium::Env::CLI::Crier. It creates a new Crier object: the object associated
with a particular output.

It accepts various attributes as options, which are listed in
L<Attributes|/Attributes> below. Attributes can be specified in the
arguments to C<new> as a list of keys and values or as a hash
reference.

However, if the first argument is a file handle or reference to a
scalar, that will be taken as the output destination for this crier.

If no arguments are passed, it will use STDERR as the output.

=head2 Crier Object Methods

=head3 $crier->cry()

This creates a new cry. Specifically, it creates a new
C<Actium::Env::CLI::Crier::Cry> object, and then that object outputs the
opening text and the ellipsis:

 my $cry = $crier->cry('Starting a task');

produces the output

 Starting a task...

It accepts various attributes as options, which are listed in
L<Attributes|/Attributes> below. Attributes must be provided in
hashrefs. If more than one hashref is provided to C<cry>, then they
will all be used as options. If there are conflicts, later items will
take priority over earlier items in the argument list.

Non-reference arguments are taken to be texts, which are concatenated
together (with texts separated by the value of perl's C<$,> variable;
see L<$, in the perlvar man page|perlvar/"$,">) and used as the opening
text of the cry.

If there is only one non-hashref argument, and it is an array
reference, then the first two entries of the array will be used as the
opening and closing text of the cry. In other words,

 $cry = $crier->cry( ['Open text', 'Close text'] );

is the same as

 $cry = $crier->cry(
      { -opentext => 'Open text', -closetext => 'Close text'}
   );

If the open text is not provided using any of these ways, then the name
of the calling subroutine will be used as the opening text.

It is not correct to call C<cry> in void context:

  $crier->cry("Doing something")

Since C<cry> creates a cry object, calling it in void context leaves noplace to
store it. If it is called in void context, the cry will immediately close with
a WARN tag (status -1), and will display 'Cry error (cry object not saved)'.

=head3 $crier->cry0, cry1, cry2, etc., through cry7

These are shortcuts for 

 $crier->cry ( ..., { importance => n } )

With something like

 $cry->cry1 ( 'Starting task', { importance => 0 } );
 $cry->cry1 ( 'Starting task', { importance => 5 } );

The number that is part of the method name will take precedence, so each of
these will actually be given importance 1.

=head3 $crier->last_cry()

This returns the most recent cry from Actium::Env::CLI::Crier's stack of cries.

=head3 $crier->prog() and $crier->over()

Outputs a progress indication, such as a percent or M/N or whatever you
devise.  In fact, this simply puts *any* string on the same line as the
original message (for the current level). 

Using C<over> will first backspace over a prior progress string (if
any) to clear it, then it will write the progress string. The prior
progress string could have been emitted by C<over> or C<prog>; it
doesn't matter.

The C<prog> method does not backspace, it simply puts the string out
there.

For example,

  my $cry = cry "Performing a task";
  $cry->prog '10%...';
  $cry->prog '20%...';

gives this output:

  Performing a task...10%...20%...

Keep your progress string small!  The string is treated as an
indivisible entity and won't be split.  If the progress string is too
big to fit on the line, a new line will be started with the appropriate
indentation.

With creativity, there's lots of progress indicator styles you could
use.  Percents, countdowns, spinners, etc. Look at sample005.pl
included with this package. Here's some styles to get you thinking:

        Style       Example output
        -----       --------------
        N           3       (overwrites prior number)
        M/N         3/7     (overwrites prior numbers)
        percent     20%     (overwrites prior percent)
        dots        ....    (these just go on and on, one dot for every step)
        tics        .........:.........:...
                            (like dots above but put a colon every tenth)
        countdown   9... 8... 7...
                            (liftoff!)

If the cry in question was filtered out, or if it has been muted, or if the
L<shows_progress|/shows_progress> option is set in the crier, the progress text
will not be displayed.


=head3 $crier->wail()

This outputs the given text without changing the current level. Use it
to give additional information, such as a blob of description. Lengthy
lines will be wrapped to fit nicely in the given width, using Unicode
definitions of column width (to allow for composed or double-wide
characters).

Note that if the most recent cry was filtered out, the wail will not be shown
either.

=head2 Cry Object Methods

=head3 $cry->c()

This closes the cry, either re-outputting the open text (if it's not on
the same line) or outputting the close text, padding out with the
trailer character, and then outputting the severity.

    Closing text.........................................[OK]

It accepts various attributes as options, which are listed in
L<Attributes|/Attributes> below.

Attributes must be provided in hashrefs. If more than one hashref is
provided, then they will all be used as options. If there are
conflicts, later items will take priority over earlier items in the
argument list.

The first argument, if it is not a reference, is taken to be the closing status
and/or status tag. Numbers from -7 to 7 are taken to be the closing status.
Anything else is taken to be a closing tag, which will, if it is a standard
tag, set the status accordingly.  

 $cry->c('OK'); # uses status 0

If a standard tag is given as the first argument, it wll override the status
code:

 $cry->c('PANIC', { status => '0'} ); # uses status -7

Although the tag will be displayed as provided, it will match the status code
regardless of case.

 $cry->c('done'); # will display '[done]' but will still use status 3

If provided in any other way, the tag will use whatever status is given:

 $cry->c({ tag => 'ALERT', status => 5 }); 
 # misleading: will display 'ALERT' but be status 5, which
 # normally corresponds to 'PASS'

A non-standard tag will use whatever status is otherwise provided:

 $cry->c('UM...'); # uses the default status
 $cry->c('YIPE', { status => -2 }); # uses status 2

If no status tag or numeric status is given, it will use the status and tag
that was set otherwise (either as an option on this call, or earlier as an
option in the constructor or via a method).

One attribute, I<reason>, is only applicable from within a C<c> call
(or its equivalents).

=head3 Convenience synonyms for "c"

These are called as C<< $cry->ok() >>, C<< $cry->done >>, etc.

For convenience, several methods exist to abbreviate the C<< $cry->c >> method,
for the standard tags:

  $cry->bliss      $cry->panic
  $cry->calm       $cry->alert
  $cry->pass       $cry->fail
  $cry->valid      $cry->error     
  $cry->done       $cry->abort
  $cry->info       $cry->warn     
  $cry->yes        $cry->no
           $cry->ok

Calling C<< $cry->bliss >> is the same as calling << $cry->c('BLISS', ...) >>,
and so forth.

=head3 $cry->c_quiet()

This is equivalent to C<cry>, except that it does NOT output a wrapup
line or a completion severity.  It simply closes out the current level
with no message. (It is the same as setting the L<muted|/muted> option.) 
A severity level can still be set by passing an argument.

=head3 $cry->prog() and $cry->over()
The same as 
L<< $crier->prog() and $crier->over()|/$crier->prog() and $crier->over() >>.

=head3 C<$cry->wail>

The same as L<< $crier->wail|/$crier->wail >>.

=head2 Attributes

There are several ways that attributes can be set: as the argument to
the B<new> class method, as methods on the crier object, as arguments
to the B<cry> object method, as methods on the cry object, or as
options to B<done> and its equivalents. Some are acceptable in all
those places!  Rather than list them separately for each type, all the
attributes are listed together here, with information as to how they
can be set and/or used.

=head3 always_show_status_above

=over

=item I<always_show_status_above> option to C<new>

=item get method: C<< $crier->always_show_status_above() >>

=item set method: C<< $crier->set_always_show_status_above() >>

=back

A reference to an array of two numbers: one between -7 and 0, and the other
between 0 and 7.  Below the first number and above the second number, these
statuses will always be shown, even if they would otherwise be filtered out by
level or importance.

If not defined, no statuses will override the filtering.

If set to a single number, it will be treated as though that number and its
negative had been set: so "5" will become [-5, 5].

See L<But Show Severe Statuses|/But Show Severe Statuses>, above.

=head3 backspace

=over

=item I<backspace> option to C<new>

=item get method: C<< $crier->backspace() >>

=item set methods: C<< $crier->use_backspace >>> and C<< $crier->no_backspace >>

=back

This attribute determines whether C<< $cry->over >> attempts to send
backspace characters to the terminal or not. Some IDE consoles don't
properly deal with backspaces (I'm looking at you, Eclipse) and so this
attribute turns that off.

Setting the backspace attribute on a crier will affect all future behavior, on
issued cries as well as new ones.

=head3 bullet

=over

=item I<bullet> option to C<cry>, or C<c> or its equivalents

=item get method: C<< $cry->bullet() >>

=item set method: C<< $cry->set_bullet() >>

=back

Normally, the bullet for a cry is derived from the I<bullets> attribute of the
crier object. This attribute allows this to be overridden for this particular
cry.

All bullets are made to take up the same width. When a custom bullet is used,
and that bullet is wider than earlier bullets, the bullet width for the entire
crier is made the width of the widest bullet.

Note that this merely changes the bullet that is used I<if> bullets are used --
the I<bullets> attribute still has to be set.

=head3 bullets

=over

=item I<bullets> option to C<new>

=item get method: C<< $crier->bullets() >>

=item set method: C<< $crier->set_bullets() >>

=back

Enables or disables the use of bullet characters in front of messages.  Set to
a reference to n empty array to disable the use of bullets, which is the
default.  Set to a scalar character string to enable that character(s) as the
bullet.  Set to an array reference of strings to use different characters for
each nesting level.  See L<Message Bullets|/Message Bullets>.

The program makes all bullets take up the same width. When bullets are
altered, the bullet width is made the width of the widest bullet ever
provided. The bullet width is never reduced.

Setting the bullets attribute on a crier will change the bullets used only for
future cries, not cries already issued. However, if the bullet width is
altered, that will affect all future behavior, on issued cries as well as new
ones.

=head3 closetext

=over

=item I<closetext> option to C<cry>, or C<done> or its equivalents

=item get method: C<< $cry->closetext() >>

=item set method: C<< $cry->set_closetext() >>

=back

Supply a string to be used as the closing text that's paired with this
level.  Normally, the same text you use when you issue a C<cry> is the
text used to close it out.  This option lets you specify different
closing text.  See L<Closing with Different Text|/Closing with Different Text>.

=head3 colorize

=over

=item I<colorize> option to C<new>

=item get methods: C<< $crier->colorize >>

=item set methods: C<> $crier->use_color >> and C<< $crier->no_color >>

=back

Set to a true value to render the completion severities in color. ANSI
escape sequences are used for the colors.  The default is to not use
colors.  See L<Status Colors|/Status Colors> above.

Setting the colorize attribute on a crier will affect all future behavior,
on issued cries as well as new ones.

=head3 column_width

=over

=item I<column_width> option to C<new>

=item get method: C<< $crier->column_width() >>

=item set method: C<< $crier->set_column_width() >>

=back

Sets the column width of your output.  C<Actium::Env::CLI::Crier>> doesn't try
to determine how wide your terminal screen is, so use this option to
indicate the width.  The default is 80.

You may want to use L<Term::Size::Any|Term::Size::Any> to determine
your device's width:

    use Term::Size::Any 'chars';
    my ($cols, $rows) = chars();
    my $crier = Actium::Env::CLI::Crier::->new({column_width => $cols});
    ...

One cool trick is to have it set when the program receives a window
change signal:

    my $crier = Actium::Env::CLI::Crier::->new();
    use Term::Size::Any 'chars';
    local $SIG{WINCH} = \&set_width;
    sub set_width {
       my ($cols, $rows) = chars();
       $crier->set_column_width($cols);
    }

Assuming your system sends the proper signal, the width of the lines
will grow and shrink as the window changes size.

=head3 default_importance

=item I<default_importance> option to C<new>

=item get method: C<< $crier->default_importance() >>

=item set method: C<< $crier->set_default_importance() >>

=back

Sets the importance of a cry if none is specified in the C<cry> or equivalent
call. 

Setting the default_importance attribute on a crier will change the default
used only for future cries, not cries already issued. 

Passing undef to set_default_importance restore the default importance to the
original default value (which is 3).

=head3 default_status

=over

=item I<default_status> option to C<new>

=item get method: C<< $crier->default_status() >>

=item set method: C<< $crier->set_default_status() >>

=back

Sets the status to use when completing a cry, if none is specified in the
C<cry> or any C<c> call. Useful when cries are closed because the object gets
destroyed.

Setting the default_status attribute on a crier will change the default used
only for future cries, not cries already issued. 

Passing undef to set_default_importance restore the default status to the
original default value (which is -3).

=head3 ellipsis

=over

=item I<ellipsis> option to C<new>, C<cry>, or C<done> or equivalents

=item get methods: C<ellipsis> (on either $crier or $cry)

=item set methods: C<set_ellipsis> (on either $crier or $cry)

=back

Sets the string to use for the ellipsis at the end of a message. The
default is "..." (three periods).  Set it to a short string. This
option is often used in combination with I<trailer>.

    Performing a task...
                     ^^^_____ These dots are the ellipsis

Setting the ellipsis attribute on a cry will affect only that cry.
Setting it in a C<c> call or equivalent, or using a C<set_ellipsis>
on an already opened cry, will affect only the close of that cry.

Setting the ellipsis attribute on a crier will change the default used
only for future cries, not cries already issued. 

=head3 fh

=over

=item I<fh> option to C<new>

=item get method: C<< $crier->fh() >>

=back

This attribute contains a reference to the file handle to which output
is sent. It cannot be changed once the crier object is created, so is
specified in the argument to C<new>.

=head3 filter_above_level

=over

=item I<filter_above_level> option to C<new>

=item get method: C<< $crier->filter_above_level() >>

=item set method: C<< $crier->set_filter_above_level() >>

=back

Filters messages by setting the maximum level of messages that will be output.
(This is how many levels of sub-task, not the status or importance.) Set to
undef (the default) to see all messages.  Set to 0 to disable B<all> messages
from the crier.  Set to a positive integer to see only messages at that level
and less.

=head3 filter_below_importance

=over

=item I<filter_below_importance> option to C<new>

=item get method: C<< $crier->filter_below_importance() >>

=item set method: C<< $crier->set_filter_below_importance() >>

=back

Filters messages by setting the minimum importance of messages that will be
output.  Set to 0 (the default) to see all messages.  Set to a positive integer
to see only messages at that importance or greater.

=head3 importance

=over

=item conveience synonyms for C<cry>

=item I<importance> option to C<cry>

=back

Sets the importance level of a cry. This is set to the value of the
I<default_importance> option if not specified in the C<cry> or equivalent call.

=head3 muted

=over

=item I<muted> option to C<cry>, or C<c> or equivalents

=item get method: C<< $cry->muted >>

=item set methods: C<< $cry->mute >> and C<< $cry->unmute >>

=back

Set this option to a true value to have output from this cry quieted, except
for the opening text.  It will not display any progress text (from C<prog> or
C<over>), any C<wail> messages, the closing trailer or the status tag.

The return status from the call will still be the appropriate value
for the severity code.

=head3 opentext

=over

=item I<opentext> option to C<cry>

=back

A string to be used as the opening text, output when the cry is
created.

Normally, this is implicit rather than explicit:

 my $cry = $crier->cry({opentext => 'Doing something'});

is the same as

 my $cry = $crier->cry('Doing something');

See L<< $crier->cry()|/$crier->cry() >>.

=head3 position

=over

=item get methods: C<position> (on either $crier or $cry)

=item set methods: C<set_position> (on either $crier or $cry)

=back

Used to reset what Actium::Env::CLI::Crier thinks the cursor position is. You
may have to do this if you mix ordinary print statements with cries.

Set this to 0 to indicate that the position is at the start of a new
line (as in, just after a C<print "\n"> or C<say>). See L</Mixing
Actium::Env::CLI::Crier with other output>.

After setting the position, C<over> will not backspace.

=head3 reason

=over

=item I<reason> option to C<c> or equivalents

=back

After the closing, it will output the given reason string on the
following line(s), indented underneath the completed message.  This is
useful to supply additional failure text to explain to a user why a
certain task failed.

This programming metaphor is commonly used:

    ...
    my $fail_reason = do_something_that_may_fail();
    return $cry->fail ( {-reason => $fail_reason} )
        if $fail_reason;
    ...

=head3 shows_progress

=over

=item I<shows_progress> option to C<new>

=item get method: C<< $crier->shows_progress() >>

=item set methods: C<< $crier->show_progress >> and C<< $crier->hide_progress >>

=back

This attribute determines whether C<< $cry->over >> and C<< $cry->prog >>
display anything. If false, these don't do anything. This is useful for turning
these off via the command line, especially in circumstances where certain dumb
IDE consoles can't backspace.

=head3 status

=over

=item I<status> option to C<cry>, or C<c> or its equivalents

=item first argument to C<c>

=item get method: C<< $cry->status() >>

=item set method: C<< $cry->set_status() >>

=back

Sets the numeric status used when completing a cry. This is set to the value of
the I<default_status> option if not specified in the C<cry> or C<c> call.

See L<Closing with Different Statuses|/"Closing with Different Statuses">.

=head3 step

=over

=item I<step> option to C<new>

=item get methods: C<< $crier->step >>

=item set methods: C<< $crier->set_step >>

=back

Sets the indentation step size (number of spaces) for nesting messages.
The default is 2. Set to 0 to disable indentation - all messages will
be left justified. Set to a small positive integer to use that step
size.

=head3 tag

=over

=item in convienence synoyms for C<c>

=item first argument to C<c>

=item I<tag> option to C<cry>, or C<c> or equivalents

=item get methods: C<< $cry->tag >> 

=item set methods: C<< $cry->set_tag >> 

=back

Sets the status tag: the text displayed in brackets as a message is closed.
See L<< $cry->c()|/$cry->c() >>.

=head3 tag_color

=over

=item I<tag-color> option to C<cry>, or C<c> or equivalents

=item get methods: C<< $cry->tag_color >> 

=item set methods: C<< $cry->set_tag_color >> 

=back

This is the attribute string passed to L<Term::ANSIColor|Term::ANSIColor> to
colorize this tag. See that module for details. If the I<colorize> attribute is
false, this will not be sent. Set it to an empty string to disable color for
this tag only.

=head3 timestamp

=over

=item I<timestamp> option to C<new>, C<cry>, or C<done> or equivalents

=item get methods: C<timestamp> (on either $crier or $cry)

=item set methods: C<set_timestamp> (on either $crier or $cry)

=back

If false (the default), output lines are not prefixed with a timestamp.  If a
true scalar, the default local timestamp HH::MM::SS is prefixed to each line.
If it's a coderef, then that function is called to get the timestamp string.
The function is passed the current indent level, for what it's worth.  Note
that no delimiter is provided between the timestamp string and the emitted
line, so you should provide your own (a space or colon or whatever).  Also,
C<wail> output is not timestamped, just the opening and closing text.

=head3 trailer

=over

=item I<trailer> option to C<new>, C<cry>, or C<done> or equivalents

=item get methods: C<trailer> (on either $crier or $cry)

=item set methods: C<set_trailer> (on either $crier or $cry)

=back

The single character used to trail after a message up to the completion
severity. It must be one column wide.

The default is the dot (the period, ".").  Here's what messages look
like if you change it to an underscore:

  The code:
    my $crier = Actium::Env::CLI::Crier::->new({trailer =>'_'});
    $crier->cry("Doing something");

  The output:
    Doing something...______________________________ [DONE]

Note that the ellipsis after the message is still "..."; use
I<ellipsis> to change that string as well.

Setting the trailer attribute on a cry will affect only that cry.
Setting it in a C<c> call or equivalent, or using a C<set_trailer>
on an already opened cry, will affect only the close of that cry.

Setting the trailer attribute on a crier will affect all future cries, but not
any cries that have already been opened.

=head1 DIAGNOSTICS

=over

=item *

'Cry error (cry object not saved)'

The C<cry> method was called in void context. This creates an object
which should be saved to a variable. See L<< $crier->cry()|/$crier->cry() >>.

=item *

Arguments given in "use Actium::Env::CLI::Crier (default_crier => {args})" but the default crier has already been initialized

A module attempted to set attributes to the default crier in the import
process, but the default crier can only be created once.  (You can use
methods to set all attributes to the default crier, with the exception
of the filehandle.)

=back

=head1 DEPENDENCIES

=over

=item Perl 5.024

=item the Actium system

=item Moose

=item Term::ANSIColor (required only if colorizing)

=item Unicode::LineBreak

=item Unicode::GCString

=back

=head1 NOTES

Actium::Env::CLI::Crier is a fork of Term::Emit, by Steve Roscio. Term::Emit is
great, but it is dependent on Scope::Upper, which hasn't always compiled
cleanly in my installation, and also Term::Emit uses a number of global
variables, which save typing but mean that its objects aren't self-contained.
Actium::Env::CLI::Crier is designed to do a lot of what Term::Emit does, but in
a somewhat cleaner way, even if it means there's a bit more typing involved.

Actium::Env::CLI::Crier does use Moose, which is somewhat odd for a
command-line program. Since many other Actium programs also use Moose, this is
a relatively small loss in this case. If this ever becomes a separate
distribution it should probably use something else, such as Moo.

=head1 BUGS AND LIMITATIONS

The test suite consists mainly of tests adapted from Term::Emit, and many of
the new methods and capabilities are not tested.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2015-2018

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

