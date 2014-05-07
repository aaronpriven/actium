# Actium/O/Notify/Notification -
# One output from Actium::O::Notify::Notification
#
# Based on Term::Emit by Steve Roscio
#
#  Subversion: $Id$

package Actium::O::Notify::Notification 0.005;

use Actium::Moose;
use Unicode::LineBreak;

###############################
## Attributes set via constructor

has 'notifier' => (
    isa     => 'Actium::O::Notify',
    is      => 'bare',
    weakref => 1,
    handles => [
        qw[
          fh
          minimum_severity maximum_severity severity_num
          step             maxdepth         override_severity
          term_width       position         set_position
          _progwid         _set_progwid
          _bullet_width    _alter_bullet_width
          _close_up_to
          uwidth
          ]
    ]
);

has 'opentext' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'level' => (
    isa      => 'Int',
    is       => 'ro',
    required => 1,
);

##########################
### Attributes set in constructor, but with special features

has 'adjust_level' => (
    isa     => 'Int',
    is      => 'ro',
    default => 0,
);

has 'closetext' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_closetext',
);

sub _build_closetext {
    my $self = shift;
    return $self->opentext;
}

has 'bullet' => (
    isa     => 'Str',
    default => $EMPTY_STR,
    is      => 'ro',
    writer  => '_set_bullet',
);

sub set_bullet {
    my $self   = shift;
    my $bullet = shift;

    $self->_alter_bullet_width($bullet);
    $self->_set_bullet($bullet);
    return;
}

#############################
## These attributes are copies of those in the notifier, but can
## be overridden in cosntructor

has 'closestat' => (
    is      => 'rw',
    isa     => 'Str',
    builder => '_reset_closestat',
);

sub _reset_closestat {
    my $self = shift;
    return $self->notifier->default_closestat;
}

has 'timestamp' => (
    is      => 'rw',
    isa     => 'Bool | CodeRef',
    builder => '_reset_timestamp',
);

sub _reset_timestamp {
    my $self = shift;
    return $self->notifier->timestamp;
}

has 'ellipsis' => (
    is      => 'rw',
    isa     => 'Str',
    builder => '_reset_ellipsis',
);

sub _reset_ellipsis {
    my $self = shift;
    return $self->notifier->ellipsis;
}

has 'trailer' => (
    is      => 'rw',
    isa     => 'Str',
    builder => '_reset_trailer',
);

sub _reset_trailer {
    my $self = shift;
    return $self->notifier->trailer;
}

has 'colorize' => (
    isa     => 'Bool',
    is      => 'ro',
    builder => '_reset_colorize',
    traits  => ['Bool'],
    handles => {
        use_color => 'set',
        no_color  => 'unset',
    },
);

sub _reset_colorize {
    my $self = shift;
    return $self->notifier->colorize;
}

##########################
### state

has '_is_opened' => (
    isa      => 'Bool',
    init_arg => undef,
    is       => 'ro',
    default  => 0,
    traits   => ['Bool'],
    handles  => {
        _mark_opened => 'set',
        _not_opened  => 'not',
    },
);

has '_is_closed' => (
    is       => 'ro',
    isa      => 'Bool',
    default  => '0',
    init_arg => undef,
    traits   => ['Bool'],
    handles  => { _mark_closed => 'set', },
);

has '_built_without_error' => (
    is       => 'ro',
    isa      => 'Bool',
    default  => '0',
    init_arg => undef,
    traits   => ['Bool'],
    handles  => { _mark_built_without_error => 'set', },
);

# can't return from BUILD to the caller, because the caller is
# expecting the object. So uses that flag in lieu of returning
# a non-object

###########################
### open

const my $NOTIFY_RIGHT_PAD => 10;
const my $MIN_SPAN_FACTOR  => 2 / 3;

sub _open {

    my $self = shift;

    my $level = shift // $self->level + $self->adjust_level;

    my $fh  = $self->fh;
    my $pos = $self->position;

    # start back at the left
    if ($pos) {
        my $succeeded = print $fh "\n";
        return unless $succeeded;
    }

    my $succeeded = _print_left_text( $self->opentext );
    return unless $succeeded;

    $self->_mark_opened;

    return $self;

} ## tidy end: sub _open

sub BUILD {
    my $self = shift;

    my $level    = $self->level + $self->adjust_level;
    my $maxdepth = $self->maxdepth;

    if ( defined $maxdepth and $level <= $maxdepth ) {
        my $success = $self->_open($level);
        $self->_mark_built_without_error if $success;
    }
    else {
        $self->_mark_built_without_error;
    }

    return;

}

sub _print_left_text {
    my $self  = shift;
    my $fh    = $self->fh;
    my $text  = shift;
    my $level = shift;

    # Timestamp
    my $timestamp = $self->_timestamp_now;

    my $bullet = $self->_spaced( $self->bullet, $self->_bullet_width );
    my $indent         = $SPACE x ( $self->step * ( $level - 1 ) );
    my $leading        = $timestamp . $bullet . $indent;
    my $leading_width  = $self->uwidth($leading);
    my $leading_spaces = $SPACE x $leading_width;
    my $span_max       = $self->term_width - $leading_width - $NOTIFY_RIGHT_PAD;
    my $span_min       = int( $span_max * $MIN_SPAN_FACTOR );

    $text .= $self->ellipsis;

    my @lines = $self->_wrap( $text, $span_min, $span_max );
    my $final_width = $self->uwidth( $lines[-1] );
    $lines[0] = $leading . $lines[0];
    if ( @lines > 1 ) {
        $_ = "\n" . $leading_spaces . $_ foreach ( 1 .. $#lines );
    }

    for my $line (@lines) {
        my $succeeded = print $fh "$line";
        return unless $succeeded;
    }

    $self->set_position( $leading_width + $final_width );
    $self->_set_progwid(0);

    return $self;
} ## tidy end: sub _print_left_text

###########################
### close

sub done {
    my $self = shift;

    my ( %opts, @args );

    foreach (@_) {
        if ( reftype($_) eq 'HASH' ) {
            %opts = ( %opts, %{$_} );
        }
        else {
            push @args, $_;
        }
    }

    my $fh           = $self->fh;
    my $severity     = shift @args // $opts{closestat} // $self->closestat;
    my $severity_num = $self->severity_num($severity);

    if ( $opts{silent} ) {
        if ( $self->position ) {
            my $succeeded = print $fh "\n";
            return unless $succeeded;
            $self->set_position(0);
        }
        return $severity_num;
    }

    my $override_severity = $self->override_severity;
    my $maxdepth          = $self->maxdepth;
    my $level             = $self->level + $self->adjust_level;

    if ( defined $maxdepth and $level > $maxdepth ) {
        # skip printing, unless there's a severity override

        if ( $severity_num < $override_severity ) {
            return $severity_num;
            # less than the override severity, so return
        }

        # here severity is overriding the max depth

    }

    # Make the severity text

    my $severity_output;
    if ( $self->colorize ) {
        $severity_output = $self->_add_color($severity);
    }
    else {
        $severity_output = $severity;
    }
    $severity_output = " [$severity_output]\n";

    my $closetext = $opts{closetext} // $self->closetext;
    my $position = $self->position;

    if
      (    $position != 0
        or $self->opentext ne $closetext
        or $self->_not_opened
      )
    {
        if ( $position != 0 ) {
            my $succeeded = print $fh "\n";
            return unless $succeeded;
        }

        my $succeeded = _print_left_text($closetext);
        return unless $succeeded;
        
        $position = 0;

    }
    
    
    # here print trailers and closing text

} ## tidy end: sub done

sub d_emerg { my $self = shift; $self->done( @_, "EMERG" ) }
# syslog: Off the scale!
sub d_alert { my $self = shift; $self->done( @_, "ALERT" ) }
# syslog: A major subsystem is unusable.
sub d_crit { my $self = shift; $self->done( @_, "CRIT" ) }
# syslog: a critical subsystem is not working entirely.
sub d_fail { my $self = shift; $self->done( @_, "FAIL" ) }
# Failure
sub d_fatal { my $self = shift; $self->done( @_, "FATAL" ) }
# Fatal error
sub d_error { my $self = shift; $self->done( @_, "ERROR" ) }
# syslog 'err': Bugs, bad data, files not found, ...
sub d_warn { my $self = shift; $self->done( @_, "WARN" ) }
# syslog 'warning'
sub d_note { my $self = shift; $self->done( @_, "NOTE" ) }
# syslog 'notice'
sub d_info { my $self = shift; $self->done( @_, "INFO" ) }
# syslog 'info'
sub d_ok { my $self = shift; $self->done( @_, "OK" ) }
# copacetic
sub d_debug { my $self = shift; $self->done( @_, "DEBUG" ) }
# syslog: Really boring diagnostic output.
sub d_notry { my $self = shift; $self->done( @_, "NOTRY" ) }
# Untried
sub d_unk { my $self = shift; $self->done( @_, "UNK" ) }
# Unknown
sub d_yes { my $self = shift; $self->done( @_, "YES" ) }
# Yes
sub d_no { my $self = shift; $self->done( @_, "NO" ) }
# No
sub d_none {
    my $self = shift;
    $self->done( { -silent => 1 }, @_, "NONE" );
}
# *Special* closes level quietly (prints no wrapup severity)

sub DEMOLISH {
    my $self                  = shift;
    my $in_global_destruction = shift;

    return if $self->is_closed;

    $self->_close_up_to($self);

    return;

}

########################
### UTILITY METHODS

sub _spaced {
    my $self  = shift;
    my $text  = shift;
    my $width = shift;

    my $textwidth = $self->uwidth($text);

    return $text unless $textwidth < $width;

    my $spaces = ( $SPACE x ( $width - $textwidth ) );

    return ( $text . $spaces );

}

sub _wrap {
    my $self = shift;
    my ( $msg, $min, $max ) = @_;

    return unless defined $msg;

    return $msg
      if $max < 3 or $min > $max;

    state $breaker = Unicode::LineBreak::->new();
    $breaker->config( ColMax => $max, ColMin => $min );

    # First split on newlines
    my @lines = ();
    foreach my $line ( split( /\n/, $msg ) ) {

        my $linewidth = $self->uwidth($line);

        if ( $linewidth <= $max ) {
            push @lines, $line;
        }
        else {
            push @lines, $breaker->break($line);
        }

    }

    @lines = map {s/\s+\Z//} @lines;

    return @lines;

} ## tidy end: sub _wrap

sub _timestamp_now {
    my $self = shift;

    my $tsr = $self->timestamp;
    if ($tsr) {
        if ( reftype($tsr) eq 'CODE' ) {
            return &{$tsr};
        }
        my ( $s, $m, $h ) = localtime( time() );
        return sprintf "%2.2d:%2.2d:%2.2d ", $h, $m, $s;
    }

    return $EMPTY_STR;
}

sub _add_color {
    my $self = shift;
    my ( $str, $sev ) = @_;
    my $zon  = q{};
    my $zoff = q{};
    $zon = chr(27) . '[1;31;40m'
      if $sev =~ m{\bEMERG(ENCY)?}i;    #bold red on black
    $zon = chr(27) . '[1;35m' if $sev =~ m{\bALERT\b}i;            #bold magenta
    $zon = chr(27) . '[1;31m' if $sev =~ m{\bCRIT(ICAL)?\b}i;      #bold red
    $zon = chr(27) . '[1;31m' if $sev =~ m{\bFAIL(URE)?\b}i;       #bold red
    $zon = chr(27) . '[1;31m' if $sev =~ m{\bFATAL\b}i;            #bold red
    $zon = chr(27) . '[31m'   if $sev =~ m{\bERR(OR)?\b}i;         #red
    $zon = chr(27) . '[33m'   if $sev =~ m{\bWARN(ING)?\b}i;       #yellow
    $zon = chr(27) . '[36m'   if $sev =~ m{\bNOTE\b}i;             #cyan
    $zon = chr(27) . '[32m'   if $sev =~ m{\bINFO(RMATION)?\b}i;   #green
    $zon = chr(27) . '[1;32m' if $sev =~ m{\bOK\b}i;               #bold green
    $zon = chr(27) . '[37;43m' if $sev =~ m{\bDEBUG\b}i;    #grey on yellow
    $zon = chr(27) . '[30;47m' if $sev =~ m{\bNOTRY\b}i;    #black on grey
    $zon = chr(27) . '[1;37;47m'
      if $sev =~ m{\bUNK(OWN)?\b}i;                         #bold white on gray
    $zon  = chr(27) . '[32m' if $sev =~ m{\bYES\b}i;        #green
    $zon  = chr(27) . '[31m' if $sev =~ m{\bNO\b}i;         #red
    $zoff = chr(27) . '[0m'  if $zon;
    return $zon . $str . $zoff;
} ## tidy end: sub _add_color

1;
__END__
