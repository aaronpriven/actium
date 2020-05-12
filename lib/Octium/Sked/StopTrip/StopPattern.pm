package Octium::Sked::StopTrip::StopPattern 0.015;
# vimcolor: #132600

# Pattern information of a stop in a StopTrip

use Actium 'class';
use Types::Standard (qw/ArrayRef Str Bool Undef HashRef/);
use Type::Utils('class_type');

const my $CONSTRUCTOR => '_octium_sked_stoptrip_stoppattern_new';

{
    no strict 'refs';
    *{"Moose::Object::$CONSTRUCTOR"} = \&Moose::Object::new;
}

# place_in_effect = place of this stop, or the immediately preceding place
# is_at_place = this stop is actually at this place
# next_place = the place following this stop, if any (won't be for last stop)
# destination_place = final place of this trip

has ensuingstops => (
    # list of subsequent stops
    isa => class_type('Octium::Sked::StopTrip::EnsuingStops')
      ->plus_constructors( ArrayRef [Str], 'new' ),
    is       => 'ro',
    coerce   => 1,
    required => 1,
    handles  => [qw/is_final_stop ensuing_str/],
);

has [qw/next_place/] => (
    is      => 'ro',
    default => $EMPTY,
    isa     => Str->plus_coercions( Undef, sub {$EMPTY} ),
    coerce  => 1,
);

has [qw/place_in_effect destination_place/] => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has is_at_place => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has bundle => (
    isa      => HashRef,
    is       => 'ro',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_bundle',
);

method _build_bundle {

    my $ensuing_bundle = $self->ensuingstops->bundle;
    my $bundle         = {
        ensuingstops => $ensuing_bundle,
        map { $_ => $self->$_ }
          qw/next_place place_in_effect destination_place is_at_place/,
    };
    return $bundle;
}

const my $JOINER => $SPACE;

my %obj_cache;

my $cachekey_cr = func( \%params ) {
    $params{ensuingstops} = Actium::refaddr( $params{ensuingstops} );
    my @keys = sort keys %params;
    return join( $JOINER, %params{@keys} );
};

override new {
    my $params = $self->BUILDARGS(@_);
    my $key    = $cachekey_cr->($params);
    return $obj_cache{$key} //= $self->$CONSTRUCTOR(@_);
}

method undbundle (HashRef $bundle) {
    $bundle->{ensuingstops}
      = Octium::Sked::StopTrip::EnsuingStops->unbundle(
        $bundle->{ensuingstops} );
    return $self->new($bundle);
}

Actium::immut( constructor_name => $CONSTRUCTOR );

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use <name>;
 # do something with <name>

=head1 DESCRIPTION

A full description of the module and its features.

=head1 CLASS METHODS

=head2 method

Description of method.

=head1 OBJECT METHODS or ATTRIBUTES

=head2 method

Description of method.

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

The Actium system, and...

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues|https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2020

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item *

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item *

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

