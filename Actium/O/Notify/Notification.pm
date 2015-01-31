# Actium/O/Notify/Notification -
# One output from Actium::O::Notify::Notification
#
# Based on Term::Emit by Steve Roscio
#
#  Subversion: $Id$

package Actium::O::Notify::Notification 0.009;

use Actium::Moose;
use Unicode::LineBreak;
use Unicode::GCString;

use Actium::Types (qw<NotifyBullet NotifyTrailer>);
use Actium::Util  (qw<u_columns u_pad u_wrap u_trim_to_columns>);

use Term::ANSIColor;

const my $MAX_SEVERITY_TEXT_WIDTH => 5;
const my $SEVERITY_MARKER_WIDTH   => 8;    # text width, plus space and brackets
const my $NOTIFY_RIGHT_PAD        => 10;
const my $MIN_SPAN_FACTOR         => 2 / 3;

###############################
## Attributes set via constructor

has 'notifier' => (
    isa      => 'Actium::O::Notify',
    is       => 'ro',
    weak_ref => 1,
    required => 1,
    handles  => [
        qw[
          fh
          minimum_severity maximum_severity severity_num
          step             maxdepth         override_severity
          term_width       position         set_position
          _prog_cols      _set_prog_cols
          _bullet_width    _alter_bullet_width
          _close_up_to
          backspace
          ]
    ]
);

has 'opentext' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'silent' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
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
    is      => 'rw',
    default => 0,
);

has 'closetext' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_closetext',
);

sub _build_closetext {
    my $self = shift;
    return $self->opentext;
}

has 'bullet' => (
    isa     => NotifyBullet,
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
    lazy    => 1,
    builder => '_reset_closestat',
);

sub _reset_closestat {
    my $self = shift;
    return $self->notifier->default_closestat;
}

has 'timestamp' => (
    is      => 'rw',
    isa     => 'Bool | CodeRef',
    lazy    => 1,
    builder => '_reset_timestamp',
);

sub _reset_timestamp {
    my $self = shift;
    return $self->notifier->timestamp;
}

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

has 'ellipsis' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    builder => '_reset_ellipsis',
);

sub _reset_ellipsis {
    my $self = shift;
    return $self->notifier->ellipsis;
}

has 'trailer' => (
    is      => 'rw',
    isa     => NotifyTrailer,
    lazy    => 1,
    builder => '_reset_trailer',
);

sub _reset_trailer {
    my $self = shift;
    return $self->notifier->trailer;
}

has 'colorize' => (
    isa     => 'Bool',
    is      => 'ro',
    lazy    => 1,
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
# is_opened is used to indicate that the opentext does not need to be
# displayed again.  Something might be built successfully but not displayed
# if it is silenced by the maxdepth attribute

has '_is_closed' => (
    is       => 'ro',
    isa      => 'Bool',
    default  => '0',
    init_arg => undef,
    traits   => ['Bool'],
    handles  => { _mark_closed => 'set', },
);

# used to indicate that we've already closed this notification,
# so that it is not closed twice -- once when it is explicitly closed
# and once when the DEMOLISH triggers

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

    my $succeeded = $self->_print_left_text( $self->opentext, $level );
    $self->_mark_opened;
    return $succeeded;

} ## tidy end: sub _open

sub BUILD {
    my $self = shift;

    my $level    = $self->level + $self->adjust_level;
    my $maxdepth = $self->maxdepth;

    if ( ( not defined $maxdepth ) or $level <= $maxdepth ) {
        # if not s not hidden by maxdepth
        my $success = $self->_open($level);
        $self->_mark_built_without_error if $success;
    }
    else {
        $self->_mark_built_without_error;
    }
    # the built_without_error attribute is used because we cannot
    # return a status here (new() returns the object no matter what)

    return;

} ## tidy end: sub BUILD

sub _print_left_text {
    my $self  = shift;
    my $fh    = $self->fh;
    my $text  = shift;
    my $level = shift;

    # Timestamp
    my $timestamp = $self->_timestamp_now;

    my $bullet = u_pad( $self->bullet, $self->_bullet_width );
    my $indent         = $SPACE x ( $self->step * ( $level - 1 ) );
    my $leading        = $timestamp . $bullet . $indent;
    my $leading_width  = u_columns($leading);
    my $leading_spaces = $SPACE x $leading_width;
    my $span_max       = $self->term_width - $leading_width - $NOTIFY_RIGHT_PAD;
    my $span_min       = int( $span_max * $MIN_SPAN_FACTOR );

    $text .= $self->ellipsis;

    my @lines = u_wrap( $text, $span_min, $span_max );
    my $final_width = u_columns( $lines[-1] );
    $lines[0] = $leading . $lines[0];
    if ( @lines > 1 ) {
        $lines[$_] = "\n" . $leading_spaces . $lines[$_]
          foreach ( 1 .. $#lines );
    }

    for my $line (@lines) {
        my $succeeded = print $fh $line;
        return unless $succeeded;
    }

    $self->set_position( $leading_width + $final_width );
    $self->_set_prog_cols(0);

    return $self;
} ## tidy end: sub _print_left_text

###########################
### close

sub _close {
    my $self = shift;

    return if $self->_is_closed;

    my ( %opts, @args );

    # process arguments
    foreach (@_) {
        if ( defined( reftype($_) ) and reftype($_) eq 'HASH' ) {
            %opts = ( %opts, %{$_} );
        }
        else {
            push @args, $_;
        }
    }

    my $fh           = $self->fh;
    my $severity     = shift @args // $opts{closestat} // $self->closestat;
    my $severity_num = $self->severity_num($severity);
    my $silent       = $opts{silent} // $self->silent;

    # skip printing if silent
    if ($silent) {
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

    # skip printing, unless there's a severity override
    if ( defined $maxdepth and $level > $maxdepth ) {

        if ( $severity_num < $override_severity ) {
            return $severity_num;
            # less than the override severity, so return
        }

        # here severity is overriding the max depth

    }

    # Make the severity text

    my $severity_output
      = u_trim_to_columns( $severity, $MAX_SEVERITY_TEXT_WIDTH );
    if ( $self->colorize ) {
        $severity_output = $self->add_color($severity_output);
    }
    $severity_output = " [$severity_output]\n";

    my $closetext = $opts{closetext} // $self->closetext;
    my $position = $self->position;

    if (   $position == 0
        or $self->opentext ne $closetext
        or $self->_not_opened )
    {
        if ( $position != 0 ) {
            my $succeeded = print $fh "\n";
            return unless $succeeded;
        }

        my $succeeded = $self->_print_left_text( $closetext, $level );
        return unless $succeeded;

        $position = $self->position;
        # altered by _print_left_text

    }

    # here print trailers and closing text

    my $trailer = $self->trailer;
    # trailer set to be a single column wide by attribute type

    my $num_trailers = $self->term_width - $position - $SEVERITY_MARKER_WIDTH;
    my $succeeded = print $fh ( $trailer x $num_trailers, $severity_output );
    return unless $succeeded;

    $self->set_position(0);

    $self->_mark_closed;

    my $reason = $opts{reason};
    if ( defined $reason ) {
        $opts{force} = 1;
        # bypass level check if it got here
        my $succeeded = $self->text( \%opts, $reason );
        return unless $succeeded;
    }

    return $severity_num;

} ## tidy end: sub _close

sub done {
    my $self = shift;
    return $self->_close_up_to( $self, @_ );
}

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
# Unknown. Also, if notification object wasn't saved

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

    my $fh = $self->fh;

    return if $self->_is_closed;

    $self->_close_up_to($self);

    return;

}

#######################
### PROGRESS AND TEXT

sub prog {

    my $self = shift;

    my $separator = doe($OUTPUT_FIELD_SEPARATOR);
    my $msg = join( $separator, doe(@_) );

    my $level = $self->level;
    return 1 if defined( $self->maxdepth ) and $level > $self->maxdepth;

    # Start a new line?
    my $avail   = $self->term_width - $self->position - $NOTIFY_RIGHT_PAD;
    my $columns = u_columns($msg);
    my $fh      = $self->fh;

    my $position = $self->position;
    my $progcols = $self->_prog_cols;

    if ( $columns > $avail ) {

        my $bspace    = q{ } x $self->_bullet_width;
        my $indent    = q{ } x ( $self->step * $level );
        my $succeeded = print $fh "\n", $bspace, $indent;
        return unless $succeeded;

        $position = length($bspace) + length($indent);
        $progcols = 0;
        $self->set_position($position);
        $self->_set_prog_cols($progcols);
    }

    # the text
    my $succeeded = print $fh $msg;
    return unless $succeeded;

    $self->set_position( $position + $columns );
    $self->_set_prog_cols( $progcols + $columns );

    return 1;

} ## tidy end: sub prog

sub over {
    my $self = shift;

    # if no backspace (in braindead consoles like Eclipse's),
    # then treats everything as a forward-progress.
    if ( $self->backspace ) {

        # filtering by level
        my $level    = $self->level;
        my $maxdepth = $self->maxdepth;
        return 1 if defined($maxdepth) and $level > $maxdepth;

        my $fh = $self->fh;

        my $prog_cols  = $self->_prog_cols;
        my $backspaces = "\b" x $prog_cols;
        my $spaces     = $SPACE x $prog_cols;

        my $succeeded = print $fh $backspaces, $spaces, $backspaces;
        return unless $succeeded;

        $self->set_position( $self->position - $prog_cols );
        $self->_set_prog_cols(0);

    } ## tidy end: if ( $self->backspace )

    return $self->prog(@_);
} ## tidy end: sub over

sub text {
    my $self = shift;

    my ( %opts, @args );

    # process arguments
    foreach (@_) {
        if ( defined( reftype($_) ) and reftype($_) eq 'HASH' ) {
            %opts = ( %opts, %{$_} );
        }
        else {
            push @args, $_;
        }
    }

    my $level    = $self->level;
    my $maxdepth = $self->maxdepth;
    return 1
      if ( not $opts{force} )
      and defined($maxdepth)
      and $level > $maxdepth;

    my $separator = doe($OUTPUT_FIELD_SEPARATOR);
    my $text = join( $separator, @args );

    my $fh = $self->fh;

    if ( $self->position != 0 ) {
        my $succeeded = print $fh "\n";
        return unless $succeeded;
    }

    my $bullet_width = $self->_bullet_width;

    my $adjust_level = $opts{adjust_level} // $self->adjust_level;
    my $indent_level = 1 + $level + $adjust_level;
    # over by one by default
    my $indent_cols = $self->step * $indent_level + $bullet_width;
    my $indentspace = $SPACE x $indent_cols;

    my $span_max = $self->term_width - $indent_cols - $NOTIFY_RIGHT_PAD;
    my $span_min = int( $span_max * $MIN_SPAN_FACTOR );

    my @lines = u_wrap( $text, $span_min, $span_max );

    foreach my $line (@lines) {
        my $succeeded = print $fh $indentspace, $line, "\n";
        return unless $succeeded;
        $self->set_position(0);
    }

    return 1;
} ## tidy end: sub text

#######################
#### COLORIZE

{
    const my %COLORS_OF => (
        EMERG => 'bold blink bright_white on_red',
        ALERT => 'bold blink bright_yellow on_red',
        CRIT  => 'bold bright_white on_red',
        FAIL  => \'CRIT',
        FATAL => \'CRIT',
        ERR   => 'bold bright_yellow on_red',
        ERROR => \'ERR',
        WARN  => 'bold black on_bright_yellow',
        NOTE  => 'bold bright_white on_blue',
        INFO  => 'green',
        OK    => \'INFO',
        DEBUG => 'bright_white on_bright_black',      #  'bold black on_yellow',
        NOTRY => 'bold bright_white on_magenta',
        UNK   => 'bold bright_yellow on_magenta',
        YES   => 'green',
        NO    => 'bright_red',
    );    # OTHER and DONE explicitly omitted

    sub add_color {

        my $self    = shift;
        my $sev     = shift;
        my $sev_key = uc($sev);

        while ( exists( $COLORS_OF{$sev_key} )
            and defined( reftype( $COLORS_OF{$sev_key} ) ) )
        {
            $sev_key = ${ $COLORS_OF{$sev_key} };
        }

        return $sev unless exists $COLORS_OF{$sev_key};

        require Term::ANSIColor;
        return Term::ANSIColor::colored( $sev, $COLORS_OF{$sev_key} );

    }

}

1;
__END__

=encoding utf-8

=head1 NAME

Actium::O::Notify::Notification - An instance of an Actium::O::Notify notification

=head1 VERSION

This documentation refers to version 0.009o

=head1 SEE

All documentation for this module is found in 
L<the documentation for Actium::O::Notify/Actium::O::Notify>.

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
