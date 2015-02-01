# Actium/O/Crier - Print with indentation, status, and closure
# Based on Term::Emit by Steve Roscio
#
#  Subversion: $Id$

package Actium::O::Crier 0.009;
use Actium::Moose;
use Scalar::Util(qw[openhandle weaken refaddr reftype]);

use Actium::Types (qw<ARCrierBullets CrierBullet CrierTrailer>);
use Actium::Util ('u_columns');

use Actium::O::Crier::Cry;

const my $CRY_CLASS => 'Actium::O::Crier::Cry';
const my $FALLBACK_CLOSESTAT => 'DONE';
const my $DEFAULT_TERM_WIDTH => 80;
const my $DEFAULT_STEP       => 2;

#########################################################
### EXPORTS

use Sub::Exporter -setup => {
  exports => [ cry => \'_build_cry' 
           , 'default_crier'  
]};

my $default_crier;

sub _build_cry {
   my ($class, $name, $arg) = @_;

   if (defined $arg and scalar keys %$arg) {
      if ($default_crier) { 
         croak 
          qq[Arguments given in "use Actium::O::Crier (cry => {args})"] 
          . qq[but the default crier has already been initialized];
     
         } 

         $default_crier = __PACKAGE__->new($arg);
         return sub {
              return $default_crier->cry(@_);
         };
   }

   return sub {
      $default_crier = __PACKAGE__->new()
          if not $default_crier;
      return $default_crier->cry(@_);
   }

}

sub default_crier {
   $default_crier = __PACKAGE__->new()
       if not $default_crier;
   return $default_crier;
}

#####################################################################
## FILEHANDLE, AND OBJECT CONSTRUCTION SETTING FILEHANDLE SPECIALLY

has fh => (
    is       => 'ro',
    isa      => 'FileHandle',
    default => sub {*STDERR{IO}},
);

sub _fh_or_scalarref {
    my $class = shift;
    my $arg   = shift;

    return $arg if defined openhandle($arg);

    if ( defined reftype($arg) and reftype($arg) eq 'SCALAR' ) {
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
# backs over this many columns during $cry->over
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
    trigger => \&_build_bullet_width,
);

sub set_bullets {
    my $self    = shift;
    my @bullets = flatten(@_);
    $self->_set_bullets_r( @bullets );
}

sub _bullet_for_level {
    my $self  = shift;
    my $count = $self->bullet_count;

    return $EMPTY_STR unless $count;

    my $level = shift;
    $level = $count if $level > $count;

    return $self->bullet($level - 1);
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
        #state $cached;
        #$cached = min(values %SEVERITY_NUM_OF) unless defined $cached;
        state $cached = min(values %SEVERITY_NUM_OF);
        return $cached;
    }
        
        
    sub maximum_severity {
        #state $cached;
        #$cached = max(values %SEVERITY_NUM_OF) unless defined $cached;
        state $cached = max(values %SEVERITY_NUM_OF);
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
### CRIES AND LEVELS

has '_cries_r' => (
    is      => 'ro',
    isa     => "ArrayRef[$CRY_CLASS]",
    traits => ['Array'],
    handles => {
        cries      => 'elements',
        _pop_cry  => 'pop',
        cry_level => 'count',
        _first_cry => [ get => 0 ],
    },
    default => sub { [] },
);

sub _push_cry {
    my $self         = shift;
    my $cry = shift;

    my $cries_r = $self->_cries_r;

    push @{$cries_r}, $cry;
    weaken ${$cries_r}[-1];

}

sub cry {
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

    my $level = $self->cry_level + 1;

    unless ( defined $opts{opentext} and $opts{opentext}) {
        my $msg;
        (undef, undef, undef, $msg ) = caller(1);
        $opts{opentext} = $msg;
        $opts{opentext} =~ s{\Amain::}{}sxm;
    }

    if ( defined $opts{bullet} ) {
        $self->_alter_bullet_width( $opts{bullet} );
    }
    else {
        $opts{bullet} = $self->_bullet_for_level($level);
    }

    my $cry = $CRY_CLASS->new(
        %opts,
        crier => $self,
        level      => $level,
    );

    my $success = $cry->_built_without_error;
    return $success unless $success;

    $self->_push_cry($cry);

    return $cry if defined wantarray;

    $cry->d_unk(
        { reason => 'Cry error (cry object not saved)' } )
      ;
    # void context - close immediately
    return; # only to make perlcritic happy

} 

sub _close_up_to {
    my $self         = shift;
    my $cry = shift;
    my @original_args = @_;
    
    my $this_cry = $self->_pop_cry;
    my $success;

    while ( $this_cry
        and ( refaddr($this_cry) != refaddr($cry) ) )
    {
        $success = $this_cry->_close; # default severity and options
        return $success unless $success;
        $this_cry = $self->_pop_cry;
    }

    return $cry->_close(@original_args);

}

sub DEMOLISH {
    my $self = shift;
    
    my @cries = $self->cries;
    if (@cries) {
        $self->_close_up_to($cries[0]);
    }
    
    return;
    
}


1;

__END__

=encoding utf8

=head1 NAME

Actium::O::Crier - Terminal notification with indentation, status, and closure

=head1 VERSION

This documentation refers to version 0.009

=head1 SYNOPSIS

 use Actium::O::Crier;
 
 my $crier = Actium::O::Crier::->new();
 
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

 use Actium::O::Crier(cry);

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

Actium::O::Crier is used to to print balanced and nested messages
with a completion status.  These messages indent easily within each other,
are easily parsed, may be bulleted, can be filtered,
and even can show status in color.

For example, you write code like this:

    use Actium::O::Crier;
    my $crier = Actium::O::Crier::->new()
    my $cry = $crier->cry("Performing the task");
    first_subtask($crier);
    second_subtask($crier);
    $cry->done;
    
It begins by printing:

    Performing the task...

Then it does the first subtask and the second subtask. When these are complete,
it adds the rest of the line: a bunch of dots and the [DONE].

    Performing the task......................................... [DONE]
    
Your subroutines first_subtask() and second_subtasks() subroutines may also 
issue a cry about
what they're doing, and indicate success or failure or whatever, so you
can get nice output like this:

    Performing the task...
      Performing a subtask ..................................... [WARN]
      A second subtask...
        Second subtask, phase one............................... [OK]
        Second subtask, phase two............................... [ERROR]
      Wrapup of second subtask.................................. [OK]
    Performing the task......................................... [DONE]

A series of examples will make Actium::O::Crier easier to understand.

=head2 Basics

Here is a basic example of usage:

    use Actium::O::Crier;
    my $crier = Actium::O::Crier::->new();
    my $cry = $crier->cry("Performing a task");
    sleep 1; # simulate task performance
    $cry->done;

First this prints:

    Performing a task...

Then after the task process is complete, the line is
continued so it looks like this:

    Performing a task........................................... [DONE]
    
Actium::O::Crier works by creating two sets of objects. 
The I<crier> represents
the destination of the cries, such as the terminal, or an output file.
The I<cry> object represents a single cry, such as a cry about
one particular task or subtask.  Methods on these objects are used to issue
cries and complete them.

The crier object is created by the C<new> class method of C<Actium::O::Crier>.
The cry object is created by the C<<cry>> object method of the crier object.

=head2 Exported subroutines: shortcut to a default output destination

Since most output from Actium::O::Crier is to a single default
output destination for that process (typically STDERR), some
procedural shortcuts exist to make it easier to send cries to a
default output.

The C<cry> routine 
establishes the default cry object, and calls the ->cry
method on that object with your arguments.

To use the shortcut, specify it in the import list in the C<use
Actium::O::Crier> call.  
C<< "use Actium::O::Crier ( qw(cry))" >> 
will establish a crier object with STDERR as the output,
and install a sub called C<cry> in your package that will create
the cry object. Therefore,

 use Actium::O::Crier ( qw(cry) );
 my $cry = cry ("Doing a task");

works basically the same as

 use Actium::O::Crier;
 my $crier = Actium::O::Crier::->new();
 my $cry = $crier->cry ("Doing a task");

except that in the former case, the crier object is stored in
the Actium::O::Crier class and will be reused by other calls to
C<cry>, from this module or any other. 
This avoids the need to pass the crier object as an
argument to routines in other modules.
 
=head2 Completion upon destruction

In the above example, we end with a I<< ->done > call to indicate that
the thing we told about (I<Performing a task>) is now done.
We don't need to do the C<< ->done >.  It will be called automatically
for us when the cry object (in this example, held in the variable 
C<$cry>) is destroyed, such as when the variable goes out of scope 
(for this example: when the program ends).
So the code example could be just this:

    use Actium::O::Crier;
    my $crier = Actium::O::Crier::->new();
    my $cry = $crier->cry("Performing a task");
    sleep 1; # simulate task performance

and we'd get the same results (assuming the program ends there).  

Completion upon destruction is useful especially in circumstances where the
program exits less than cleanly, but also simply when it is convenient to avoid
additional method calls at the end of a function.

=head2 Completion Severity

There's many ways a task can complete.  It can be simply DONE, or it can
complete with an ERROR, or it can be OK, etc.  These completion codes are
called the I<severity code>s.  C<Actium::O::Crier> defines many different 
severity codes.

Severity codes also have an associated numerical value.
This value is called the I<severity number>.
It's useful for comparing severities to each other or filtering out
severities you don't want to be bothered with.

Here are the severity codes and their severity numbers.
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

To complete with a different severity, call C<< ->done >> with the
severity code like this:

    $crier->done("WARN");

C<done> and its equivalents return with the severity number from the above 
table, otherwise it returns 1, unless there's an error in which case it
returns false.

As a convienence, it's easier to use these methods which do the same thing,
only simpler:

 Method   Equivalent     Usual Meaning
 -------  -------------  -----------------------------------------------------
 d_emerg  done "EMERG";  syslog: Off the scale!
 d_alert  done "ALERT";  syslog: A major subsystem is unusable.
 d_crit   done "CRIT";   syslog: a critical subsystem is not working entirely.
 d_fail   done "FAIL";   Failure
 d_fatal  done "FATAL";  Fatal error
 d_error  done "ERROR";  syslog 'err': Bugs, bad data, files not found, ...
 d_warn   done "WARN";   syslog 'warning'
 d_note   done "NOTE";   syslog 'notice'
 d_info   done "INFO";   syslog 'info'
 d_ok     done "OK";     copacetic
 d_debug  done "DEBUG";  syslog: Really boring diagnostic output.
 d_notry  done "NOTRY";  tried
 d_unk    done "UNK";    Unknown
 d_yes    done "YES";    Yes
 d_no     done "NO";     No

We'll change our simple example to give a FATAL completion:

    use Actium::O::Crier;
    my $crier = Actium::O::Crier::->new();
    my $cry = $crier->cry("Performing a task");
    sleep 1; # simulate task performance
    $cry->d_fatal;

Here's how it looks:

    Performing a task........................................... [FATAL]

=head3 Severity Colors

One feature of C<Actium::O::Crier> is that you can enable colorization of the
severity codes.  That means that the severity code inside the square brackets
is printed in color, so it's easy to see.  
The module Term::ANSIColor is used to do the colorization.

Here's the colors:

        EMERG    bold blink bright white on red
        ALERT    bold blink bright yellow on red
        CRIT     bold bright white on red
        FAIL     bold bright white on red
        FATAL    bold bright white on red
        ERR      bold bright yellow on red
        ERROR    bold bright yellow on red
        WARN     bold black on bright yellow
        NOTE     bold bright white on blue
        INFO     green
        OK       green
        DEBUG    bright white on bright black
        NOTRY    bold bright white on magenta
        UNK      bold bright yellow on magenta
        YES      green
        NO       bright red
        
("Bold black" is ANSI for gray.)

To use colors on all cries, pass 'colorize => 1' as an argument 
to the C<< ->new >> call:

    my $crier = Actium::O::Crier::->new({colorize => 1});

Or, invoke the set_color method on the crier, once it's created:

    $crier->set_color;
    
Cries also accept the colorize argument or the set_color method,
so that individual cries can be colorized or not.

Run sample003.pl, included with this module, to see how the colors look on
your terminal.

=head2 Nested Messages

Nested cries will automatically indent with each other.
You do this:

    use Actium::O::Crier;
    my $crier = Actium::O::Crier::->new();
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
within the "Bbb" item.  Note too how the Bbb and Aaa items were repeated
because their initial lines were interrupted by more-inner tasks.

You can control the indentation with the I<step> attribute,
and you may turn off or alter the repeated text (Bbb and Aaa) as you wish.

=head3 Filtering-out Deeper Levels (Verbosity)

Often a script will have a verbosity option (-v usually), that allows
a user to control how much output to see.  Actium::O::Crier handles this
with the I<maxdepth> attribute and C<set_maxdepth> method.

Suppose your script has the verbose option in $opts{verbose}, where 0 means
no output, 1 means some output, 2 means more output, etc.  In your script,
do this:

    my $crier = Actium::O::Crier::->new(maxdepth => $opts[verbose});

or this:

    $crier->set_maxdepth ($opts{verbose});

Then output will be filtered from nothing to full-on based on 
the verbosity setting.

=head3 ...But Show Severe Messages

If you're using maxdepth to filter messages, sometimes you still want 
to see a message regardless of the depth 
filtering -- for example, a severe error.
To set this, use the override_severity option.  All messages that have
at least that severity value or higher will be shown, regardless of the depth 
filtering.  Thus, a better filter would look like:

    my $crier = Actium::O::Crier::->new(
        maxdepth          => $opts[verbose} ,
        override_severity => 7,
      );

See L</Completion Severity> above for the severity numbers.

=head2 Closing with Different Text

Suppose you want the opening and closing messages to be different.
Such as I<"Beginning task"> and I<"Ending task">.

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

Using the array reference notation is easier, and it will override
the closetext option if you use both.  So don't use both.

=head2 Closing with Different Severities (Completion Upon Destruction)

So far our examples have been rather boring.  They're not vey real-world.
In a real script, you'll be doing various steps, checking status as you go,
and bailing out with an error status on each failed check.  It's only when
you get to the bottom of all the steps that you know it's succeeded.
Here's where completion upon destruction becomes more useful:

    #!/usr/bin/env perl

    use warnings; 
    use strict;

    use Actium::O::Crier;
    
    my $crier = Actium::O::Crier::->new({default_closestat => "ERROR");
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
    
(Note that "$crier" is set at file scope, which means it is available to
subroutines further in the same file.)

In this example, we set C<default_closestat> to "ERROR".  This means that if any
cry object is destroyed, presumably because the cry variable
went out of scope without doing a C<< ->done >> (or its equivalents), 
a C << ->d_error >> will automatically be called.

Next we do_a_subtask and do_another_subtask (whatever these are!).
If either fails, we simply return.  Automatically then, the C<< ->d_error >>
will be called to close out the context.

In the third step, we do_major_cleanup().  If that fails, we explicitly
close out with a warning (the C<< ->d_warn >>), and we pass some reason text.

If we get through all three steps, we close out with an OK.

=head2 Output to Other File Handles

By default, Actium::O::Crier writes its output to STDERR 
You can tell it to use another file handle like this:

    open ($fh, '>', 'some_file.txt') or die;
    my $crier = Actium::O::Crier::->new({fh => $fh});
    
Alternatively, if you pass a scalar reference in the fh attribute, 
the output will be appended to the string at the reference:

    my $output = "Cry output:\n";
    my $crier = Actium::O::Crier::->new({fh => \$output});
    
If there is only one argument to new(), it is taken as the "fh" attribute:

    open ($fh, '>', 'some_file.txt') or die;
    my $crier = Actium::O::Crier::->new($fh);
    # same as ->new({ fh => $fh })
    
The output destination is determined at the creation of the crier object, 
and cannot be changed.

=head2 Return Status

Methods that attempt to write to the output (including C<< ->cry >> and
C<< ->done >> and its equivalents) return
a true value on success and false on failure.  Failure can occur, 
for example, when attempting to write to a closed filehandle.

=head2 Message Bullets

You may preceed each message with a bullet.
A bullet is usually a single character
such as a dash or an asterisk, but may be multiple characters.
You probably want to include a space after each bullet, too.

You may have a different bullet for each nesting level.
Levels deeper than the number of defined bullets will use the last bullet.

Bullets can be set by passing an array reference of the bullet strings
as the I<bullets> attribute, or to the C<set_bullets> method, to the crier.

If you want the bullet to be the same for all levels,
just pass the string.  Here's some popular bullet definitions:

If you want the bullet to be the same for all levels,
just pass the string.  Here's some popular bullet definitions:

    bullets => "* "
    bullets => [" * ", " + ", " - ", "   "]
    
Also, a bullet can be changed for a particular cry with the 
I<bullet> attribute to C<< ->cry >> or the C<< ->set_bullet >> method 
on the cry object.

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

=head2 Mixing Actium::O::Crier with other output

Internally, Actium::O::Crier keeps track of the output cursor position.  
It only
knows about what it has sent to the output destination. 
If you mix C<print> or C<say> statements, or other output methods, with your 
Actium::O::Crier output, then things
will likely get screwy.  So, you'll need to tell Actium::O::Crier where you've
left the cursor.  Do this by setting the I<-pos> option:

    $cry = $crier->cry("Doing something");
    print "\nHey, look at me, I'm printed output!\n";
    $cry->set_position(0);  # Tell where we left the cursor

=head1 SUBROUTINES

Two subroutines can be exported from Actium::O::Crier.

=over 

=item B<cry>

The cry subroutine is a shortcut to allow a default output crier
object to be easily accessed. See 
L</Exported subroutines: shortcut to a default output destination> above.

Install it using C<use>:

 use Actium::O::Crier (qw(cry));

To specify a different filehandle, or any other argument, provide
them as a hashref of arguments in the C<use> call:

 use Actium::O::Crier ( cry => { fh => *STDOUT{IO} , bullets => ' * ' );

Behind the scenes, it is passing these arguments to the 
C<< Actium::O::Crier::->new >> class method, 
so the import routine accepts all the same arguments as that
class method.  In addition, the
"-as" argument can be used to give the installed subroutine another name:

 use Actium::O::Crier ( cry => { -as => 'bawl' } );

This will install the routine into the caller's namespace as C<bawl>.

The import routine for C<cry> will accept arguments from only
one caller.  If two callers attempt to set the attributes of the
object via the import routine, an exception will be thrown.

=item B<default_crier>

The B<default_crier> subroutine returns the default crier
object, allowing it to be accessed directly. This allows most
attributes to be set (although not the filehandle).

 use Actium::O::Crier ( qw(cry default_crier) );
 $crier = default_crier();
 $crier->bullets( ' + ' );

=head1 CLASS METHOD

=over

=item B<< Actium::O::Crier::->new(...) >>

This is the C<new> constructor inherited from Moose by Actium::O::Crier. 
It creates a new Crier object: the object associated
with a particular output.  

It accepts various attributes, which are listed below along with the methods
that access them.  Attributes can be specified as hash or hash reference.
However, if the first argument is a file handle or reference to a scalar,
that will be taken as the output destination for this crier.
If no arguments are passed, it will use STDERR as the output.

=back

=head1 Attributes, Object Methods, Options

There are several ways that attributes can be set: as the argument to the 
B<new> class method, as methods on the crier object, as arguments to 
the B<cry> object method, as methods on the cry object, or
as options to B<done> and its equivalents. Some are acceptable
in all those places!  Rather than list them separately for each type, 
all the attributes, methods and options are listed together here, with 
information as to where it can be used.

=over

=item B<fh> 

=over 

=item Argument to C<new>

=item Object method to the crier and cry objects

=back

This attribute contains a reference to the file handle to 
which output is sent. It cannot be changed once the crier object
is created.

=item 

          fh
          minimum_severity maximum_severity severity_num
          step             maxdepth         override_severity
          term_width       position         set_position
          _prog_cols      _set_prog_cols
          _bullet_width    _alter_bullet_width
          _close_up_to
          backspace

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 PROGRAM NOTES

Actium::O::Crier is basically a rewrite of Term::Emit, by Steve Roscio. 
Term::Emit is great, but it is dependent on Scope::Upper, which hasn't always
compiled cleanly in my installation, and also Term::Emit uses a number of
global variables, which save typing but mean that its objects aren't 
self-contained. Actium::O::Crier is designed to do a lot of what 
Term::Emit does, but in a somewhat cleaner way, even if it means there's a bit
more typing involved.

Actium::O::Crier does use Moose, which probably would seem odd for a
command-line program. Since many other Actium programs also use Moose,
this is a relatively small loss in this case. If this ever becomes 
a standalone module it should probably use something else.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2015

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.













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
