#!/ActivePerl/bin/perl
use strict;
use warnings;
use Actium::O::Crier;

our $VERSION = 0.005;

my $crier = Actium::O::Crier::->new(colorize=>1);

my $cry = $crier->cry("Contract to build house");
build_house();
$cry->done;

exit 0;

sub build_house {
    my $build_cry = $crier->cry ("Building house");
    sitework();
    shell();
    $build_cry->text( "
    Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vestibulum varius libero nec emitus. Mauris eget ipsum eget quam sodales ornare. Suspendisse nec nibh. Duis lobortis mi at augue. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.
"); 

# line feed at the top of text yields blank line, 
# but this was present in original Term::Emit sample

    mechanical();
    finish();
    $build_cry->done;
}

sub sitework {
    my $site_cry = $crier->cry();
    sleep 1;  #simulate doing something
    $site_cry->d_ok;
}


sub shell {
    my $shell_cry = $crier->cry();
    foundation();
    framing();
    roofing();
    $shell_cry->d_ok;
}

sub foundation {
    my $found_cry = $crier->cry();
    sleep 1;  #simulate doing something
    # Omit closing, will automatically be closed
    undef $found_cry;
}

sub framing {
    my $framing_cry = $crier->cry( "Now we do the framing task, which has a really long text title that should wrap nicely in the space we give it");
    sleep 1;  #simulate doing something
    $framing_cry->d_warn;
}

sub roofing {
    my $roof_cry = $crier->cry();
    sleep 1;  #simulate doing something
    $roof_cry->d_ok;
}

sub mechanical {
    my $mech_cry = $crier->cry( "The MECHANICAL task is also a lengthy one so this is a bunch of text that should also wrap");
    electrical();
    plumbing();
    hvac();
    $mech_cry->d_fail;
}

sub electrical {
    my $cry = $crier->cry();
    sleep 1;  #simulate doing something
    $cry->d_ok;
}

sub plumbing {
    my $cry = $crier->cry();
    sleep 1;  #simulate doing something
    $cry->d_ok;
}

sub hvac {
    my $cry = $crier->cry();
    sleep 1;  #simulate doing something
    $cry->d_ok;
}

sub finish {
    my $cry = $crier->cry();
    sleep 1;  #simulate doing something
    $cry->d_ok;
}
