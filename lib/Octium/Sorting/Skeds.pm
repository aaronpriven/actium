package Octium::Sorting::Skeds 0.012;

# Routines to sort schedule-type objects

use 5.016;
use warnings;

use Sub::Exporter -setup => { exports => [qw(skedsort)] };
# Sub::Exporter ### DEP ###
use Params::Validate;    ### DEP ###

use Octium::Sorting::Line (qw(byline linekeys));

use List::Util(qw/min/);    ### DEP ###
use Params::Validate();     ### DEP ###

my $required_methods
  = [qw( linedir earliest_timenum sortable_id sortable_id_with_timenum )];

# can take Octium::Sked objects, or Octium::Sked::Timetable objects
# or anything else that can do those methods

sub skedsort {

    Params::Validate::validate_pos( @_,
        ( ( { can => $required_methods } ) x scalar(@_) ) );

    my %earliest_timenum_of;
    my @objs = @_;

    my @objs_with_ids;

    foreach my $obj (@objs) {

        if ( $obj->should_preserve_direction_order ) {
            push @objs_with_ids, { obj => $obj, id => $obj->sortable_id };
        }
        else {
            my $linedir          = $obj->linedir;
            my $earliest_timenum = $obj->earliest_timenum;
            if ( exists $earliest_timenum_of{$linedir} ) {
                $earliest_timenum_of{$linedir}
                  = min( $earliest_timenum_of{$linedir}, $earliest_timenum );
            }
            else {
                $earliest_timenum_of{$linedir} = $earliest_timenum;
            }
            push @objs_with_ids, { obj => $obj };
        }

    }

    foreach my $obj_with_id (@objs_with_ids) {
        next if exists $obj_with_id->{id};
        my $obj     = $obj_with_id->{obj};
        my $linedir = $obj->linedir;
        my $timenum = $earliest_timenum_of{$linedir};
        $obj_with_id->{id} = $obj->sortable_id_with_timenum($timenum);
    }

    @objs_with_ids = sort { $a->{id} cmp $b->{id} } @objs_with_ids;

    return map { $_->{obj} } @objs_with_ids;
} ## tidy end: sub skedsort

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

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
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

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

