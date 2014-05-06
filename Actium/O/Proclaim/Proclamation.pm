# Actium/O/Proclaim/Proclamation -
# One output from Actium::O::Proclaim::Proclamation
#
# Forked from Term::Emit by Steve Roscio
#
#  Subversion: $Id$

package Actium::O::Proclaim::Proclamation 0.005;

use Actium::Moose;

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
          breaker
          ellipsis
          colorize
          maxdepth
          showseverity
          step
          trailer
          width set_width
          close_proclamation
          _default_timestamp;
          ]

    ]
);

has 'opentext' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
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
    is      => 'rw',
);

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

sub _open_proclamation {

    my $self = shift;
    my $fh   = $self->fh;
    my $pos  = $self->pos;

    # start back at the left
    if ($pos) {
        my $result = print $fh "\n";
        return $result if $result;
    }

    $self->set_pos(0);
    $self->_set_progwid(0);

    # Timestamp
    my $timestamp = $self->_timestamp_now;
    
    


} ## tidy end: sub _open_proclamation

sub _timestamp_now {
    my $self = shift;

    my $tsr = $self->timestamp;
    if ($tsr) {
        if ( reftype($tsr) eq 'CODE' ) {
            return &{$tsr};
        }
        return $self->_default_timestamp;
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
