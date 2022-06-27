package Octium::Cmd::ExcelCompare 0.019;

use Actium;
use File::Copy;

sub OPTIONS {
    return (
        'signup_with_old',
        {   spec    => 'phylum',
            default => 's',
            description =>
              'Phylum - type of file (s for skeds, p for place, etc.)',
        },
        {   spec        => 'collection',
            default     => 'received',
            description => 'Collection - collection of files '
              . '(received,  final, exceptions, etc.)',
        },
        {   spec        => 'format',
            default     => 'place',
            description => 'format - type of files (skeds, place, etc.)',
        },
    );
}

sub START {

    my @argv       = env->argv;
    my $excel_base = $argv[0];

    goto &HELP unless $excel_base;

    my $signup     = env->signup;
    my $phylum     = env->option('phylum');
    my $collection = env->option('collection');
    my $format     = env->option('format');

    my $new_folder = $signup->folder(
        phylum     => $phylum,
        collection => $collection,
        format     => $format
    );

    my $old_signup = env->oldsignup;
    my $old_folder = $old_signup->folder(
        phylum     => $phylum,
        collection => $collection,
        format     => $format
    );

    my $old_excel = $old_folder->make_filespec("$excel_base.xlsx");
    my $new_excel = $new_folder->make_filespec("$excel_base.xlsx");

    my $old_tag = $old_signup->signup;
    my $new_tag = $signup->signup;

    my $old_copyto = "/tmp/${old_tag}_$excel_base.xlsx";
    my $new_copyto = "/tmp/${new_tag}_$excel_base.xlsx";

    copy( $old_excel, $old_copyto ) or die $!;
    copy( $new_excel, $new_copyto ) or die $!;

    exec qq{/usr/bin/open  -a "Microsoft Excel"  $old_copyto $new_copyto};

}

sub HELP {
    say "excelcompare [options] _file_";
}

1;
