# Actium/O/Proclaim/Proclamation -
# One output from Actium::O::Proclaim::Proclamation
#
# Forked from Term::Emit by Steve Roscio
#
#  Subversion: $Id$

package Actium::O::Proclaim::Proclamation 0.005;

use Actium::Moose;
use Unicode::LineBreak;

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

has 'proclaimer' => (
    isa     => 'Actium::O::Proclaim',
    is      => 'ro',
    weakref => 1,
    handles => [
        qw[
          fh
          minimum_severity maximum_severity severity
          pos set_pos
          _progwid _set_progwid
          _bullet_width
          _alter_bullet_width
          breaker
          ellipsis
          colorize
          maxdepth
          showseverity
          step
          trailer
          width set_width
          close_proclamation
          uwidth
          ]

    ]
);

has 'opentext' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'adjust_level' => (
    isa     => 'Int',
    is      => 'rw',
    default => 0,
);

has 'is_opened' => (
    isa      => 'Bool',
    init_arg => undef,
    is       => 'ro',
    default  => 0,
    traits   => ['Bool'],
    handles  => { mark_opened => 'set', },
);

has 'closetext' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'closestat' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    # there is a default, but it's set in Actium::O::Proclaim::proclaim
);

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

sub _bullet_spaced {
    my $self        = shift;
    my $bullet      = shift;
    my $bulletwidth = $self->_uwidth($bullet);

    return $self->_spaced( $bullet, $bulletwidth );

}

sub _spaced {
    my $self  = shift;
    my $text  = shift;
    my $width = shift;

    my $textwidth = $self->uwidth($text);

    return $text unless $textwidth < $width;

    my $spaces = ( $SPACE x ( $width - $textwidth ) );

    return ( $text . $spaces );

}

has 'level' => (
    isa      => 'Int',
    is       => 'ro',
    required => 1,
);

has 'timestamp' => (
    is      => 'ro',
    isa     => 'Bool | CodeRef',
    default => 0,
);

has 'is_closed' => (
    is       => 'ro',
    isa      => 'Bool',
    default  => '0',
    init_arg => undef,
    traits   => ['Bool'],
    handles  => { mark_closed => 'set', },
);

const my $PROCLAIM_RIGHT_PAD => 10;
const my $MIN_SPAN_FACTOR    => 2 / 3;

sub _open_proclamation {

    my $self = shift;
    my $fh   = $self->fh;
    my $pos  = $self->pos;

    # start back at the left
    if ($pos) {
        my $succeeded = print $fh "\n";
        return $succeeded unless $succeeded;
    }

    # Timestamp
    my $timestamp = $self->_timestamp_now;

    my $level = $self->level + $self->adjust_level;

    my $bullet         = $self->bullet;
    my $indent         = $SPACE x ( $self->step * ( $level - 1 ) );
    my $leading        = $timestamp . $bullet . $indent;
    my $leading_width  = $self->uwidth($leading);
    my $leading_spaces = $SPACE x $leading_width;
    my $span_max = $self->term_width - $leading_width - $PROCLAIM_RIGHT_PAD;
    my $span_min = int( $span_max * $MIN_SPAN_FACTOR );

    my $text = $self->opentext . $self->ellipsis;

    my @lines = $self->_wrap( $text, $span_min, $span_max );
    my $final_width = $self->uwidth( $lines[-1] );

    $lines[0] = $leading . $lines[0];
    if ( @lines > 1 ) {
        $_ = "\n" . $leading_spaces . $_ foreach ( 1 .. $#lines );
    }

    my $maxdepth = $self->maxdepth;
    if ( defined $maxdepth and $level >= $maxdepth ) {

        for my $line (@lines) {
            my $succeeded = print $fh "$line";
            return $succeeded unless $succeeded;
        }

        $self->set_pos( $leading_width + $final_width );
        $self->_set_progwid(0);
        $self->mark_opened;
    }

    return $self;

} ## tidy end: sub _open_proclamation

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

sub BUILD {
    my $self = shift;

    $self->_open_proclamation;

    # output proclamation

}

sub DEMOLISH {
    my $self                  = shift;
    my $in_global_destruction = shift;

    return if $self->is_closed;

    $self->close_proclamation($self);

    return;

}

1;

__END__
