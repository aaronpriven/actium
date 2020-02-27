package Octium::Cmd::StopSearch 0.011;

# command-line utility to search for stps

use Octium;
use Octium::O::Folder;

sub OPTIONS {

    return ( 'actiumdb',
        [ 'tab', 'Uses tabs instead of spaces to separate text' ] );
}

my $divider;
const my $DEFAULT_DIVIDER => $SPACE x 2;

sub START {

    my ( $class, $env ) = @_;

    $env->be_quiet();

    my $actiumdb = $env->actiumdb;

    $divider = $env->option('tab') ? "\t" : $DEFAULT_DIVIDER;

    my @args = $env->argv;

    # split arguments by commas as well as spaces
    # (assumes we're not searching for commas...)
    @args = map { split /,/s } @args;

    if (@args) {
        foreach (@args) {
            my @rows = $actiumdb->search_ss($_);
            _display(@rows);
        }

        return;
    }
    else {

        say 'Enter a stop ID, phone ID, or pattern to match.';
        say 'Enter a blank line to quit.';

        require Term::ReadLine;    ### DEP ###

        my $term = Term::ReadLine->new('st.pl');
        $term->ornaments(1);
        my $prompt = 'st.pl >';
        while ( defined( $_ = $term->readline($prompt) ) ) {
            last if ( not $_ );
            my @rows = $actiumdb->search_ss($_);
            _display(@rows);
            say $EMPTY;
        }

        say 'Exiting.';

    }    ## tidy end: else [ if (@args) ]

    return;

}    ## tidy end: sub START

sub _display {

    my @rows = @_;

    foreach my $fields_r (@rows) {

        if ( not defined Octium::reftype($fields_r) ) {
            say "Unknown id $fields_r";
            next;
        }
        my $active = $fields_r->{p_active};

        print $fields_r->{h_stp_511_id}, $divider,
          $fields_r->{h_stp_identifier}, $divider;
        say( $active ? $EMPTY : '*', $fields_r->{c_description_full} );
    }

    return;
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

