package Actium::Cmd::CompareSkeds 0.014;

use Actium;
use Actium::O::Folder;

use File::Copy ();
use List::Compare;
use File::Compare;

sub OPTIONS {
    return 'signup_with_old';
}

const my %WE_DAYS => ( WE => 1, SA => 1, SU => 1 );

my ( $old, $oldraw, $new, $newraw, $oldtempfolder, $newtempfolder,
    $diff_folder );

my ( @ssdiff_commands, @comparisons, @identical );

sub START {

    my ( $class, $env ) = @_;

    $new = $env->signup;
    my $newsignup = $new->signup;
    $newraw = $new->subfolder( 'rawskeds', { must_exist => 1 } );
    $old = $env->oldsignup;
    my $oldsignup = $old->signup;
    $oldraw = $old->subfolder( 'rawskeds', { must_exist => 1 } );

    my $tempfolder = Actium::O::Folder->new('/tmp/actium_compareskeds');
    $oldtempfolder = $tempfolder->subfolder($oldsignup);
    $newtempfolder = $tempfolder->subfolder($newsignup);

    my $base = $new->base;
    my $script_folder = Actium::O::Folder->new( $base, 'diffs' );
    $diff_folder
      = Actium::O::Folder->new( $base, 'diffs',
        "$oldsignup-$newsignup-ssdiff" );

    my $cry = cry("Comparing schedules: $oldsignup and $newsignup");

    my @oldfiles = $oldraw->glob_plain_files_nopath('*.txt');
    my @newfiles = $newraw->glob_plain_files_nopath('*.txt');

    my $lc = List::Compare::->new( \@oldfiles, \@newfiles );

    my @oldonly = $lc->get_Lonly;
    my @newonly = $lc->get_Ronly;

    my %is_new_only = map { $_ => 1 } @newonly;
    my %is_old_only = map { $_ => 1 } @oldonly;

    my @both = $lc->get_intersection;

    my %different;
    my $diffcount = 0;
    foreach my $filename (@both) {

        $cry->over($filename);
        my $oldspec = $oldraw->make_filespec($filename);
        my $newspec = $newraw->make_filespec($filename);
        my $result  = compare( $oldspec, $newspec );

        die "Error comparing $filename" if $result == -1;

        if ($result) {    # 1 if different
            $cry->prog('*');
            $different{$filename} = [ $oldspec, $newspec ];
            $diffcount++;

            _makessdiff($filename);

        }
        else {
            my ( $base, undef ) = u::file_ext($filename);
            push @identical, $base;
        }
    } ## tidy end: foreach my $filename (@both)
    $cry->over("Found $diffcount differences");

    $cry->d_ok;

    my $weekendcry = cry("Comparing weekend differences");

    my ( @old_to_delete, @new_to_delete );

    foreach my $filename (@oldonly) {
        my ( $skedid, $ext ) = u::file_ext($filename);
        my @components = split( /_/sx, $skedid );
        my $thesedays  = pop(@components);
        my $lgdir      = join( '_', @components );

        foreach my $days_to_test ( keys %WE_DAYS ) {
            my $file_to_test = "${lgdir}_$days_to_test.$ext";
            if ( exists $is_new_only{$file_to_test} ) {
                push @old_to_delete, $filename;
                push @new_to_delete, $file_to_test;
                _makessdiff( $filename, $file_to_test );
            }
        }
    }

    delete @is_old_only{@old_to_delete};
    delete @is_new_only{@new_to_delete};
    # makes sure, after all comparisons are run, that is shown.
    # those are hash slices

    $weekendcry->done;

    my $scriptfile = 'compareskeds.sh';
    my $script     = u::joinlf(@ssdiff_commands) . "\n";

    $script_folder->slurp_write( $script, $scriptfile );

    if (@comparisons) {
        say "\nComparisons:";
        _say_array(@comparisons);
    }

    if (@identical) {
        say "\nIdentical:";
        _say_array(@identical);
    }

    if ( scalar keys %is_old_only ) {
        say "\nDeleted schedules:";
        _say_array( keys %is_old_only );
    }

    if ( scalar keys %is_new_only ) {
        say "\nNew schedules:";
        _say_array( keys %is_new_only );
    }

    say "\nThe script is $scriptfile in $script_folder.";

} ## tidy end: sub START

sub _say_array {
    say scalar u::u_wrap( joinspace( u::sortbyline(@_) ) );
}

sub _makessdiff {
    my $oldfile = shift;
    my ( $oldbase, undef ) = u::file_ext($oldfile);

    my $newfile = shift;
    my ( $diffbase, $newbase );

    if ($newfile) {
        ( $newbase, undef ) = u::file_ext($newfile);
        $diffbase = "$oldbase-$newbase";
    }
    else {
        $newfile  = $oldfile;
        $newbase  = $oldbase;
        $diffbase = $oldbase;
    }

    my $oldtsv = "$oldbase.tsv";
    my $newtsv = "$newbase.tsv";

    my $oldspec    = $oldraw->make_filespec($oldfile);
    my $newspec    = $newraw->make_filespec($newfile);
    my $oldtsvspec = $oldtempfolder->make_filespec($oldtsv);
    my $newtsvspec = $newtempfolder->make_filespec($newtsv);

    my $diff_spec = $diff_folder->make_filespec("$diffbase.xlsx");

    File::Copy::copy( $oldspec, $oldtsvspec ) or die $OS_ERROR;
    File::Copy::copy( $newspec, $newtsvspec ) or die $OS_ERROR;

    my @commandwords = (
        'echo',            $diffbase,
        ';',               '/usr/local/bin/ssdiff',
        $oldtsvspec,       $newtsvspec,
        '--headerless',    "--output=$diff_spec",
        '--format=hilite', '--context=all',
    );

    push @ssdiff_commands, joinspace(@commandwords);
    push @comparisons,     $diffbase;

    return;
} ## tidy end: sub _makessdiff

sub joinspace {
    return join( $SPACE, map { $_ // $EMPTY } @_ );
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

