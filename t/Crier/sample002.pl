#!perl -w
use strict;
use warnings;
use Actium::O::Crier;

our $VERSION = 0.005;

my $crier = Actium::O::Crier->new({step => 3});

sub emit {$crier->cry(@_)};

my $cry_config = $crier->cry("Updating Configuration");

  my $cry_parameter = $crier->cry ("System parameter updates");
    my $cry_clock = $crier->cry("CLOCK_UTC");
    $cry_clock->d_ok;
    my $cry_servers = $crier->cry( "NTP Servers");
    $cry_servers->d_ok;
    my $cry_dns = $crier->cry ("DNS Servers");
    $cry_dns->d_warn;
  $cry_parameter->done;

  my $cry_app = emit "Application parameter settings";
    my $cry_adm = emit "Administrative email contacts";
    $cry_adm->d_error;
    my $cry_hop = emit "Hop server settings";
    $cry_hop->d_ok;
  $cry_app->done;

  my $cry_web = emit "Web server primary page";
  $cry_web->d_ok;

  my $cry_crontab = emit "Updating crontab jobs";
  $cry_crontab->d_ok;

  my $cry_restart = emit "Restarting web server";
  $cry_restart->done;

exit 0;
