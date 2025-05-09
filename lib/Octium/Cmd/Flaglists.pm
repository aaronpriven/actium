package Octium::Cmd::Flaglists 0.016;

use Actium;
use Octium;
use Octium::SkedCollection;

sub OPTIONS {
    return (
        qw/signup actiumdb/,
        {   spec        => 'collection=s',
            description => 'Collection under "s" (e.g., "final" or "received")',
            fallback    => 'final',
        },

    );
}

sub START {
    my $collection = Octium::SkedCollection::->load_storable(
        signup     => env->signup,
        collection => env->option('collection'),
    );

    $collection->output_skeds_flaglists( actiumdb => env->actiumdb );

}

1;

__END__

=encoding utf8

=head1 NAME

Octium::Cmd::FinalizeSkeds - CLI command to cook schedules

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

Combines received schedules (that come from XHEA or other files
exported from a scheduling system) with exceptional ones altered by a
person, and creates new finalized schedules.

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

