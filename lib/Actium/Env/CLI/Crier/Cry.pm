package Actium::Env::CLI::Crier::Cry 0.015;
# vimcolor: #00261c

# One output from Actium::Env::CLI::Crier::Cry
#
# Based on Term::Emit by Steve Roscio

use Actium ('class');
use Types::Standard(qw/Maybe Str Int Bool CodeRef Undef/);
use Actium::Types(qw/CrierImportance CrierStatus/);

const my $CRIER_CLASS => 'Actium::Env::CLI::Crier';

const my $MAX_TAG_WIDTH => 5;
const my $RIGHT_INDENT  => $MAX_TAG_WIDTH + 3;
# includes brackets and a leading space.
const my $MIN_SPAN_FACTOR => ( 2 / 3 );
# sets ColMin in Unicode::LineBreak

##################
## crier attribute

has '_crier' => (
    isa      => $CRIER_CLASS,
    is       => 'ro',
    weak_ref => 1,
    required => 1,
    handles  => [
        qw/ _ensure_start_of_line _print
          position set_position
          over prog wail /
    ],
);

has '_level' => (
    isa      => Int,
    is       => 'ro',
    required => 1,
);

####################################
# silence, status, importance, level

has status => (
    isa       => CrierStatus,
    is        => 'rw',
    predicate => '_has_status',
);

has 'tag' => (
    is      => 'rw',
    isa     => Maybe [Str],
    default => undef,
);
# when tag is not defined, will use the status code to determine the tag

has importance => (
    isa       => CrierImportance,
    is        => 'ro',
    predicate => '_has_importance',
    writer    => '_set_importance',
);

# silent cries are never opened.
# muted cries are opened, but are not closed.

has '_silent' => (
    isa       => Bool,
    is        => 'rw',
    predicate => '_has_silent',
    #handles   => { _mark_not_silent => 'unset', },
);

has 'muted' => (
    isa     => Bool,
    is      => 'ro',
    default => 0,
    writer  => '_set_muted_to',
    traits  => ['Bool'],
    handles => {
        mute   => 'set',
        unmute => 'unset',
    },
);

##################################
### text and other displayed items

has 'opentext' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has 'closetext' => (
    is      => 'rw',
    isa     => Str,
    builder => '_build_closetext',
    lazy    => 1,
);

method _build_closetext { return $self->opentext }

has 'bullet' => (
    isa       => Str->plus_coercions( Undef, $EMPTY ),
    is        => 'ro',
    coerce    => 1,
    writer    => '_set_bullet',
    predicate => '_has_bullet',
);

method set_bullet (Maybe[Str] $bullet) {
    $self->_crier->_alter_bullet_width( [$bullet] )
      if defined $bullet and $bullet ne $EMPTY;
    return $self->_set_bullet($bullet);
}

method _bullet_to_use {
    if ( 0 == $self->_crier->_bullet_count ) {
        return $EMPTY;
    }

    my $bullet_width  = $self->_crier->_bullet_width;
    my $padded_bullet = Actium::u_pad(
        text  => $self->bullet,
        width => $bullet_width,
    );

    return $padded_bullet;

}

has 'ellipsis' => (
    is        => 'rw',
    isa       => Str,
    predicate => '_has_ellipsis',
);

has 'trailer' => (
    is        => 'rw',
    isa       => Str->where( sub { Actium::u_columns($_) == 1 } ),
    predicate => '_has_trailer',
);

has tag_color => (
    isa => Maybe [Str],
    is => 'rw',
    default => undef,
);

has 'timestamp' => (
    is        => 'rw',
    isa       => Bool | CodeRef,
    predicate => '_has_timestamp',
);

method _get_timestamp {

    my $timestamp = $self->timestamp;

    if ( defined $timestamp ) {
        if ( Actium::is_coderef($timestamp) ) {
            return $timestamp->( $self->_level );
        }
        my ( $s, $m, $h ) = localtime( time() );
        return sprintf "%2.2d:%2.2d:%2.2d ", $h, $m, $s;
    }
    return $EMPTY;
}

has _left_indent_cols => (
    isa => Int,
    is  => 'rw',
);

##########################
### state

has _position_changed => (
    isa      => Bool,
    init_arg => undef,
    is       => 'ro',
    default  => 0,
    traits   => ['Bool'],
    handles  => {
        _mark_position_changed   => 'set',
        _mark_position_unchanged => 'unset',
    },
);

has '_is_opened' => (
    isa      => Bool,
    init_arg => undef,
    is       => 'ro',
    default  => 0,
    traits   => ['Bool'],
    handles  => {
        _mark_opened => 'set',
        _not_opened  => 'not',
    },
);

# is_opened is used to indicate that the left text may not need to be
# displayed again.  Something might be built successfully but not displayed
# if it is silenced by something

has '_is_closed' => (
    is       => 'ro',
    isa      => Bool,
    default  => 0,
    init_arg => undef,
    traits   => ['Bool'],
    handles  => { _mark_closed => 'set', },
);

# used to indicate that we've already closed this cry,
# so that it is not closed twice -- once when it is explicitly closed
# and once when the DEMOLISH triggers

has '_built_without_error' => (
    is       => 'ro',
    isa      => Bool,
    default  => 0,
    init_arg => undef,
    traits   => ['Bool'],
    handles  => { _mark_built_without_error => 'set', },
);

# can't return from BUILD to the caller, because the caller is
# expecting the object. So uses that flag in lieu of returning
# a non-object

###########################
### open

sub BUILD {
    my $self = shift;

    # set attributes that should be set from crier upon construction

    $self->set_status( $self->_crier->default_status )
      unless $self->_has_status;

    $self->_set_importance( $self->_crier->default_importance )
      unless $self->_has_importance;

    $self->_set_silent(
        $self->importance < $self->_crier->filter_below_importance
          or ( defined $self->_crier->filter_above_level
            and $self->_crier->filter_above_level < $self->_level )
    ) unless $self->_has_silent;

    $self->mute if $self->_silent;

    $self->set_bullet(
          $self->_has_bullet
        ? $self->bullet
        : $self->_crier->_bullet_for_level( $self->_level )
    );
    # set_bullet alters the bullet width if necessary

    $self->set_ellipsis( $self->_crier->ellipsis )
      unless $self->_has_ellipsis;

    $self->set_trailer( $self->_crier->trailer )
      unless $self->_has_trailer;

    $self->set_timestamp( $self->_crier->timestamp )
      unless $self->_has_timestamp;

    # open the cry

    if ( not $self->_silent ) {
        $self->_mark_built_without_error if $self->_open;
    }
    else {
        $self->_mark_built_without_error;
    }

    # the built_without_error attribute is used because we cannot
    # return a status here (new() returns the object no matter what)

    return;

}

method _open {
    my $succeeded = $self->_print_left_text( $self->opentext );
    $self->_mark_opened;
    return $succeeded;
}

method _print_left_text ($text) {
    return undef unless $self->_ensure_start_of_line;

    my $indent_for_level
      = $SPACE x ( $self->_crier->step * ( $self->_level - 1 ) );
    my $leader
      = $self->_get_timestamp() . $self->_bullet_to_use . $indent_for_level;

    my $left_indent_cols = Actium::u_columns($leader);
    $self->_set_left_indent_cols($left_indent_cols);

    my $span_max
      = $self->_crier->column_width - $left_indent_cols - $RIGHT_INDENT;
    my $span_min = int( $span_max * $MIN_SPAN_FACTOR );

    my @lines = Actium::u_wrap(
        $text . $self->ellipsis,
        min_columns => $span_min,
        max_columns => $span_max
    );

    # add leader text to first line, and indent remaining lines to match
    $lines[0] = $leader . $lines[0];
    foreach my $line ( @lines[ 1 .. $#lines ] ) {
        $line = ( $SPACE x $left_indent_cols ) . $line;
    }

    return undef unless $self->_print( join( "\n", @lines ) );
    my $width_of_final_line = Actium::u_columns( $lines[-1] );
    $self->_crier->_set_raw_position($width_of_final_line);
    $self->_crier->_set_prog_cols(0);
    $self->_mark_position_unchanged;

    return 1;
}

###########################
### close

method _force_display {
    my $status                   = $self->status;
    my $always_show_status_above = $self->_crier->always_show_status_above;
    return 0 if not defined $always_show_status_above;
    return 1 if $status < $always_show_status_above->[0];
    return 1 if $always_show_status_above->[1] < $status;
    return 0;
}

method _close {
    return $self->status if $self->_is_closed;

    ( \my %opts, \my @args ) = $self->_crier->_opts_and_args(@_);

    # handle options that are attributes

    # _c_tag is used to determine the status, unlike a plain tag option,
    # which is not
    my $c_tag = delete $opts{_c_tag};
    if ( defined $c_tag ) {
        $opts{tag} = $c_tag;
        my $status_of_tag = $self->_crier->_status_of_tag( uc($c_tag) );
        $opts{status} = $status_of_tag if defined $status_of_tag;
    }

    for my $attribute (
        qw/status tag bullet ellipsis timestamp trailer closetext tag_color/)
    {
        my $value  = delete $opts{$attribute};
        my $setter = "set_$attribute";
        $self->$setter($value) if defined $value;
    }
    my $muted = delete $opts{muted};
    if ( defined $muted ) {
        $self->_set_muted_to($muted);
    }
    else {
        $self->unmute if $self->_force_display;
    }

    if ( $self->muted ) {
        $self->_mark_closed;
        if ( $self->_is_opened ) {
            return undef unless $self->_ensure_start_of_line;
        }
        return $self->status;
    }

    my $status = $self->status;
    my $tag    = Actium::u_trim_to_columns(
        string => $self->tag // $self->_crier->_tag_of_status($status),
        columns => $MAX_TAG_WIDTH
    );

    $tag = ' [' . $self->_add_color($tag) . "]\n";

    my $closetext = $self->closetext;

    if (   $self->position == 0
        or $self->opentext ne $closetext
        or $self->_not_opened )
    {

        $self->_crier->_open_below($self);
        return undef unless $self->_print_left_text($closetext);
        # position was altered by _print_left_text
    }

    # here print trailers and closing text

    # trailer set to be a single column wide by attribute type

    my $num_trailers
      = $self->_crier->column_width - $self->position - $RIGHT_INDENT;
    return undef unless $self->_print( $self->trailer x $num_trailers, $tag );
    $self->set_position(0);

    $self->_mark_closed;

    if ( defined $opts{reason} ) {
        return undef
          unless $self->_crier->_display_wail(
            text              => $opts{reason},
            left_indent_cols  => $self->_left_indent_cols + 1,
            right_indent_cols => $RIGHT_INDENT + 1
          );
    }

    return $status;

}

##############################
# public close methods

sub c {
    my $self   = shift;
    my $status = shift;
    my %opts;
    if ( defined $status ) {
        if ( Actium::is_ref($status) ) {
            unshift @_, $status;
        }
        elsif ( $status =~ /\A -? [0-7] \z/x ) {
            $opts{status} = $status;
        }
        else {
            $opts{_c_tag} = $status;
        }
    }
    return $self->_crier->_close_up_to( $self, @_, \%opts );
}

method bliss { $self->c( 'BLISS', @_ ); }
method calm { $self->c( 'CALM',  @_ ); }
method pass { $self->c( 'PASS',  @_ ); }
method valid { $self->c( 'VALID', @_ ); }
method done { $self->c( 'DONE',  @_ ); }
method info { $self->c( 'INFO',  @_ ); }
method yes { $self->c( 'YES',   @_ ); }
method ok { $self->c( 'OK',    @_ ); }
method no { $self->c( 'NO',    @_ ); }
method warn { $self->c( 'WARN',  @_ ); }
method abort { $self->c( 'ABORT', @_ ); }
method error { $self->c( 'ERROR', @_ ); }
method fail { $self->c( 'FAIL',  @_ ); }
method alert { $self->c( 'ALERT', @_ ); }
method panic { $self->c( 'PANIC', @_ ); }

method c_quiet {
    ( \my %opts, \my @args ) = $self->_crier->_opts_and_args(@_);
    return $self->c( @args, { tag => 'QUIET', muted => 1 }, \%opts );
}
# closes level quietly (prints no wrapup severity)

sub DEMOLISH {
    my $self = shift;
    return if $self->_is_closed;
    $self->_crier->_close_up_to($self);
    return;
}

#######################
#### COLORIZE

method _add_color (Str $string) {
    return $string unless $self->_crier->colorize;
    my $status = $self->status;
    my $color  = $self->tag_color
      // $self->_crier->_color_of_status( $self->status );
    return $string unless $color;

    require Term::ANSIColor;    ### DEP ###
    return Term::ANSIColor::colored( $string, $color );
}

1;
__END__

=encoding utf-8

=head1 NAME

Actium::Env::CLI::Crier::Cry - An single Actium::Env::CLI::Crier cry

=head1 VERSION

This documentation refers to version 0.015

=head1 SEE

All documentation for this module is found in  L<the documentation for
Actium::Env::CLI::Crier/Actium::Env::CLI::Crier>.

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
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

