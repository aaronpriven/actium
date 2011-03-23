#!/usr/bin/perl

# copies most recent files in . to the directory specified in the command line

# BUGS - not Y10K compliant. Tough

use strict;
use warnings;

use File::Glob(':glob');

chdir "/Volumes/Bireme/Maps/Schematics" if $ENV{'RUNNING_UNDER_AFFRUS'};

my $newdir = $ARGV[0] || "/tmp/copylatest";

mkdir $newdir or die "Can't make $newdir: $!"
   unless (-d $newdir);

use File::Find ();

my %validlines;

my $using_validlines = 0;

if ( -f "_validlines") {

   print "Using _validlines\n";
   open my $fh, '<' , "_validlines" or die "Can't open _validlines: $!";

   while (<$fh>) {
      chomp;
      $validlines{$_} = 1;
   }
   $using_validlines = 1;

}

use File::Basename(qw(fileparse));

use File::Copy;

my %latest_date_of;
my %latest_ver_of;

# for the convenience of &wanted calls, including -eval statements:
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

File::Find::find({wanted => \&wanted}, '.');

sub wanted {

    lstat($_);
    unless (-f _) {
        # print "\nDIRECTORY: $_\n\n";
        return;
    }
    
    return if /^\./;
    return unless /\.eps$/;
    
    my ($name, $path, $ext) = fileparse($_ , (qr{\.[^.]+}) );
        
    my ($lines_and_token, $date, $ver) = split (/-/ , $name, 3);
    
    return unless (not $using_validlines) or $validlines{$lines_and_token};
    
    if (! exists ($latest_date_of{$lines_and_token} ) # if it doesn't exist,
          or ($latest_date_of{$lines_and_token} lt $date)  # or the older date is earlier than the current date,
          or ($latest_ver_of {$lines_and_token} lt $ver )  # or the older version is earlier than the current version,
       ) {
       $latest_date_of{$lines_and_token} = $date;  # make the current one the real one and return
       $latest_ver_of{$lines_and_token} = $ver;
       return;
    }
    
    # so it exists, but has a less than or equal date.
    
    return if $latest_date_of{$lines_and_token} gt $date; 
    # if the old one is later than the current one, return

    return if $latest_ver_of{$lines_and_token} le $ver; 
    # if the old version is less than or equal to the current one, return

    # so the dates are the same but the version is later (ascii-wise)

    $latest_date_of{$lines_and_token} = $date;
    $latest_ver_of{$lines_and_token} = $ver;

}

my @files;

foreach my $lines_and_token (sort keys %latest_date_of) {
   $dir = $lines_and_token;
   $dir =~ s/=.*//;
   $dir =~ s/_/ /g;
   
   my $latestdate = $latest_date_of{$lines_and_token};
   my $latestver = $latest_ver_of{$lines_and_token};
   my $glob = "$dir/$lines_and_token-$latestdate-$latestver.*";
   
   @files = bsd_glob ($glob);
   
   foreach (@files) {
      my $newfile = $_;
      $newfile =~ s#.*/#$newdir/#;
      print "$_   $newfile\n";
      copy ($_ , $newfile);
   
   }   

}


