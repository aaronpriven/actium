package Actium::AttrHandlers;

use warnings;
use strict;

use Exporter qw( import );
our @EXPORT_OK
  = qw(arrayhandles arrayhandles_ro stringhandles numhandles boolhandles counterhandles hashhandles );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

### PRIVATE HELPER ROUTINES FOR ATTRIBUTE HANDLERS

my $EMPTY_STR = '';

sub _op_name {
    my @pairs;
    foreach (@_) {
        push @pairs, "${_}_%", $_;
    }
    return @pairs;
}

sub _name_op {
    my @pairs;
    foreach (@_) {
        push @pairs, "%_$_", $_;
    }
    return @pairs;
}

sub _op_to_name {
    my @pairs;
    foreach (@_) {
        push @pairs, "${_}_to_%", $_;
    }
    return @pairs;
}

sub _array_pl_ro {
    return (
        _op_name(qw<grep map>),
        _name_op('natatime'),
        '%'            => 'elements',
        '%_joinedwith' => 'join',
        '%_reducedwith' => 'reduce',
        'sorted_%'     => 'sort',
        'shuffled_%'   => 'shuffle',
        'unique_%'     => 'uniq',
        '%_are_empty'  => 'is_empty',
    );

}

sub _array_sing_ro {
    return (
        'first_%_where' => 'first',
        _name_op('count'),
        '%' => 'get',
    );
}

sub _array_pl_rw {
    return ( _op_name(qw<pop push shift unshift splice clear insert >),
        'sort_%' => 'sort_in_place', );
}

sub _array_sing_rw {
    return _op_name(qw<delete set insert>),;
}

sub _str {
    return (
        _op_to_name(qw<append prepend length>),
        _op_name(qw<inc chop chomp replace match clear substr>),
    );
}

sub _num {
    return (
        _op_name(qw<set abs>),
        _op_to_name(qw<add>),
        'subtract_from_%' => 'sub',
        'multiply_by_%'   => 'mul',
        'divide_by_%'     => 'div',
        '%_modulo'        => 'mod',
    );
}

sub _hash {
    return ( _op_name(qw<get set delete keys exists 
             defined values kv elements clear count is_empty > ) );

# This is kind of the easy way out -- it makes sense for some things
# (get_thing_of{other_thing}) but less so for other things
# (get_thing_of{qw<other_thing third_thing>} , 
# exists_thing_of{other_thing} , keys_thing_of , kv_thing_of). 

# set is OK here because it assumes _r

}

sub _bool {
    return ( _op_name(qw<toggle not>),
             't_%' => 'set' ,
             'f_%' => 'unset',
     );
}

sub _counter {
    return ( _op_name(qw<inc dec reset>) );
}
# set is handled by MooseX::SemiAffordanceAccessor
# so on this one, you can use is => 'ro' or 'rw'

sub _privacy {
    my @names = @_;
    my $private;

    if ( substr( $names[0], 0, 1 ) eq '_' ) {
        $private = 1;
        substr( $_, 0, 1, $EMPTY_STR ) foreach @names;
    }

    return $private, @names;

}

sub _restore_privacy {

    my ( $private, %handles ) = @_;

    return %handles unless $private;

    my %newhandles;

    foreach ( keys %handles ) {
        $newhandles{ '_' . $_ } = $handles{$_};
    }

    return %newhandles;
}

sub _replace_attr {
    my $attr = shift;
    my @pairs = @_;
    s/%/$attr/g foreach @pairs;
    return @pairs;
}

sub _singularplural {
    my $singular = shift;
    my $plural = shift || ("${singular}s");
    return ( $singular, $plural );
}
### ATTRIBUTE HANDLERS

sub arrayhandles_ro {

    my ( $privacy, @names ) = _privacy(@_);

    my ( $singular, $plural ) = _singularplural(@_);

    my %handles = (
        _replace_attr( $plural,   _array_pl_ro() ),
        _replace_attr( $singular, _array_sing_ro() ),
    );

    return _restore_privacy( $privacy, %handles );

}

sub arrayhandles {
    my ( $privacy, @names ) = _privacy(@_);

    my ( $singular, $plural ) = _singularplural(@names);

    #my %handles = (
    #    _replace_attr( $plural,   _array_pl_ro() ),
    #    _replace_attr( $singular, _array_sing_ro() ),
    #    _replace_attr( $plural,   _array_pl_rw() ),
    #    _replace_attr( $singular, _array_sing_rw() ),
    #);

    my %a = _replace_attr( $plural,   _array_pl_ro() );
    my %b = _replace_attr( $singular, _array_sing_ro() );
    my %c = _replace_attr( $plural,   _array_pl_rw() );
    my %d = _replace_attr( $singular, _array_sing_rw() );

    my %handles = ( %a, %b, %c, %d );

    return _restore_privacy( $privacy, %handles );

} ## <perltidy> end sub arrayhandles

sub _handles {

    my ( $privacy, $name ) = _privacy( shift @_ );
    my %handles = _replace_attr( $name, @_ );
    return _restore_privacy( $privacy, %handles );
}

sub stringhandles {
    return _handles( shift, _str() );
}

sub numhandles {
    return _handles( shift, _num() );
}

sub boolhandles {
    return _handles( shift, _bool() );
}

sub counterhandles {
    return _handles( shift, _counter() );
}

sub hashhandles {
    return _handles (shift , _hash() );
}


1;

