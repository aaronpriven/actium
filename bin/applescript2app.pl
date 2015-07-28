#!/usr/bin/env perl

use 5.022;
use warnings;
use English;

our $VERSION = 0.010;

my $apppath = '/Users/apriven/Dev/apps';
use File::Slurper('read_text');

for my $scriptfile (@ARGV) {

    my $appfile = ( $scriptfile =~ s/[.](?:applescript|scpt)\z/.app/rsx );
    # turn "foo.applescript" or "foo.scpt" into "foo.app"

    my $script = read_text($scriptfile);
    $script =~ s/\r/\n/gsx;

    $script = "script s\n$script\nend script\n"
      . qq{store script s in (POSIX file "$apppath/$appfile") replacing yes\n};
    say "=== $scriptfile ===";
    open my $osascript, '|-', 'osascript'
      or die $OS_ERROR;
    say $osascript $script;
    close $osascript or die $OS_ERROR;
}

__END__