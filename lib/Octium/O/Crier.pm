package Octium::O::Crier 0.011;

# Actium/O/Crier - Print with indentation, status, and closure
# Based on Term::Emit by Steve Roscio

use Octium ('class');
use Octium::Types (qw<ARCrierBullets CrierBullet CrierTrailer>);
use Octium::O::Crier::Cry;
use Scalar::Util;

const my $CRY_CLASS            => 'Octium::O::Crier::Cry';
const my $FALLBACK_CLOSESTAT   => 'DONE';
const my $DEFAULT_COLUMN_WIDTH => 80;
const my $DEFAULT_STEP         => 2;

#########################################################
### EXPORTS

# Moved to Octium::Crier since this didn't seem to work

#use Sub::Exporter -setup => {
#    exports => [
#        'cry' => \&_build_cry,
#        'cry_text',
#        'default_crier' => \&_build_default_crier,
#    ]
#};
## Sub::Exporter ### DEP ###
#
#my $default_crier;
#
#sub _build_default_crier {
#    my ( $class, $name, $arg ) = @_;
#
#    if ( defined $arg and scalar keys %$arg ) {
#        if ($default_crier) {
#            croak 'Arguments given in '
#              . q{"use Octium::O::Crier (default_crier => {args})"}
#              . q{but the default crier has already been initialized};
#        }
#
#        $default_crier = __PACKAGE__->new($arg);
#        return sub {
#            return $default_crier;
#        };
#    }
#
#    return sub {
#        $default_crier = __PACKAGE__->new()
#          if not $default_crier;
#        return $default_crier;
#      }
#
#} ## tidy end: sub _build_default_crier
#
#sub _build_cry {
#    return sub {
#        $default_crier = __PACKAGE__->new()
#          if not $default_crier;
#        return $default_crier->cry(@_);
#      }
#}
#
## that is only necessary because we have a cry subroutine and a cry object
## method and we want them to do different things
#
#sub cry_text {
#    $default_crier = __PACKAGE__->new()
#      if not $default_crier;
#    return $default_crier->text(@_);
#}

#####################################################################
## FILEHANDLE, AND OBJECT CONSTRUCTION SETTING FILEHANDLE SPECIALLY

has fh => (
    is      => 'ro',
    isa     => 'FileHandle',
    default => sub { *STDERR{IO} },
);

sub _fh_or_scalarref {
    my $class = shift;
    my $arg   = shift;

    return $arg if defined Scalar::Util::openhandle($arg);

    if ( defined u::reftype($arg) and u::reftype($arg) eq 'SCALAR' ) {
        open( my $fh, '>', \$_[0] );
        return $fh;
    }

    return;

}

around BUILDARGS ($orig, $class : slurpy @) {

    # if first argument is handle or reference to scalar,
    # use it as argument to "fh" .
    # Pass everything else through to Moose.

    # If no arguments, make fh be the handle for STDERR

    # ->new()
    if ( @_ == 0 ) {
        return $class->$orig( fh => *STDERR{IO} );
    }

    if ( @_ == 1 ) {

        # ->new($fh)
        # or ->new(\$scalar)
        my $handle = $class->_fh_or_scalarref( $_[0] );
        if ( defined $handle ) {
            return $class->$orig( fh => $handle );
        }

        # ->new({ option => option1, ... })
        return $class->$orig(@_);
    }

    my $firstarg = shift;
    my $fh       = $class->_fh_or_scalarref($firstarg);

    if ( defined $fh ) {

        # ->new($fh, {option => option1, ...})
        if ( @_ == 1 and u::reftype( $_[0] ) eq 'HASH' ) {
            return $class->$orig( fh => $fh, %{ $_[0] } );
        }
        else {
            # ->new($fh, option => option1 ,...)
            return $class->$orig( fh => $fh, @_ );
        }
    }

    # ->new(option => option1 ,...)
    return $class->$orig( $firstarg, @_ );

} ## tidy end: around BUILDARGS

######################
## WIDTH AND POSITION

has 'position' => (
    is      => 'ro',
    writer  => '_set_position_without_prog_cols',
    isa     => 'Int',
    default => 0,
);

has '_prog_cols' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

sub set_position {
    my $self = shift;
    my $col  = shift;
    $self->_set_position_without_prog_cols($col);
    $self->_set_prog_cols(0);
}

# backs over this many columns during $cry->over
# this means will send two backspaces for each double-wide character
# This seems to be the right thing in Mac oS X Terminal;
# not sure about other terminals

has 'column_width' => (
    is      => 'rw',
    isa     => 'Int',
    default => $DEFAULT_COLUMN_WIDTH,
);

#############################
### DISPLAY FEATURES

has 'ellipsis' => (
    is      => 'rw',
    isa     => 'Str',
    default => '...',
);

has 'colorize' => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0,
    traits  => ['Bool'],
    handles => {
        use_color => 'set',
        no_color  => 'unset',
    },
);

has 'timestamp' => (
    is      => 'rw',
    isa     => 'Bool | CodeRef',
    default => 0,
);

has 'trailer' => (
    is      => 'rw',
    isa     => CrierTrailer,
    default => '.',
);

has 'shows_progress' => (
    isa     => 'Bool',
    is      => 'ro',
    default => 1,
    traits  => ['Bool'],
    handles => {
        show_progress => 'set',
        hide_progress => 'unset',
    },
);

has 'backspace' => (
    isa     => 'Bool',
    is      => 'ro',
    default => 1,
    traits  => ['Bool'],
    handles => {
        use_backspace => 'set',
        no_backspace  => 'unset',
    },
);

#########################
## BULLETS, INDENTATION, LEVELS

has 'bullets_r' => (
    is       => 'bare',
    isa      => ARCrierBullets,
    init_arg => 'bullets',
    reader   => '_bullets_r',
    writer   => '_set_bullets_r',
    coerce   => 1,
    default  => sub { [] },
    traits   => ['Array'],
    handles  => {
        bullets      => 'elements',
        bullet_count => 'count',
        bullet       => 'get',
    },
    trigger => \&_alter_bullet_width,
);

sub set_bullets {
    my $self    = shift;
    my @bullets = u::flatten(@_);
    $self->_set_bullets_r(@bullets);
}

sub _bullet_for_level {
    my $self  = shift;
    my $count = $self->bullet_count;

    return $EMPTY unless $count;

    my $level = shift;
    $level = $count if $level > $count;

    return $self->bullet( $level - 1 );

    # zero-based array

}

has '_bullet_width' => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
    builder  => '_build_bullet_width',
    lazy     => 1,
);

sub _build_bullet_width {
    my $self = shift;
    my $bullets_r = shift // $self->_bullets_r();

    # $bullets_r is passed when called as trigger,
    # but not when called as builder

    return 0 if @{$bullets_r} == 0;

    my $width = u::max( map { u::u_columns($_) } @{$bullets_r} );
    return $width;
}

sub _alter_bullet_width {
    my $self      = shift;
    my $bullets_r = shift;

    my $bullet_width = $self->_bullet_width;

    my $newbullet_width = u::max( map { u::u_columns($_) } @{$bullets_r} );

    return if $newbullet_width <= $bullet_width;

    $self->_set_bullet_width($newbullet_width);

    return;

}

has 'step' => (
    is      => 'rw',
    isa     => 'Int',
    default => $DEFAULT_STEP,
);

has 'maxdepth' => (
    is      => 'rw',
    isa     => 'Maybe[Int]',
    default => undef,
);

#########################
## SEVERITY

{

    # copied straight out of Term::Emit, with a few additions
    # I don't know why the values are what they are.
    const my %SEVERITY_NUM_OF => (
        EMERG => 15,
        PANIC => 15,
        HAVOC => 14,
        ALERT => 13,
        DARN  => 12,
        CRIT  => 11,
        FAIL  => 11,
        FATAL => 11,
        ARGH  => 10,
        ERR   => 9,
        ERROR => 9,
        OOPS  => 8,
        WARN  => 7,
        NOTE  => 6,
        INFO  => 5,
        OK    => 5,
        DEBUG => 4,
        NOTRY => 3,
        UNK   => 2,
        OTHER => 1,
        YES   => 1,
        PASS  => 1,
        NO    => 0,
    );

    sub _severity_num {
        my $self    = shift;
        my $sevtext = uc(shift);
        return $SEVERITY_NUM_OF{OTHER}
          unless exists $SEVERITY_NUM_OF{$sevtext};
        return $SEVERITY_NUM_OF{$sevtext};
    }

}

has 'override_severity' => (
    is      => 'ro',
    isa     => 'Int',
    default => -1,
);

has 'minimum_severity' => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has 'default_closestat' => (
    is      => 'rw',
    isa     => 'Str',
    default => $FALLBACK_CLOSESTAT,
);

###########################
### CRIES AND LEVELS

has '_cries_r' => (
    is      => 'ro',
    isa     => "ArrayRef[$CRY_CLASS]",
    traits  => ['Array'],
    handles => {
        cries      => 'elements',
        _pop_cry   => 'pop',
        cry_level  => 'count',
        _first_cry => [ get => 0 ],
        _last_cry  => [ get => -1 ],
    },
    default => sub { [] },
);

sub _push_cry {
    my $self = shift;
    my $cry  = shift;

    my $cries_r = $self->_cries_r;

    push @{$cries_r}, $cry;
    Scalar::Util::weaken( ${$cries_r}[-1] );

}

{
    no warnings 'redefine';
    #eval {
    sub cry {
        goto &cry_method;
    }

    sub last_cry {
        goto &last_cry_method;
    }
    #}
}

sub cry_method {
    my $self = shift;

    my ( %opts, @args );

    foreach (@_) {
        if ( defined( u::reftype($_) ) and u::reftype($_) eq 'HASH' ) {
            %opts = ( %opts, %{$_} );
        }
        else {
            push @args, $_;
        }
    }

    if ( exists $opts{silent} ) {
        $opts{muted} = 1;
    }

    if (    @args == 1
        and defined( u::reftype( $args[0] ) )
        and u::reftype( $args[0] ) eq 'ARRAY' )
    {
        my @pair = @{ +shift };
        $opts{opentext}  = $pair[0];
        $opts{closetext} = $pair[1];
    }
    else {
        my $separator = u::define($OUTPUT_FIELD_SEPARATOR);
        $opts{opentext} = join( $separator, @args );
    }

    my $level = $self->cry_level + 1;

    unless ( defined $opts{opentext} and $opts{opentext} ) {
        my $msg;
        ( undef, undef, undef, $msg ) = caller(1);
        $opts{opentext} = $msg;
        $opts{opentext} =~ s{\Amain::}{}sxm;
    }

    if ( defined $opts{bullet} ) {
        $self->_alter_bullet_width( $opts{bullet} );
    }

    #else {
    #    $opts{bullet} = $self->_bullet_for_level($level);
    #}

    my $cry = $CRY_CLASS->new(
        %opts,
        _crier => $self,
        _level => $level,
    );

    my $success = $cry->_built_without_error;
    return $success unless $success;

    $self->_push_cry($cry);

    return $cry if defined wantarray;

    $cry->d_unk( { reason => 'Cry error (cry object not saved)' } );

    # void context - close immediately
    return;

} ## tidy end: sub cry_method

sub _close_up_to {
    my $self          = shift;
    my $cry           = shift;
    my @original_args = @_;

    my $this_cry = $self->_pop_cry;
    my $success;

    while ( $this_cry
        and ( u::refaddr($this_cry) != u::refaddr($cry) ) )
    {
        $success = $this_cry->_close;    # default severity and options
        return $success unless $success;
        $this_cry = $self->_pop_cry;
    }

    return $cry->_close(@original_args);

}

sub last_cry_method {
    my $self = shift;

    my $cry;
    if ( $self->cry_level == 0 ) {

        # caller's subroutine name
        $cry = $self->cry( { silent => 1, closestat => 'UNK' } );
    }
    else {
        $cry = $self->_last_cry;
    }

}

sub text {

    my $self = shift;
    my @args = @_;
    my $cry  = $self->last_cry;

    return $cry->text(@_);

}

sub DEMOLISH {
    my $self = shift;

    my @cries = $self->cries;
    if (@cries) {
        $self->_close_up_to( $cries[0] );
    }

    return;

}

1;

__END__

=encoding utf8

=head1 NAME

Octium::O::Crier - Terminal notification with indentation, status, and
closure

=head1 VERSION

This documentation refers to version 0.009

=head1 SYNOPSIS

 use Octium::O::Crier;

 my $crier = Octium::O::Crier::->new();

 my $task_cry = $crier->cry("Main Task");
 ...
 my $subtask_cry = $crier->cry("First Subtask");
 ...
 $subtask_cry->done;
 ...
 my $another_subtask_cry = $crier->cry("Second Subtask");
 ...
 $another_subtask_cry->done;
 ...
 $task_cry->done;

This results in this output to STDOUT:

 Main task...
     First Subtask..............................................[DONE]
     Second Subtask.............................................[DONE]
 Main task......................................................[DONE]

There are procedural shortcuts for output to a default destination:

 use Octium::O::Crier(cry);

 my $task_cry = cry("Main Task");
 ...
 my $subtask_cry = cry("First Subtask");
 ...
 $subtask_cry->done;
 ...
 my $another_subtask_cry = cry("Second Subtask");
 ...
 $another_subtask_cry->done;
 ...
 $task_cry->done;

This produces the same output as before.

=head1 DESCRIPTION

Octium::O::Crier is used to to output balanced and nested messages with
a completion status.  These messages indent easily within each other,
are easily parsed, may be bulleted, can be filtered, and even can show
status in color.

For example, you write code like this:

    use Octium::O::Crier;
    my $crier = Octium::O::Crier::->new()
    my $cry = $crier->cry("Performing the task");
    first_subtask($crier);
    second_subtask($crier);
    $cry->done;

It begins by outputting:

    Performing the task...

Then it does the first subtask and the second subtask. When these are
complete, it adds the rest of the line: a bunch of dots and the [DONE].

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

A series of examples will make Octium::O::Crier easier to understand.

=head2 Basics

Here is a basic example of usage:

    use Octium::O::Crier;
    my $crier = Octium::O::Crier::->new();
    my $cry = $crier->cry("Performing a task");
    sleep 1; # simulate task performance
    $cry->done;

First this outputs:

    Performing a task...

Then after the task process is complete, the line is continued so it
looks like this:

    Performing a task........................................... [DONE]

Octium::O::Crier works by creating two sets of objects. The I<crier>
represents the destination of the cries, such as the terminal, or an
output file. The I<cry> object represents a single cry, such as a cry
about one particular task or subtask.  Methods on these objects are
used to issue cries and complete them.

The crier object is created by the C<new> class method of
C<Octium::O::Crier>. The cry object is created by the C<cry> object
method of the crier object.

=head2 Exported subroutines: shortcut to a default output destination

Since most output from Octium::O::Crier is to a single default output
destination for that process (typically STDERR), some procedural
shortcuts exist to make it easier to send cries to a default output.

To use the shortcuts, specify them in the import list in the  C<use
Octium::O::Crier> call. C<< "use Octium::O::Crier ( qw(cry))" >> will
install a sub called C<cry> in your package that will call the C<cry>
method on the default crier object. Therefore,

 use Octium::O::Crier ( qw(cry) );
 my $cry = cry ("Doing a task");

works basically the same as

 use Octium::O::Crier;
 my $crier = Octium::O::Crier::->new();
 my $cry = $crier->cry ("Doing a task");

except that in the former case, the crier object is stored in the
Octium::O::Crier class and will be reused by other calls to C<cry>,
from this module or any other. This avoids the need to pass the crier
object as an argument to routines in other modules.

See L</Subroutines> below.

=head2 Completion upon destruction

In the above example, we end with a C<done> call to indicate that the
thing we told about (I<Performing a task>) is now done. But we don't
need to do the C<done>.  It will be called automatically for us when
the cry object (in this example, held in the variable C<$cry>) is
destroyed, such as when the variable goes out of scope (for this
example: when the program ends). So the code example could be just
this:

    use Octium::O::Crier;
    my $crier = Octium::O::Crier::->new();
    my $cry = $crier->cry("Performing a task");
    sleep 1; # simulate task performance

and we'd get the same results (assuming the program ends there).

Completion upon destruction is useful especially in circumstances where
the program exits less than cleanly, but also simply when it is
convenient to avoid additional method calls at the end of a function.

=head2 Completion Severity

There's many ways a task can complete.  It can be simply DONE, or it
can complete with an ERROR, or it can be OK, etc.  These completion
codes are called the I<severity code>s.  C<Octium::O::Crier> defines
many different severity codes.

Severity codes also have an associated numerical value. This value is
called the I<severity number>. It's useful for comparing severities to
each other or filtering out severities you don't want to be bothered
with.

Here are the severity codes and their severity numbers. Those on the
same line are considered equal in severity:

    EMERG => 15,
    HAVOC => 14,
    ALERT => 13,
    DARN  => 12,
    CRIT  => 11, FAIL => 11, FATAL => 11,
    ARGH  => 10,
    ERROR => 9, ERR => 9,
    OOPS  => 8,
    WARN  => 7,
    NOTE  => 6,
    INFO  => 5, OK => 5,
    DEBUG => 4,
    NOTRY => 3,
    UNK   => 2,
    YES   => 1, PASS  => 1,
    NO    => 0,

You may make up your own severities if what you want is not listed.
Please keep the length to 5 characters or less, otherwise the text may
wrap. Any severity not listed is given the value 1.

To complete with a different severity, call C<done> with the severity
code like this:

    $crier->done("WARN");

C<done> and its equivalents return with the severity number from the
above table, otherwise it returns 1, unless there's an error in which
case it returns false.

As a convienence, it's easier to use methods that incorporate the 
severity level, such as C<d_ok> or C<d_fail>. See  L<Convenience
methods for "done"|#Convenience methods for "done"> below for  a
complete list.

We'll change our simple example to give a FATAL completion:

    use Octium::O::Crier;
    my $crier = Octium::O::Crier::->new();
    my $cry = $crier->cry("Performing a task");
    sleep 1; # simulate task performance
    $cry->d_fatal;

Here's how it looks:

    Performing a task........................................... [FATAL]

=head3 Severity Colors

One feature of C<Octium::O::Crier> is that you can enable colorization
of the severity codes.  That means that the severity code inside the
square brackets is output in color, so it's easy to see. The module
Term::ANSIColor is used to do the colorization.

Here's the colors:

        EMERG    bold blink bright white on red
        PANIC    bold blink bright white on red
        HAVOC    bold blink black on bright yellow
        ALERT    bold blink bright yellow on red
        DARN     bold blink red on white
        CRIT     bold bright white on red
        FAIL     bold bright white on red
        FATAL    bold bright white on red
        ARGH     bold red on white
        ERR      bold bright yellow on red
        ERROR    bold bright yellow on red
        OOPS     bold bright yellow on bright black
        WARN     bold black on bright yellow
        NOTE     bold bright white on blue
        INFO     bold black on green
        OK       bold black on green
        DEBUG    bright white on bright black
        NOTRY    bold bright white on magenta
        UNK      bold bright yellow on magenta
        YES      green
        PASS     green
        NO       bright red

To use colors on all cries, pass 'colorize => 1' as an option to the
C<new> method call:

    my $crier = Octium::O::Crier::->new({colorize => 1});

Or, invoke the use_color method on the crier, once it's created:

    $crier->use_color;

Cries also accept the colorize argument or the use_color method, so
that individual cries can be colorized or not.

Run sample003.pl, included with this module, to see how the colors look
on your terminal.

=head2 Nested Messages

Nested cries will automatically indent with each other. You do this:

    use Octium::O::Crier;
    my $crier = Octium::O::Crier::->new();
    my $aaa = $crier->cry("Aaa")
    my $bbb = $crier->cry("Bbb")
    my $ccc = $crier->cry("Ccc")

and you'll get output like this:

    Aaa...
      Bbb...
        Ccc.......................... [DONE]
      Bbb............................ [DONE]
    Aaa.............................. [DONE]

Notice how "Bbb" is indented within the "Aaa" item, and that "Ccc" is
within the "Bbb" item.  Note too how the Bbb and Aaa items were
repeated because their initial lines were interrupted by more-inner
tasks.

You can control the indentation with the I<step> attribute, and you may
turn off or alter the repeated text (Bbb and Aaa) as you wish.

=head3 Filtering-out Deeper Levels (Verbosity)

Often a script will have a verbosity option (-v usually), that allows a
user to control how much output to see.  Octium::O::Crier handles this
with the I<maxdepth> attribute and C<set_maxdepth> method.

Suppose your script has the verbose option in $opts{verbose}, where 0
means no output, 1 means some output, 2 means more output, etc.  In
your script, do this:

    my $crier = Octium::O::Crier::->new(maxdepth => $opts[verbose});

or this:

    $crier->set_maxdepth ($opts{verbose});

Then output will be filtered from nothing to full-on based on the
verbosity setting.

=head3 ...But Show Severe Messages

If you're using maxdepth to filter messages, sometimes you still want
to see a message regardless of the depth filtering -- for example, a
severe error. To set this, use the override_severity option.  All
messages that have at least that severity value or higher will be
shown, regardless of the depth filtering.  Thus, a better filter would
look like:

    my $crier = Octium::O::Crier::->new(
        maxdepth          => $opts[verbose} ,
        override_severity => 7,
      );

See L</Completion Severity> above for the severity numbers.

=head2 Closing with Different Text

Suppose you want the opening and closing messages to be different. Such
as I<"Beginning task"> and I<"Ending task">.

To do this, use the I<closetext> attribute or C<set_closetext> method:

    $cry = $crier->cry(
         "Beginning task" ,
         {closetext => "Ending task"},
      );

Or:

    $cry->set_closetext("Ending task");

Or:

    $cry->done({closetext => "Ending task"});

Now, instead of the start message being repeated at the end, you get
custom end text.

A convienent shorthand notation for I<closetext> is to instead call
C<cry> with a pair of strings as an array reference, like this:

    my $cry=$crier->cry( ["Start text", "End text"] );

Using the array reference notation is easier, and it will override the
closetext option if you use both.  So don't use both.

=head2 Closing with Different Severities (Completion Upon Destruction)

So far our examples have been rather boring.  They're not vey
real-world. In a real script, you'll be doing various steps, checking
status as you go, and bailing out with an error status on each failed
check.  It's only when you get to the bottom of all the steps that you
know it's succeeded. Here's where completion upon destruction becomes
more useful:

    #!/usr/bin/env perl

    use warnings;
    use strict;

    use Octium::O::Crier;

    my $crier = Octium::O::Crier::->new({default_closestat => "ERROR");
    primary_task();

    sub primary_task {

       $cry_main = $crier->cry( "Primary task");
       return
           if !do_a_subtask();
       return
           if !do_another_subtask();
       $fail_reason = do_major_cleanup();
       return $cry_main->d_warn ({reason => $fail_reason})
            if $fail_reason;
       $cry_main->d_ok;

    }

(Note that "$crier" is set at file scope, which means it is available
to subroutines further in the same file.)

In this example, we set C<default_closestat> to "ERROR".  This means
that if any cry object is destroyed, presumably because the cry
variable went out of scope without doing a C<done> (or its
equivalents), a C<d_error> will automatically be called.

Next we do_a_subtask and do_another_subtask (whatever these are!). If
either fails, we simply return.  Automatically then, the C<d_error>
will be called to close out the context.

In the third step, we do_major_cleanup().  If that fails, we explicitly
close out with a warning (the C<d_warn>), and we pass some reason text.

If we get through all three steps, we close out with an OK.

=head2 Output to Other File Handles

By default, Octium::O::Crier writes its output to STDERR You can tell
it to use another file handle like this:

    open ($fh, '>', 'some_file.txt') or die;
    my $crier = Octium::O::Crier::->new({fh => $fh});

Alternatively, if you pass a scalar reference in the fh attribute, the
output will be appended to the string at the reference:

    my $output = "Cry output:\n";
    my $crier = Octium::O::Crier::->new({fh => \$output});

If there is only one argument to C<new>, it is taken as the "fh"
attribute:

    open ($fh, '>', 'some_file.txt') or die;
    my $crier = Octium::O::Crier::->new($fh);
    # same as ->new({ fh => $fh })

The output destination is determined at the creation of the crier
object, and cannot be changed.

=head2 Return Status

Methods that attempt to write to the output (including C<cry> and
C<done> and its equivalents) return a true value on success and false
on failure.  Failure can occur, for example, when attempting to write
to a closed filehandle.

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

Also, a bullet can be changed for a particular cry with the I<bullet>
attribute to C<cry> or the C<set_bullet> method on the cry object.

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

If not all bullets are the same width (according to the
Unicode::GCString module), the bullets will be made the same width by
adding spaces to the right.

=head2 Mixing Octium::O::Crier with other output

Internally, Octium::O::Crier keeps track of the output cursor position.
It only knows about what it has sent to the output destination. If you
mix C<print> or C<say> statements, or other output methods, with your
Octium::O::Crier output, then things will likely get screwy.  So,
you'll need to tell Octium::O::Crier where you've left the cursor.  Do
this by using  C<set_position>:

    $cry = $crier->cry("Doing something");
    print "\nHey, look at me, I'm printed output!\n";
    $cry->set_position(0);  # Tell where we left the cursor
    
(Using C<set_position> will skip the backspacing of the next C<over>.)

=head1 SUBROUTINES, METHODS, ATTRIBUTES REFERENCE

=head2 Subroutines

Three subroutines can be exported from Octium::O::Crier.

These subroutines are exported using C<Sub::Exporter>, so if you prefer
a different name for a subroutine,  you can specify that using an
I<-as> option in a hashref of options after the  subroutine name.

  use Octium::O::Crier (cry => { -as => 'bellow' } , 
                        default_crier => { -as => 'bellower'} ,
                        cry_text => { -as => {bellow_text} } );

will install the routines using the those names. See L<Sub::Exporter>
for more  detail on I<-as>.

Note that several of these routines are built during the import
process, so cannot be called using a fully-qualified package name. 
Octium::O::Crier::cry("some text") will not do what you want.  (It will
call the method C<cry>, not the subroutine C<cry>.)

=head3 B<default_crier>

Importing B<default_crier> does two things. First, it creates a
C<default_crier> subroutine in your package that returns the default
crier object, allowing it to be accessed directly. This allows most
attributes to be set (although not the filehandle).

 use Octium::O::Crier ( qw(default_crier) );
 $crier = default_crier();
 $crier->set_bullets( ' + ' );
 
If a hashref of options is present after default_crier in the import
list, during the import process, the default crier object will be
created with those options.   This is the only way to set the
filehandle of the default crier object.

Behind the scenes, it is passing these arguments to the C<<
Octium::O::Crier::->new >> class method, so the import routine accepts
all the same options as that class method.  For example:

 use Octium::O::Crier ( default_crier => { fh => \$myvar , backspace => 0 } );
 
The import routine for C<default_crier> will accept options  (other
than "-as") from only one caller.  If two callers attempt to set the
attributes of the object via the import routine, an exception will be
thrown.

=head3 B<cry>

The C<cry> subroutine will have the default crier object create a new
cry. It accepts all the same arguments as the object method C<<
$crier->cry() >>.

=head3 B<cry_text>

The C<cry_text> subroutine will have the most recent cry issue text
underneath it. It works the same as, and accepts all the same arguments
as, the object method C<< $cry->text() >>.

=head2 Class Method

=head3 Octium::O::Crier::->new()

This is the C<new> constructor inherited from Moose by
Octium::O::Crier. It creates a new Crier object: the object associated
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
C<Octium::O::Crier::Cry> object, and then that object outputs the
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

Since C<cry> creates a cry object, calling it in void context leaves
noplace to store it. If it is called in void context, the cry will
immediately close with "UNK" severity, and will display 'Cry error (cry
object not saved)'.

=head3 $crier->text()

This invokes the C<text> object method on the deepest open cry. If no
cry is open, opens a silent cry.

=head2 Cry Object Methods

=head3 $cry->done()

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

The first non-reference argument is taken to be the closing severity.
If none is provided, it will use the severity that is in the
I<closestat> attribute (whether specified in this call, or earlier as
an option in the constructor or via a method).

One attribute, I<reason>, is only applicable from within a C<done> call
(or its equivalents).

=head3 Convenience methods for "done"

These are called as C<< $cry->d_emerg() >>, C<< $cry->d_ok >>, etc.

For convenience, several methods exist to abbreviate the C<< $cry->done
>> method, for the built-in severities:

 d_emerg  done "EMERG";  syslog: Off the scale!
 d_panic  done "PANIC";  Time to panic
 d_havoc  done "HAVOC";  the dogs of war are let loose
 d_alert  done "ALERT";  syslog: A major subsystem is unusable.
 d_crit   done "CRIT";   syslog: a critical subsystem is not working entirely.
 d_darn   done "DARN";   Darn it, something happened
 d_fail   done "FAIL";   Failure
 d_fatal  done "FATAL";  Fatal error
 d_argh   done "ARGH";   Argh, something I didn't want to happen happened
 d_error  done "ERROR";  syslog 'err': Bugs, bad data, files not found, ...
 d_err    done "ERR";    syslog 'err': Bugs, bad data, files not found, ...
 d_oops   done "OOPS";   Oops, I did it again
 d_warn   done "WARN";   syslog 'warning'
 d_note   done "NOTE";   syslog 'notice'
 d_info   done "INFO";   syslog 'info'
 d_ok     done "OK";     copacetic
 d_debug  done "DEBUG";  syslog: Really boring diagnostic output.
 d_notry  done "NOTRY";  tried
 d_unk    done "UNK";    Unknown
 d_yes    done "YES";    Yes
 d_pass   done "PASS";   Passed a test
 d_no     done "NO";     No

=head3 $cry->d_none()

This is equivalent to C<done>, except that it does NOT output a wrapup
line or a completion severity.  It simply closes out the current level
with no message.

=head3 $cry->prog() and $cry->over()

Outputs a progress indication, such as a percent or M/N or whatever you
devise.  In fact, this simply puts *any* string on the same line as the
original message (for the current level).

Using C<over> will first backspace over a prior progress string (if
any) to clear it, then it will write the progress string. The prior
progress string could have been emitted by C<over> or C<prog>; it
doesn't matter.

The C<prog> method does not backspace, it simply puts the string out
there.

If the I<backspace> attribute is false, then C<over> behaves
identically to C<prog>. If the I<shows_progress> attribute is false,
does nothing.

For example,

  use Octium::O::Crier('cry');
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


=head3 C<$cry->text>

This outputs the given text without changing the current level. Use it
to give additional information, such as a blob of description. Lengthy
lines will be wrapped to fit nicely in the given width, using Unicode
definitions of column width (to allow for composed or double-wide
characters).

=head2 Attributes

There are several ways that attributes can be set: as the argument to
the B<new> class method, as methods on the crier object, as arguments
to the B<cry> object method, as methods on the cry object, or as
options to B<done> and its equivalents. Some are acceptable in all
those places!  Rather than list them separately for each type, all the
attributes are listed together here, with information as to how they
can be set and/or used.

=head3 adjust_level

=over

=item I<adjust_level> option to C<cry> or C<text>

=back

Supply an integer value.

This adjusts the indentation level of the message inwards (positive) or
outwards (negative).

This can be applied to a cry, in which case it applies to the cry and
any subsequent messages (C<prog>, C<over>, C<text>) associated with it,
or to just a C<text>, in which case it applies to just that text.

When it is applied to a cry, it affects filtering via the I<maxdepth>
attribute and the bullet character(s) if bullets are enabled.

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

=head3 bullet

=over

=item I<bullet> option to C<cry>, or C<done> or its equivalents

=item get method: C<< $cry->bullet() >>

=item set method: C<< $cry->set_bullet() >>

=back

Normally, the bullet for a cry is derived from the I<bullets> attribute
of the crier object. This attribute allows this to be overridden for
this particular cry.

The program makes all bullets take up the same width. When a custom
bullet is used, and that bullet is wider than earlier bullets, the
bullet width for the entire crier is made the width of the widest
bullet.

=head3 bullets

=over

=item I<bullets> option to C<new>

=item get method: C<< $crier->bullets() >>

=item set method: C<< $crier->set_bullets() >>

=back

Enables or disables the use of bullet characters in front of messages.
Set to a reference to n empty array to disable the use of bullets,
which is the default.  Set to a scalar character string to enable that
character(s) as the bullet.  Set to an array reference of strings to
use different characters for each nesting level.  See L</Message
Bullets>.

The program makes all bullets take up the same width. When bullets are
altered, the bullet width is made the width of the widest bullet ever
provided. The bullet width is never reduced.

=head3 closestat

=over

=item I<closestat> option to C<cry>, or C<done> or its equivalents

=item get method: C<< $cry->closestat() >>

=item set method: C<< $cry->set_closestat() >>

=back

Sets the severity code to use when completing a cry. This is set to the
value of the I<default_closestat> option if not specified in the C<cry>
or C<done> call.

See L</"Closing with Different Severities (Completion Upon
Destruction)">.

=head3 closetext

=over

=item I<closetext> option to C<cry>, or C<done> or its equivalents

=item get method: C<< $cry->closetext() >>

=item set method: C<< $cry->set_closetext() >>

=back

Supply a string to be used as the closing text that's paired with this
level.  Normally, the same text you use when you issue a C<cry> is the
text used to close it out.  This option lets you specify different
closing text.  See L</Closing with Different Text>.

=head3 colorize

=over

=item I<colorize> option to C<new>, C<cry>, or C<done> or equivalents

=item get methods: C<colorize> (on either $crier or $cry)

=item set methods: C<use_color> and C<no_color> (on either $crier or $cry)

=back

Set to a true value to render the completion severities in color. ANSI
escape sequences are used for the colors.  The default is to not use
colors.  See L</Severity Colors> above.

Setting the colorize attribute on a cry will affect only that cry.
Setting it in a C<done> call or equivalent, or using a C<use_color> or
C<no_color> on an already opened cry, will affect only the close of
that cry.

Setting the colorize attribute on a crier will affect all future cries.

=head3 column_width

=over

=item I<column_width> option to C<new>

=item get method: C<< $crier->column_width() >>

=item set method: C<< $crier->set_column_width() >>

=back

Sets the column width of your output.  C<Octium::O::Crier>> doesn't try
to determine how wide your terminal screen is, so use this option to
indicate the width.  The default is 80.

You may want to use L<Term::Size::Any|Term::Size::Any> to determine
your device's width:

    use Term::Size::Any 'chars';
    my ($cols, $rows) = chars();
    my $crier = Octium::O::Crier::->new({column_width => $cols});
    ...

One cool trick is to have it set when the program receives a window
change signal:

    my $crier = Octium::O::Crier::->new();
    use Term::Size::Any 'chars';
    local $SIG{WINCH} = \&set_width;
    sub set_width {
       my ($cols, $rows) = chars();
       $crier->set_column_width($cols);
    }

Assuming your system sends the proper signal, the width of the lines
will grow and shrink as the window changes size.

=head3 default_closestat

=over

=item I<default_closestat> option to C<new>

=item get method: C<< $crier->default_closestat() >>

=item set method: C<< $crier->set_default_closestat() >>

=back

Sets the severity code to use when completing a cry, if none is
specified in the C<cry> or any C<done> call. Useful when cries are
closed because the object gets destroyed.

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
Setting it in a C<done> call or equivalent, or using a C<set_ellipsis>
on an already opened cry, will affect only the close of that cry.

Setting the ellipsis attribute on a crier will affect all future cries.

=head3 fh

=over

=item I<fh> option to C<new>

=item get method: C<< $crier->fh() >>

=back

This attribute contains a reference to the file handle to which output
is sent. It cannot be changed once the crier object is created, so is
specified in the argument to C<new>.

=head3 maxdepth

=over

=item I<maxdepth> option to C<new>

=item get method: C<< $crier->maxdepth() >>

=item set method: C<< $crier->set_maxdepth() >>

=back

Filters messages by setting the maximum depth of messages that will be
output.  (This is how many levels of sub-task, not the severity level.)
Set to undef (the default) to see all messages.  Set to 0 to disable
B<all> messages from the crier.  Set to a positive integer to see only
messages at that depth and less.

=head3 muted

=over

=item I<muted> option to C<cry>, or C<done> or equivalents

=item get method: C<< $cry->muted >>

=item set methods: C<< $cry->mute >> and C<< $cry->unmute >>

=back

Set this option to a true value to have the cry close out silently.
This means that the severity code, the trailer (dot dots), and the
possible repeat of the message are turned off.

The return status from the call is will still be the appropriate value
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

See L<< /$crier->cry() >>.

=head3 override_severity

=over

=item I<override_severity> option to C<new>

=item get method: C<< $crier->override_severity() >>

=item set method: C<< $crier->override_severity() >>

=back

Specifies a severity number that will always be shown, even if it is so
deep that it would otherwise be filtered by the I<maxdepth> attribute.
So, for example, if I<override_severity> is 15, then "EMERG" and
"PANIC" messages will be printed, no matter what depth is used.

If I<override_severity> is negative, I<maxdepth> will always be
honored.

See L</...But Show Severe Messages>.

=head3 position

=over

=item get methods: C<position> (on either $crier or $cry)

=item set methods: C<set_position> (on either $crier or $cry)

=back

Used to reset what Octium::O::Crier thinks the cursor position is. You
may have to do this if you mix ordinary print statements with cries.

Set this to 0 to indicate that the position is at the start of a new
line (as in, just after a C<print "\n"> or C<say>). See L</Mixing
Octium::O::Crier with other output>.

After setting the position, C<over> will not backspace.

=head3 reason

=over

=item I<reason> option to C<done> or equivalents

=back

After the closing, it will output the given reason string on the
following line(s), indented underneath the completed message.  This is
useful to supply additional failure text to explain to a user why a
certain task failed.

This programming metaphor is commonly used:

    ...
    my $fail_reason = do_something_that_may_fail();
    return emit_fail {-reason => $fail_reason}
        if $fail_reason;
    ...

=head3 shows_progress

=over

=item I<shows_progress> option to C<new>

=item get method: C<< $crier->shows_progress() >>

=item set methods: C<< $crier->show_progress >> and C<< $crier->hide_progress >>

=back

This attribute determines whether C<< $cry->over >> and C<< $cry->prog
>>  display anything. If false, these don't do anything. This is useful
for turning these off via the command line, especially in circumstances
 where certain dumb IDE consoles can't backspace.

=head3 silent

=over

=item I<silent> option to C<cry>

=back

Set this option to a true value to have the cry both begin and close
out  silently. It will not display the opentext, and it will set the
I<muted>  option for this cry.

It might seem pointless, but since C<text> calls are only valid inside
a cry, a silent cry is the only way to allow for C<text> calls before
any cry is issued.

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


=head3 timestamp

=over

=item I<timestamp> option to C<new>, C<cry>, or C<done> or equivalents

=item get methods: C<timestamp> (on either $crier or $cry)

=item set methods: C<set_timestamp> (on either $crier or $cry)

=back

If false (the default), output lines are not prefixed with a timestamp.
 If true, the default local timestamp HH::MM::SS is prefixed to each
line.  If it's a coderef, then that function is called to get the
timestamp string.  The function is passed the current indent level, for
what it's worth.  Note that no delimiter is provided between the
timestamp string and the emitted line, so you should provide your own
(a space or colon or whatever).  Also, C<text> output is NOT
timestamped, just the opening and closing text.

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
    my $crier = Octium::O::Crier::->new({trailer =>'_'});
    $crier->cry("Doing something");

  The output:
    Doing something...______________________________ [DONE]

Note that the ellipsis after the message is still "..."; use
I<ellipsis> to change that string as well.

Setting the trailer attribute on a cry will affect only that cry.
Setting it in a C<done> call or equivalent, or using a C<set_trailer>
on an already opened cry, will affect only the close of that cry.

Setting the trailer attribute on a crier will affect all future cries.

=head1 DIAGNOSTICS

=head2 'Cry error (cry object not saved)'

The C<cry> method was called in void context. This creates an object
which should be saved to a variable. See L<< /$crier->cry() >>.

=head2 Arguments given in "use Octium::O::Crier (default_crier => {args})" but the default crier has already been initialized

A module attempted to set attributes to the default crier in the import
process, but the default crier can only be created once.  (You can use
methods to set all attributes to the default crier, with the exception
of the filehandle.)

=head1 DEPENDENCIES

At the moment, it relies on a number of Actium modules as well as core
modules in Perl 5.016. Other dependencies include:

=over

=item Moose

=item Sub::Exporter

=item Term::ANSIColor (required only if colorizing)

=item Unicode::LineBreak

=item Unicode::GCString

=back

=head1 NOTES

Octium::O::Crier is a fork of Term::Emit, by Steve Roscio. Term::Emit
is great, but it is dependent on Scope::Upper, which hasn't always
compiled cleanly in my installation, and also Term::Emit uses a number
of global variables, which save typing but mean that its objects aren't
self-contained. Octium::O::Crier is designed to do a lot of what
Term::Emit does, but in a somewhat cleaner way, even if it means
there's a bit more typing involved.

Octium::O::Crier does use Moose, which is somewhat odd for a
command-line program. Since many other Actium programs also use Moose,
this is a relatively small loss in this case. If this ever becomes a
separate distribution it should probably use something else, such as
Moo.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2015

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

