#!/ActivePerl/bin/perl

#/Actium/Flagspecs/Route.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::Route 0.001;

use Moose;
use MooseX::StrictConstructor;

around BUILDARGS => sub {
    return positional( \@_, 'patterns_r' );
};

has 'route' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'patterns_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::Flagspecs::Pattern]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        patterns    => 'elements',
    },
);


has 'dir_obj_of' => (
    is      => 'bare',
    traits  => ['Hash'],
    isa     => 'HashRef[Actium::Sked::Dir]',
    builder => '_build_dir_objs_of' ,
    lazy => 1,
    handles => {
        dir_codes    => 'keys',
        dir_obj_of => 'get' ,
        dir_objs => 'values' ,
        has_direction => 'exists',
    },
);

sub _build_dir_objs_of {
    my $self = shift;
    my %dir_obj_of;
    foreach my $pattern ($self->patterns) {
        my $dir_obj = $pattern->dir_obj;
        my $dircode = $dir_obj->dircode;
        $dir_obj_of{$dircode} = $dir_obj;
    }
    return \%dir_obj_of;
}

# $hashref->{placelist}->[0..n]

has 'pattern_of_placelist_r' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Actium::Flagspecs::Pattern]]',
    builder => '_build_pattern_of_placelist_r' ,
    lazy => 1,
    traits => ['Hash'],
    handles => {
        _pattern_list_of_placelist_r     => 'get',
        _set_pattern_list_of_placelist_r => 'set',
        has_placelist    => 'exists',
        placelists => 'keys',
    },
);

sub _build_pattern_of_placelist_r {
    my $self = shift;
    my %patterns_of;
    foreach my $pattern ($self->patterns) {
        push @{$patterns_of{$pattern->placelist}} , $pattern;
    }
    return \%patterns_of;
}

sub patterns_of_placelist {
    my $self              = shift;
    my $placelist = shift;
    return @{ $self->_pattern_list_of_placelist_r($placelist) };
}

has 'pattern_of_dir_r' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Actium::Flagspecs::Pattern]]',
    builder => '_build_pattern_of_dir_r' ,
    lazy => 1,
    traits => ['Hash'],
    handles => {
        _pattern_list_of_dir_r     => 'get',
        _set_pattern_list_of_dir_r => 'set',
    },
);

sub _build_pattern_of_dir_r {
    my $self = shift;
    my %patterns_of;
    foreach my $pattern ($self->patterns) {
        push @{$patterns_of{$pattern->direction}} , $pattern;
    }
    return \%patterns_of;
}

sub patterns_of_dir {
    my $self              = shift;
    my $dir = shift;
    return @{ $self->_pattern_list_of_dir_r($dir) };
}

# TODO - build route stop lists here

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
