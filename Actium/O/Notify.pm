# Actium/O/Notify - Print with indentation, status, and closure
# Based on Term::Emit by Steve Roscio
#
#  Subversion: $Id$

package Actium::O::Notify 0.005;
use Actium::Moose;
use Scalar::Util(qw[openhandle weaken refaddr reftype]);

use Actium::Types (qw<ARNotifyBullets NotifyBullet NotifyTrailer>);
use Actium::Util ('u_columns');

use Actium::O::Notify::Notification;

const my $NOTIFICATION_CLASS => 'Actium::O::Notify::Notification';
const my $FALLBACK_CLOSESTAT => 'DONE';
const my $DEFAULT_TERM_WIDTH => 80;
const my $DEFAULT_STEP       => 2;

#####################################################################
## FILEHANDLE, AND OBJECT CONSTRUCTION SETTING FILEHANDLE SPECIALLY

has fh => (
    is       => 'ro',
    isa      => 'FileHandle',
    required => 1,
);

sub _fh_or_scalarref {
    my $class = shift;
    my $arg   = shift;

    return $arg if defined openhandle($arg);

    if ( reftype($arg) eq 'SCALAR' ) {
        open( my $fh, '>', \$_[0] );
        return $fh;
    }

    return;

}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

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
        my $handle = $class->_fh_or_scalarref->( $_[0] );
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
        if ( @_ == 1 and reftype( $_[0] ) eq 'HASH' ) {
            return $class->$orig( fh => $fh, %{ $_[0] } );
        }
        else {
            # ->new($fh, option => option1 ,...)
            return $class->$orig( fh => $fh, @_ );
        }
    }

    # ->new(option => option1 ,...)
    return $class->$orig( $firstarg, @_ );

};

######################
## WIDTH AND POSITION

has 'position' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has '_prog_cols' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);
# backs over this many columns during $notification->over
# this means will send two backspaces for each double-wide character
# This seems to be the right thing in Mac oS X Terminal; 
# not sure about other terminals

has 'term_width' => (
    is      => 'rw',
    isa     => 'Int',
    default => $DEFAULT_TERM_WIDTH,
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

has 'light_background' => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0,
    traits  => ['Bool'],
    handles => {
        set_light_background => 'set',
        set_dark_background => 'unset',
    },
);

has 'timestamp' => (
    is      => 'rw',
    isa     => 'Bool | CodeRef',
    default => 0,
);

has 'trailer' => (
    is      => 'rw',
    isa     => NotifyTrailer,
    default => '.',
);

#########################
## BULLETS, INDENTATION, LEVELS

has 'bullets_r' => (
    is       => 'bare',
    isa      => ARNotifyBullets,
    init_arg => 'bullets',
    reader   => '_bullets_r',
    writer   => '_set_bullets_r',
    #coerce   => 1,
    default  => sub { [] },
    traits   => ['Array'],
    handles  => {
        bullets      => 'elements',
        bullet_count => 'count',
        bullet       => 'get',
    },
    trigger => \&_build_bullet_width,
);

sub set_bullets {
    my $self    = shift;
    my @bullets = flatten(@_);
    $self->_set_bullets_r->( \@bullets );
}

sub _bullet_for_level {
    my $self  = shift;
    my $count = $self->bullet_count;

    return $EMPTY_STR unless $count;

    my $level = shift;
    $level = $count if $level > $count;

    return $self->bullet($level);

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

    my $width = max( map { u_columns($_) } @{$bullets_r} );
    return $width;
}

sub _alter_bullet_width {
    my $self            = shift;
    my $newbullet       = shift;
    my $newbullet_width = u_columns($newbullet);

    my $bullet_width = $self->bullet_width;

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
    is      => 'ro',
    isa     => 'Maybe[Int]',
    default => undef,
);

#########################
## SEVERITY

{

    # copied straight out of Term::Emit.
    # I don't know why the values are what they are
    const my %SEVERITY_NUM_OF => (
        EMERG => 15,
        ALERT => 13,
        CRIT  => 11,
        FAIL  => 11,
        FATAL => 11,
        ERR   => 9,
        ERROR => 9,
        WARN  => 7,
        NOTE  => 6,
        INFO  => 5,
        OK    => 5,
        DEBUG => 4,
        NOTRY => 3,
        UNK   => 2,
        OTHER => 1,
        YES   => 1,
        NO    => 0,
    );

    sub severity_num {
        my $self    = shift;
        my $sevtext = uc(shift);
        return $SEVERITY_NUM_OF{OTHER} unless exists $SEVERITY_NUM_OF{$sevtext};
        return $SEVERITY_NUM_OF{$sevtext};
    }
    
    sub minimum_severity {
        state $cached;
        $cached = min(values %SEVERITY_NUM_OF) unless defined $cached;
        return $cached;
    }
        
        
    sub maximum_severity {
        state $cached;
        $cached = max(values %SEVERITY_NUM_OF) unless defined $cached;
        return $cached;
    }

}

has 'override_severity' => (
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
### NOTIFICATIONS AND LEVELS

has '_notifications_r' => (
    is      => 'ro',
    isa     => "ArrayRef[$NOTIFICATION_CLASS]",
    traits => ['Array'],
    handles => {
        notifications      => 'elements',
        _pop_notification  => 'pop',
        notification_level => 'count',
    },
    default => sub { [] },
);

sub _push_notification {
    my $self         = shift;
    my $notification = shift;

    my $notifications_r = $self->_notifications_r;

    weaken($notification);
    push @{$notifications_r}, $notification;

}

sub notify {
    my $self = shift;

    my ( %opts, @args );

    foreach (@_) {
        if ( defined(reftype($_)) and reftype($_) eq 'HASH' ) {
            %opts = ( %opts, %{$_} );
        }
        else {
            push @args, $_;
        }
    }

    if ( @args == 1 and defined(reftype($args[0])) and reftype( $args[0] ) eq 'ARRAY' ) {
        my @pair = @{ +shift };
        $opts{opentext}  = $pair[0];
        $opts{closetext} = $pair[1];
    }
    else {
        my $separator = doe($OUTPUT_FIELD_SEPARATOR);
        $opts{opentext} = join( $separator, @args );
    }

    my $level = $self->notification_level + 1;

    unless ( defined $opts{opentext} ) {
        $opts{opentext} = ( caller(1) )[3];    # subroutine name;
        $opts{opentext} =~ s{\Amain::}{}sxm;
    }

    if ( defined $opts{bullet} ) {
        $self->_alter_bullet_width( $opts{bullet} );
    }
    else {
        $opts{bullet} = $self->_bullet_for_level($level);
    }

    my $notification = $NOTIFICATION_CLASS->new(
        %opts,
        notifier => $self,
        level      => $level,
    );

    my $success = $notification->_built_without_error;
    return $success unless $success;

    $self->_push_notification($notification);

    return $notification if defined wantarray;

    $notification->d_unk(
        { reason => 'Notification error (notification object not saved)' } )
      ;
    # void context - close immediately
    return; # only to make perlcritic happy

} 

sub _close_up_to {
    my $self         = shift;
    my $notification = shift;
    my @original_args = @_;
    
    my $this_notification = $self->_pop_notification;
    my $success;

    while ( $this_notification
        and ( refaddr($this_notification) != refaddr($notification) ) )
    {
        $success = $this_notification->_close; # default severity and options
        return $success unless $success;
        $this_notification = $self->_pop_notification;
    }

    return $notification->_close(@original_args);

}


1;

__END__

=head1 NAME

Term::Emit - Print with indentation, status, and closure

=head1 VERSION

This document describes Term::Emit version 0.0.4

=head1 SYNOPSIS

For a script like this:

    use Term::Emit qw/:all/;
    emit "System parameter updates";
      emit "CLOCK_UTC";
      #...do_something();
      emit_ok;

      emit "NTP Servers";
      #...do_something();
      emit_error;

      emit "DNS Servers";
      #...do_something();
      emit_warn;

You get this output:

   System parameter updates...
     CLOCK_UTC................................................. [OK]
     NTP Servers............................................... [ERROR]
     DNS Servers............................................... [WARN]
   System parameter updates.................................... [DONE]

=head1 DESCRIPTION

The C<Term::Emit> package is used to print balanced and nested messages
with a completion status.  These messages indent easily within each other,
autocomplete on scope exit, are easily parsed, may be bulleted, can be filtered,
and even can show status in color.

For example, you write code like this:

    use Term::Emit qw/:all/;
    emit "Reconfiguring the grappolator";
    do_whatchamacallit();
    do_something_else();

It begins by printing:

    Reconfiguring the grappolator...

Then it does "whatchamacallit" and "something else".  When these are complete
it adds the rest of the line: a bunch of dots and the [DONE].

    Reconfiguring the grappolator............................... [DONE]

Your do_whatchamacallit() and do_something_else() subroutines may also C<emit>
what they're doing, and indicate success or failure or whatever, so you
can get nice output like this:

    Reconfiguring the grappolator...
      Processing whatchamacallit................................ [WARN]
      Fibulating something else...
        Fibulation phase one.................................... [OK]
        Fibulation phase two.................................... [ERROR]
        Wrapup of fibulation.................................... [OK]
    Reconfiguring the grappolator............................... [DONE]


A series of examples will make I<Term::Emit> easier to understand.

=head2 Basics

    use Term::Emit ':all';
    emit "Frobnicating the biffolator";
    sleep 1; # simulate the frobnication process
    emit_done;

First this prints:

    Frobnicating the biffolator...

Then after the "frobnication" process is complete, the line is
continued so it looks like this:

    Frobnicating the biffolator................................ [DONE]

=head2 Autocompletion

In the above example, we end with a I<emit_done> call to indicate that
the thing we told about (I<Frobnicating the biffolator>) is now done.
We don't need to do the C<emit_done>.  It will be called automatically
for us when the current scope is exited (for this example: when the program ends).
So the code example could be just this:

    use Term::Emit ':all';
    emit "Frobnicating the biffolator";
    sleep 1; # simulate the frobnication process

and we'd get the same results.  

Yeah, autocompletion may not seem so useful YET,
but hang in there and you'll soon see how wonderful it is.

=head2 Completion Severity

There's many ways a task can complete.  It can be simply DONE, or it can
complete with an ERROR, or it can be OK, etc.  These completion codes are
called the I<severity code>s.  C<Term::Emit> defines many different severity codes.
The severity codes are borrowed from the UNIX syslog subsystem,
plus a few from VMS and other sources.  They should be familiar to you.

Severity codes also have an associated numerical value.
This value is called the I<severity level>.
It's useful for comparing severities to eachother or filtering out
severities you don't want to be bothered with.

Here are the severity codes and their severity values.
Those on the same line are considered equal in severity:

    EMERG => 15,
    ALERT => 13,
    CRIT  => 11, FAIL => 11, FATAL => 11,
    ERROR => 9,
    WARN  => 7,
    NOTE  => 6,
    INFO  => 5, OK => 5,
    DEBUG => 4,
    NOTRY => 3,
    UNK   => 2,
    YES   => 1,
    NO    => 0,

You may make up your own severities if what you want is not listed.
Please keep the length to 5 characters or less, otherwise the text may wrap.
Any severity not listed is given the value 1.

To complete with a different severity, call C<emit_done> with the
severity code like this:

    emit_done "WARN";

C<emit_done> returns with the severity value from the above table,
otherwise it returns 1, unless there's an error in which case it
returns false.

As a convienence, it's easier to use these functions which do the same thing,
only simpler:

     Function          Equivalent                       Usual Meaning
    ----------      -----------------      -----------------------------------------------------
    emit_emerg      emit_done "EMERG";     syslog: Off the scale!
    emit_alert      emit_done "ALERT";     syslog: A major subsystem is unusable.
    emit_crit       emit_done "CRIT";      syslog: a critical subsystem is not working entirely.
    emit_fail       emit_done "FAIL";      Failure
    emit_fatal      emit_done "FATAL";     Fatal error
    emit_error      emit_done "ERROR";     syslog 'err': Bugs, bad data, files not found, ...
    emit_warn       emit_done "WARN";      syslog 'warning'
    emit_note       emit_done "NOTE";      syslog 'notice'
    emit_info       emit_done "INFO";      syslog 'info'
    emit_ok         emit_done "OK";        copacetic
    emit_debug      emit_done "DEBUG";     syslog: Really boring diagnostic output.
    emit_notry      emit_done "NOTRY";     Untried
    emit_unk        emit_done "UNK";       Unknown
    emit_yes        emit_done "YES";       Yes
    emit_no         emit_done "NO";        No

We'll change our simple example to give a FATAL completion:

    use Term::Emit ':all';
    emit "Frobnicating the biffolator";
    sleep 1; # simulate the frobnication process
    emit_fatal;

Here's how it looks:

    Frobnicating the biffolator................................ [FATAL]

=head3 Severity Colors

A spiffy little feature of C<Term::Emit> is that you can enable colorization of the
severity codes.  That means that the severity code inside the square brackets
is printed in color, so it's easy to see.  The standard ANSI color escape sequences
are used to do the colorization.

Here's the colors:

    EMERG    bold red on black
    ALERT    bold magenta
    CRIT     bold red
    FAIL     bold red
    FATAL    bold red
    ERROR    red
    WARN     yellow (usually looks orange)
    NOTE     cyan
    INFO     green
    OK       bold green
    DEBUG    grey on yellow/orange
    NOTRY    black on grey
    UNK      bold white on grey
    DONE     default font color (unchanged)
    YES      green
    NO       red

To use colors, do this when you I<use> Term::Emit:

    use Term::Emit ":all", {-color => 1};
        -or-
    Term::Emit::setopts(-color => 1);

Run sample003.pl, included with this module, to see how it looks on
your terminal.

=head2 Nested Messages

Nested calls to C<emit> will automatically indent with eachother.
You do this:

    use Term::Emit ":all";
    emit "Aaa";
    emit "Bbb";
    emit "Ccc";

and you'll get output like this:

    Aaa...
      Bbb...
        Ccc.......................... [DONE]
      Bbb............................ [DONE]
    Aaa.............................. [DONE]

Notice how "Bbb" is indented within the "Aaa" item, and that "Ccc" is
within the "Bbb" item.  Note too how the Bbb and Aaa items were repeated
because their initial lines were interrupted by more-inner tasks.

You can control the indentation with the I<-step> attribute,
and you may turn off or alter the repeated text (Bbb and Aaa) as you wish.

=head3 Nesting Across Processes

If you write a Perl script that uses Term::Emit, and this script invokes other
scripts that also use Term::Emit, some nice magic happens.  The inner scripts become
aware of the outer, and they "nest" their indentation levels appropriately.
Pretty cool, eh?

=head3 Filtering-out Deeper Levels (Verbosity)

Often a script will have a verbosity option (-v usually), that allows
a user to control how much output to see.  Term::Emit makes this easy
with the -maxdepth option.

Suppose your script has the verbose option in $opts{verbose}, where 0 means
no output, 1 means some output, 2 means more output, etc.  In your script,
do this:

    Term::Emit::setopts(-maxdepth => $opts{verbose});

Then output will be filtered from nothing to full-on based on the verbosity setting.

=head4 ...But Show Severe Messages

If you're using -maxdepth to filter messages, sometimes you still want 
to see a message regardless of the depth filtering - for example, a severe error.
To set this, use the -showseverity option.  All messages that have
at least that severity value or higher will be shown, regardless of the depth 
filtering.  Thus, a better filter would look like:

    Term::Emit::setopts(-maxdepth     => $opts{verbose},
                        -showseverity => 7);

See L</Completion Severity> above for the severity numbers.
Note that the severity is rolled up to the deepest message filtered by
the -maxdepth setting; any -reason text is hooked to that level.

=head2 Closing with Different Text

Suppose you want the opening and closing messages to be different.
Such as I<"Starting gompchomper"> and I<"End of the gomp">.

To do this, use the C<-closetext> option, like this:

    emit {-closetext => "End of the gomp"}, "Starting gompchomper";

Now, instead of the start message being repeated at the end, you get
custom end text.

A convienent shorthand notation for I<-closetext> is to instead call
C<emit> with a pair of strings as an array reference, like this:

    emit ["Start text", "End text"];

Using the array reference notation is easier, and it will override
the -closetext option if you use both.  So don't use both.

=head3 Changing the 'close text' afterwards

*** TODO:  Provide an easy way to do this! ***

OK, you got me!  I didn't think of this case when I built this module.

It's not easy to do now, even with access to the base object.
For now, I recommend you use -reason and give extra reason text.
When I fix it, it'll probably take the form of setopts(-closetext => "blah")
and emit_done {-closetext=>"blah"};

=head2 Closing with Different Severities, or... Why Autocompletion is Nice

So far our examples have been rather boring.  They're not vey real-world.
In a real script, you'll be doing various steps, checking status as you go,
and bailing out with an error status on each failed check.  It's only when
you get to the bottom of all the steps that you know it's succeeded.
Here's where emit becomes more useful:

    use Term::Emit qw/:all/, {-closestat => "ERROR"};
    emit "Juxquolating the garfibnotor";
    return
        if !do_kibvoration();
    return
        if !do_rumbalation();
    $fail_reason = do_major_cleanup();
    return emit_warn {-reason => $fail_reason}
         if $fail_reason;
    emit_ok;

In this example, we set C<-closestat> to "ERROR".  This means that if we
exit scope without doing a emit_done() (or its equivalents), a emit_error()
will automatically be called.

Next we do_kibvoration and do_runbalation (whatever these are!).
If either fails, we simply return.  Automatically then, the emit_error()
will be called to close out the context.

In the third step, we do_major_cleanup().  If that fails, we explicitly
close out with a warning (the emit_warn), and we pass some reason text.

If we get thru all three steps, we close out with an OK.


=head2 Output to Other File Handles

By default, C<Term::Emit> writes its output to STDOUT (or whatever select()
is set to).  You can tell C<Term::Emit> to use another file handle like this:

    use Term::Emit qw/:all/, {-fh => *LOG};
        -or-
    Term::Emit::setopts(-fh => *LOG);

Individual "emit" lines may also take a file handle as the first
argument, in a manner similar to a print statement:

    emit *LOG, "this", " and ", "that";

Note the required comma after the C<*LOG> -- if it was a C<print> you
would omit the comma.

=head3 Output to Strings

If you give Term::Emit a scalar (string) reference instead of a file handle,
then Term::Emit's output will be appended to this string.

For example:

    my $out = "";
    use Term::Emit qw/:all/, {-fh => \$out};
        -or-
    Term::Emit::setopts(-fh => \$out);

Individual "emit" lines may also take a scalar reference as the first
argument:

    emit \$out, "this ", " and ", "that";

=head2 Output Independence

C<Term::Emit> separates output contexts by file handle.  That means the
indentation, autoclosure, bullet style, width, etc. for any output told
to STDERR is independent of output told to STDOUT, and independent
of output told to a string.  All output to a string is lumped together
into one context.

=head3 Return Status

Like C<print>, the C<emit> function returns a true value on success
and false on failure.  Failure can occur, for example, when attempting
to emit to a closed filehandle.

To get the return status, you must assign into a scalar context,
not a list context:

      my $stat;
      $stat = emit "Whatever";      # OK. This puts status into $stat
      ($stat) = emit "Whatever";    # NOT what it looks like!

In list context, the closure for C<emit> is bound to the list variable's
scope and autoclosure is disabled.  Probably not what you wanted.

=head2 Message Bullets

You may preceed each message with a bullet.
A bullet is usually a single character
such as a dash or an asterix, but may be multiple characters.
You probably want to include a space after each bullet, too.

You may have a different bullet for each nesting level.
Levels deeper than the number of defined bulelts will use the last bullet.

Define bullets by passing an array reference of the bullet strings
with C<-bullet>.  If you want the bullet to be the same for all levels,
just pass the string.  Here's some popular bullet definitions:

    -bullets => "* "
    -bullets => [" * ", " + ", " - ", "   "]

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

=head2 Mixing Term::Emit with print'ed Output

Internally, Term::Emit keeps track of the output cursor position.  It only
knows about what it has spewed to the screen (or logfile or string...).
If you intermix C<print> statements with your C<emit> output, then things
will likely get screwy.  So, you'll need to tell Term::Emit where you've
left the cursor.  Do this by setting the I<-pos> option:

    emit "Skrawning all xyzons";
    print "\nHey, look at me, I'm printed output!\n";
    Term::Emit::setopts (-pos => 0);  # Tell where we left the cursor


=head1 EXPORTS

Nothing is exported by default.  You'll want to do one of these:

    use Term::Emit qw/emit emit_done/;    # To get just these two functions
    use Term::Emit qw/:all/;              # To get all functions

Most of the time, you'll want the :all form.


=head1 SUBROUTINES/METHODS

Although an object-oriented interface exists for I<Term::Emit>, it is uncommon
to use it that way.  The recommended interface is to use the class methods
in a procedural fashion.
Use C<emit()> similar to how you would use C<print()>.

=head2 Methods

The following subsections list the methods available:

=head3 C<base>

Internal base object accessor.  Called with no arguments, it returns
the Term::Emit object associated with the default output filehandle.
When called with a filehandle, it returns the Term::Emit object associated
with that filehandle.

=head3 C<clone>

Clones the current I<Term::Emit> object and returns a new copy.
Any given attributes override the cloned object.
In most cases you will NOT need to clone I<Term::Emit> objects yourself.

=head3 C<new>

Constructor for a Term::Emit object.
In most cases you will B<NOT> need to create I<Term::Emit> objects yourself.

=head3 C<setopts>

Sets options on a Term::Emit object. For example to enable colored severities,
or to set the indentation step size.  Call it like this:

        Term::Emit::setopts(-fh    => *MYLOG,
                            -step  => 3,
                            -color => 1);

See L</Options>.

=head3 C<emit>

Use C<emit> to emit a message similar to how you would use C<print>.

Procedural call syntax:

    emit LIST
    emit *FH, LIST
    emit \$out, LIST
    emit {ATTRS}, LIST

Object-oriented call syntax:

    $tobj->emit (LIST)
    $tobj->emit (*FH, LIST)
    $tobj->emit (\$out, LIST)
    $tobj->emit ({ATTRS}, LIST)

=head3 C<emit_done>

Closes the current message level, re-printing the message
if necessary, printing dot-dot trailers to get proper alignment,
and the given completion severity.

=head3 C<emit_alert>

=head3 C<emit_crit>

=head3 C<emit_debug>

=head3 C<emit_emerg>

=head3 C<emit_error>

=head3 C<emit_fail>

=head3 C<emit_fatal>

=head3 C<emit_info>

=head3 C<emit_no>

=head3 C<emit_note>

=head3 C<emit_notry>

=head3 C<emit_ok>

=head3 C<emit_unk>

=head3 C<emit_warn>

=head3 C<emit_yes>

All these are convienence methods that call C<emit_done()>
with the indicated severity.  For example, C<emit_fail()> is
equivalent to C<emit_done "FAIL">.  See L</Completion Severity>.

=head3 C<emit_none>

This is equivalent to emit_done, except that it does NOT print
a wrapup line or a completion severity.  It simply closes out
the current level with no message.

=head3 C<emit_over>

=head3 C<emit_prog>

Emits a progress indication, such as a percent or M/N or whatever
you devise.  In fact, this simply puts *any* string on the same line
as the original message (for the current level).

Using C<emit_over> will first backspace over a prior progress string
(if any) to clear it, then it will write the progress string.
The prior progress string could have been emitted by emit_over
or emit_prog; it doesn't matter.

C<emit_prog> does not backspace, it simply puts the string out there.

For example,

  use Term::Emit qw/:all/;
  emit "Varigating the shaft";
  emit_prog '10%...';
  emit_prog '20%...';

gives this output:

  Varigating the shaft...10%...20%...

Keep your progress string small!  The string is treated as an indivisible
entity and won't be split.  If the progress string is too big to fit on the
line, a new line will be started with the appropriate indentation.

With creativity, there's lots of progress indicator styles you could
use.  Percents, countdowns, spinners, etc.
Look at sample005.pl included with this package.
Here's some styles to get you thinking:

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


=head3 C<emit_text>

This prints the given text without changing the current level.
Use it to give additional information, such as a blob of description.
Lengthy lines will be wrapped to fit nicely in the given width.

=head2 Options

The I<emit*> functions, the I<setopts()> function, and I<use Term::Emit> take the following
optional attributes.  Supply options and their values as a hash reference,
like this:

    use Term::Emit ':all', {-fh => \$out,
                            -step => 1,
                            -color => 1};
    emit {-fh => *LOG}, "This and that";
    emit {-color => 1}, "Severities in living color";

The leading dash on the option name is optional, but encouraged;
and the option name may be any letter case, but all lowercase is preferred.

=head3 -adjust_level

Only valid for C<emit> and C<emit_text>.  Supply an integer value.

This adjusts the indentation level of the message inwards (positive) or
outwards (negative) for just this message.  It does not affect filtering
via the I<maxdepth> attribute.  But it does affect the bullet character(s)
if bullets are enabled.

=head3 -bullets

Enables or disables the use of bullet characters in front of messages.
Set to a false value to disable the use of bullets - this is the default.
Set to a scalar character string to enable that character(s) as the bullet.
Set to an array reference of strings to use different characters for each
nesting level.  See L</Message Bullets>.

=head3 -closestat

Sets the severity code to use when autocompleting a message.
This is set to "DONE" by default.  See
L</Closing with Different Severities, or... Why Autocompletion is Nice> above.

=head3 -closetext

Valid only for C<emit>.

Supply a string to be used as the closing text that's paired
with this level.  Normally, the text you use when you emit() a message
is the text used to close it out.  This option lets you specify
different closing text.  See L</Closing with Different Text>.

=head3 -color

Set to a true value to render the completion severities in color.
ANSI escape sequences are used for the colors.  The default is
to not use colors.  See L</Severity Colors> above.

=head3 -ellipsis

Sets the string to use for the ellipsis at the end of a message.
The default is "..." (three periods).  Set it to a short string.
This option is often used in combination with I<-trailer>.

    Frobnicating the bellfrey...
                             ^^^_____ These dots are the ellipsis

=head3 -envbase

May only be set before making the first I<emit()> call.

Sets the base part of the environment variable used to maintain
level-context across process calls.  The default is "term_emit_".
See L</CONFIGURATION AND ENVIRONMENT>.

=head3 -fh

Designates the filehandle or scalar to receive output.  You may alter
the default output, or specify it on individual emit* calls.

    use Term::Emit ':all', {-fh => *STDERR};  # Change default output to STDERR
    emit "Now this goes to STDERR instead of STDOUT";
    emit {-fh => *STDOUT}, "This goes to STDOUT";
    emit {-fh => \$outstr}, "This goes to a string";

The emit* methods have a shorthand notation for the filehandle.
If the first argument is a filehandle or a scalar reference, it is
presumed to be the -fh attribute.  So the last two lines of the above
example could be written like this:

    emit *STDOUT, "This goes to STDOUT";
    emit \$outstr, "This goes to a string";

The default filehandle is whatever was C<select()>'ed, which
is typically STDOUT.

=head3 -maxdepth

Only valid with C<setopts()> and I<use Term::Emit>.

Filters messages by setting the maximum depth of messages tha will be printed.
Set to undef (the default) to see all messages.
Set to 0 to disable B<all> messages from Term::Emit.
Set to a positive integer to see only messages at that depth and less.

=head3 -pos

Used to reset what Term::Emit thinks the cursor position is.
You may have to do this is you mix ordinary print statements
with emit's.

Set this to 0 to indicate we're at the start of a new line
(as in, just after a print "\n").  See L</Mixing Term::Emit with print'ed Output>.

=head3 -reason

Only valid for emit_done (and its equivalents like emit_warn,
emit_error, etc.).

Causes emit_done() to emit the given reason string on the following line(s),
indented underneath the completed message.  This is useful to supply additional
failure text to explain to a user why a certain task failed.

This programming metaphor is commonly used:

    .
    .
    .
    my $fail_reason = do_something_that_may_fail();
    return emit_fail {-reason => $fail_reason}
        if $fail_reason;
    .
    .
    .

=head3 -silent

Only valid for emit(), emit_done(), and it's equivalents, like emit_ok, emit_warn, etc.

Set this option to a true value to make an emit_done() close out silently.
This means that the severity code, the trailer (dot dots), and
the possible repeat of the message are turned off.

The return status from the call is will still be the appropriate
value for the severity code.

=head3 -step

Sets the indentation step size (number of spaces) for nesting messages.
The default is 2.
Set to 0 to disable indentation - all messages will be left justified.
Set to a small positive integer to use that step size.

=head3 -timestamp

If false (the default), emitted lines are not prefixed with a timestamp.
If true, the default local timestamp HH::MM::SS is prefixed to each emit line.
If it's a coderef, then that function is called to get the timestamp string.
The function is passed the current indent level, for what it's worth.
Note that no delimiter is provided between the timestamp string and the 
emitted line, so you should provide your own (a space or colon or whatever).
Also, emit_text() output is NOT timestamped, just that from emit() and 
its closure.

=head3 -trailer

The B<single> character used to trail after a message up to the
completion severity.
The default is the dot (the period, ".").  Here's what messages
look like if you change it to an underscore:

  The code:
    use Term::Emit ':all', {-trailer => '_'};
    emit "Xerikineting";

  The output:
    Xerikineting...______________________________ [DONE]

Note that the ellipsis after the message is still "...";
use -ellipsis to change that string as well.

=head3 -want_level

Indicates the needed matching scope level for an autoclosure call
to emit_done().  This is really an internal option and you should
not use it.  If you do, I'll bet your output would get all screwy.
So don't use it.

=head3 -width

Sets the terminal width of your output device.  I<Term::Emit> has no
idea how wide your terminal screen is, so use this option to
indicate the width.  The default is 80.

You may want to use L<Term::Size::Any|Term::Size::Any>
to determine your device's width:

    use Term::Emit ':all';
    use Term::Size::Any 'chars';
    my ($cols, $rows) = chars();
    Term::Emit::setopts(-width => $cols);
      .
      .
      .

=head1 CONFIGURATION AND ENVIRONMENT

I<Term::Emit> requires no configuration files or environment variables.
However, it does set environment variables with this form of name:

    term_emit_fd#_th#

This envvar holds the current level of messages (represented
visually by indentation), so that indentation can be smoothly
maintained across process contexts.

In this envvar's name, fd# is the fileno() of the output file handle to which
the messages are written.  By default output is to STDERR,
which has a fileno of 2, so the envvar would be C<term_emit_fd2>.
If output is being written to a string (C<<-fh => \$some_string>>),
then fd# is the string "str", for example C<term_emit_fdstr>

When Term::Emit is used with threads, the thread ID is placed
in th# in the envvar.
Thus for thread #7, writing Term::Emit messages to STDERR, the envvar
would be C<term_emit_fd2_th7>.
For the main thread, th# and the leading underscore are omitted.

Under normal operation, this environment variable is deleted
before the program exits, so generally you won't see it.

Note: If your program's output seems excessively indented, it may be
that this envvar has been left over from some other aborted run.
Check for it and delete it if found.

=head1 DEPENDENCIES

This pure-Perl module depends upon Scope::Upper.

=head1 DIAGNOSTICS

None.

=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

Limitation:  Output in a threaded environment isn't always pretty.
It works OK and won't blow up, but indentation may get a bit screwy.
I'm workin' on it.

Bugs: No bugs have been reported.

Please report any bugs or feature requests to
C<bug-term-emit@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 SEE ALSO

To format C<Term::Emit> output to HTML, use
L<Term::Emit::Format::HTML|Term::Emit::Format::HTML> .

Other modules like C<Term::Emit> but not quite the same:

=over 4

=item *

L<Debug::Message|Debug::Message>

=item *

L<Log::Dispatch|Log::Dispatch>

=item *

L<PTools::Debug|PTools::Debug>

=item *

L<Term::Activity|Term::Activity>

=item *

L<Term::ProgressBar|Term::ProgressBar>

=back

=head1 AUTHOR

Steve Roscio  C<< <roscio@cpan.org> >>

=head1 ACKNOWLEDGEMENTS

Thanx to Paul Vencel for his review of this package, and to Jimmy Maguire
for his namespace advice.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009-2012, Steve Roscio C<< <roscio@cpan.org> >>.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

Because this software is licensed free of charge, there is no warranty
for the software, to the extent permitted by applicable law.  Except when
otherwise stated in writing the copyright holders and/or other parties
provide the software "as is" without warranty of any kind, either
expressed or implied, including, but not limited to, the implied
warranties of merchantability and fitness for a particular purpose.  The
entire risk as to the quality and performance of the software is with
you.  Should the software prove defective, you assume the cost of all
necessary servicing, repair, or correction.

In no event unless required by applicable law or agreed to in writing
will any copyright holder, or any other party who may modify and/or
redistribute the software as permitted by the above licence, be
liable to you for damages, including any general, special, incidental,
or consequential damages arising out of the use or inability to use
the software (including but not limited to loss of data or data being
rendered inaccurate or losses sustained by you or third parties or a
failure of the software to operate with any other software), even if
such holder or other party has been advised of the possibility of
such damages.

=for me to do:
    * Get this to work back at 5.006
    * Validate any given options
    * Fixup anonymous literals
    * Hmmm... how to setopts() the default -fh  vs. setopts() for a particular -fh?
    * Make a 'print' wrapper to keep track of position,
       and POD about interaction with print
       then a function to reset the internal position (or use a setopts() attr)
    * Make emit() use indirect object notation so it's a drop-in for print
        ** But do we want the overhead of IO::Handle?
    * Timestamps - maybe do in another module?
        Allow timestamps in something akin to sprintf format within the strings.
        IE, solve this problem:
            emit ["Starting Frobnication process at %T",
                  "Frobnication process complete at %T"];
    * emit_more : another emit at the same level as the prior?
       for example:
           emit "yomama";
           emit_more "yopapa";  # does not start a new context, like emit_text
             but at upper level (or call it "yell"?)
    * Thread support
    * Add a "Closing Silently" section up around the closing w/diff text section.
    * Read envvars for secondary defaults, so qx() wrapping looks consistent.
    * Envvars for color, width, maxdepth, etc...
       ** export the envvars (in setopts()) so wrapped scripts pick 'em up
       ** clean up the envvars, iff we set 'em
       ** make 'em work by fd# as well, not just default.  IE, have
            term_emit_color apply to the default fd, but
            term_emit_fd2_color applies to stdout.  And so on.
