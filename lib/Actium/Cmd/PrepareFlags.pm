package Actium::Cmd::PrepareFlags 0.011;

# Prepare artwork so that flags are built

use Actium;
use Actium::Flags;
use Actium::O::2DArray;

sub OPTIONS {
    return qw/actiumdb signup/;
}

sub START {
    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;
    my @argv     = $env->argv;

    my $assigncry = cry('Creating flag assignments');

    my $input_file = shift @argv;
    my ( $output_file, @stopids );

    if ( defined $input_file ) {
        my $stopidinput_cry = cry("Getting stop IDs from file $input_file");
        ( $output_file, undef ) = u::file_ext($input_file);
        $output_file .= '-assignments.txt';

        my $in_sheet = Actium::O::2DArray->new_from_file($input_file);
        @stopids = $in_sheet->col(0);
        @stopids = grep {/\A \d+ \z/sx} @stopids;
        $stopidinput_cry->d_ok;
    }
    else {
        my $db_cry = cry('Getting stop IDs from database');
        $db_cry->d_ok;
    }

    my $tabbed = Actium::Flags::flag_assignments_tabbed( $actiumdb, @stopids );

    unless ($tabbed) {
        $assigncry->d_error;
        return;
    }

    if ( defined $output_file ) {
        require File::Slurper;
        File::Slurper::write_text( $output_file, $tabbed );
    }
    else {
        my $signup = $env->signup;
        $signup->folder->file('flag_assignments.txt')->spew_utf8($tabbed);
    }

    $assigncry->done;
    return;

} ## tidy end: sub START

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

