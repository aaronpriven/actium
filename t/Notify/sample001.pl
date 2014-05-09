#!/ActivePerl/bin/perl
use strict;
use warnings;
use Actium::O::Notify;

my $notifier = Actium::O::Notify::->new(colorize=>1);

my $notification = $notifier->notify("Contract to build house");
build_house();
$notification->done;

exit 0;

sub build_house {
    my $build_nf = $notifier->notify ("Building house");
    sitework();
    shell();
    $build_nf->text( "
    Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vestibulum varius libero nec emitus. Mauris eget ipsum eget quam sodales ornare. Suspendisse nec nibh. Duis lobortis mi at augue. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.
"); 

# line feed at the top of text yields blank line, 
# but this was present in original Term::Emit sample

    mechanical();
    finish();
    $build_nf->done;
}

sub sitework {
    my $site_nf = $notifier->notify();
    sleep 1;  #simulate doing something
    $site_nf->d_ok;
}


sub shell {
    my $shell_nf = $notifier->notify();
    foundation();
    framing();
    roofing();
    $shell_nf->d_ok;
}

sub foundation {
    my $found_nf = $notifier->notify();
    sleep 1;  #simulate doing something
    # Omit closing, will automatically be closed
    undef $found_nf;
}

sub framing {
    my $framing_nf = $notifier->notify( "Now we do the framing task, which has a really long text title that should wrap nicely in the space we give it");
    sleep 1;  #simulate doing something
    $framing_nf->d_warn;
}

sub roofing {
    my $roof_nf = $notifier->notify();
    sleep 1;  #simulate doing something
    $roof_nf->d_ok;
}

sub mechanical {
    my $mech_nf = $notifier->notify( "The MECHANICAL task is also a lengthy one so this is a bunch of text that should also wrap");
    electrical();
    plumbing();
    hvac();
    $mech_nf->d_fail;
}

sub electrical {
    my $nf = $notifier->notify();
    sleep 1;  #simulate doing something
    $nf->d_ok;
}

sub plumbing {
    my $nf = $notifier->notify();
    sleep 1;  #simulate doing something
    $nf->d_ok;
}

sub hvac {
    my $nf = $notifier->notify();
    sleep 1;  #simulate doing something
    $nf->d_ok;
}

sub finish {
    my $nf = $notifier->notify();
    sleep 1;  #simulate doing something
    $nf->d_ok;
}
