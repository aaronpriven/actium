package Octium::Cmd::ZipDecals 0.012;

# Creates a Zip archive of the relevant decals

use Actium;
use Octium;
use Octium::O::Folder;
use Spreadsheet::ParseXLSX;    ### DEP ###

use Archive::Zip qw(:ERROR_CODES);    ### DEP ###

const my $EPSFOLDER =>
  '/Users/Shared/Dropbox (AC_PubInfSys)/Actium/flagart/Decals/export_eps_bleed';

sub HELP { say "Make an archive of the decals in an Excel file." }

sub START {
    my $class = shift;

    my @argv = env->argv;

    my $filespec = shift @argv;
    die "No input file given" unless $filespec;

    my ( $folder, $filename ) = Octium::O::Folder->new_from_file($filespec);

    my $sheet  = $folder->load_sheet($filename);
    my @decals = Actium::sortbyline $sheet->col(0);

    my $zipobj = Archive::Zip->new();

    foreach my $decal (@decals) {
        next if ( !$decal and $decal ne '0' );
        next if $decal =~ /decal/i;
        my $zip_internal_filename = "${decal}_outl.eps";
        my $diskfile              = "$EPSFOLDER/$zip_internal_filename";

        die "Can't find file $diskfile" unless -e $diskfile;
        $zipobj->addFile( $diskfile, $zip_internal_filename );
    }

    my ( $zipfile, undef ) = Octium::file_ext($filename);
    $zipfile =~ s/-counted\z//i;
    $zipfile = "$zipfile-decals.zip";
    $zipfile =~ s/-decals-decals/-decals/i;

    my $result = $zipobj->writeToFileNamed($zipfile);
    die "Couldn't write zip file $zipfile"
      unless $result == AZ_OK;

    say "Decals written to $zipfile";

}    ## tidy end: sub START

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

