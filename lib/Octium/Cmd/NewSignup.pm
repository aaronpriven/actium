package Octium::Cmd::NewSignup 0.012;

# Prepares a new signup directory

use Actium;
use Octium;
use Octium::Import::Xhea;
use Archive::Zip;    ### DEP ###

sub OPTIONS {
    return (
        'newsignup',
        {   spec        => 'xhea=s',
            description => 'ZIP file containing Xhea export ',
            fallback    => $EMPTY,
        },
    );
}

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium newsignup -- prepare new signup directories and extract files
HELP

    return;

}

sub START {

    my $xheazip = env->option('xhea');

    my $cry = env->cry("Making signup and subdirectories");

    my $signup      = env->signup;
    my $hasi_folder = $signup->subfolder('hasi');
    my $xhea_folder = $signup->subfolder('xhea');

    $cry->done;

    if ($xheazip) {

        my $xcry = env->cry("Extracting XHEA files");

        unless ( -e $xheazip ) {
            die "Can't find xhea zip file $xheazip";
        }

        my $zipobj = Archive::Zip->new($xheazip);

        foreach my $member ( $zipobj->members ) {
            next if $member->isDirectory;

            my $filename = Octium::filename( $member->fileName );

            $xcry->over( $filename . '...' );
            my $filespec = $xhea_folder->make_filespec($filename);

            $member->extractToFileNamed("$filespec");

        }

        $xcry->over('');

        $xcry->done;

    }

    my %schcal_xhea_specs;

    if ( $xheazip or $xhea_folder->glob_plain_files('*.xml') ) {

        my $impcry = env->cry("Importing xhea files");

        my $tab_folder = $xhea_folder->subfolder('tab');

        my %xhea_import_specs = (
            signup      => $signup,
            xhea_folder => $xhea_folder,
            tab_folder  => $tab_folder,
            %schcal_xhea_specs,
        );

        Octium::Import::Xhea::xhea_import(%xhea_import_specs);

        $impcry->done;

        my $hasicry = env->cry("Creating HASI files from XHEA files");

        Octium::Import::Xhea::to_hasi( $tab_folder, $hasi_folder );

        $hasicry->done;

    }

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

