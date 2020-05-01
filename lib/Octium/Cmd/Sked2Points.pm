package Octium::Cmd::Sked2Points 0.015;

use Actium;

use Octium::SkedCollection;
use Octium::Sked::StopSkedCollection;

sub OPTIONS {
    return qw/signup/,
      { spec => 'threshold=i',
        description =>
          'The number of ensuing stops that will be used to see if '
          . 'schedules should be combined. If zero, then will use all '
          . 'ensuing stops.',
        fallback => 15,
      },
      { spec => 'difference_fraction=f',
        description =>
          'The maximum fraction of trips that can have different times '
          . 'before schedules of the same line and different days '
          . 'can be combined. ',
        fallback => .15,
      },
      ;
}

sub START {

    my $signup = env->signup;

    my $skedcollection
      = Octium::SkedCollection->load_storable( collection => 'final' );

    \my @stopskedcollections = $skedcollection->stopskeds(
        threshold           => env->option('threshold'),
        difference_fraction => env->option('difference_fraction')
    );
    @stopskedcollections
      = Octium::Sked::StopSkedCollection->sorted(@stopskedcollections);

    my $stopskedfolder = $signup->subfolder( 'p', 'final', 'json' );

    my $cry = env->cry('Writing stop sked collections');
    for my $stopskedcollection (@stopskedcollections) {
        $stopskedcollection->store_bundled($stopskedfolder);
    }
    $cry->over($EMPTY);
    $cry->done;

}

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

