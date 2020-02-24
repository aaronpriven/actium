package Actium::Cmd::LineDescrip 0.011;

# Produces line descriptions from the Lines database
# Also produces transit hubs sheet, so should be renamed to something else.
# Possibly combine with slists2html

use Actium;

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
linedescrip. Creates line description file.
HELP

    return;
}

sub OPTIONS {
    return qw/actiumdb signup/;
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;

    my $signup = $env->signup;

    my $html_descrips = $actiumdb->line_descrip_html( { signup => $signup, } );

    my $outfh = $signup->open_write('line_descriptions.html');
    say $outfh $html_descrips;
    close $outfh or die $OS_ERROR;

    my $html_hubs = $actiumdb->lines_at_transit_hubs_html;

    my $outhubs = $signup->open_write('transithubs.html');
    say $outhubs $html_hubs;
    close $outhubs or die $OS_ERROR;

    \my %descrips_of_hubs_indesign
      = $actiumdb->descrips_of_transithubs_indesign( { signup => $signup } );

    my $line_descrip_folder = $signup->subfolder('line_descrip');

    $line_descrip_folder->write_files_from_hash( \%descrips_of_hubs_indesign,
        'Indesign Line Description', 'txt' );

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

