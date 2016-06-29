package Actium::Cmd::CompareSkeds 0.010;

use 5.022;
use warnings;

use Actium::Preamble;
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
    say scalar u::u_wrap( u::joinspace( u::sortbyline(@_) ) );
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

    push @ssdiff_commands, u::joinspace(@commandwords);
    push @comparisons,     $diffbase;

    return;
} ## tidy end: sub _makessdiff

1;

__END__
