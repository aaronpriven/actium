#!perl -w
use strict;
use warnings;
use Actium::O::Notify;

our $VERSION = 0.005;

my $n = Actium::O::Notify->new({step => 3});

sub emit {$n->note(@_)};

my $nf_config = $n->note("Updating Configuration");

  my $nf_parameter = $n->note ("System parameter updates");
    my $nf_clock = $n->note("CLOCK_UTC");
    $nf_clock->d_ok;
    my $nf_servers = $n->note( "NTP Servers");
    $nf_servers->d_ok;
    my $nf_dns = $n->note ("DNS Servers");
    $nf_dns->d_warn;
  $nf_parameter->done;

  my $nf_app = emit "Application parameter settings";
    my $nf_adm = emit "Administrative email contacts";
    $nf_adm->d_error;
    my $nf_hop = emit "Hop server settings";
    $nf_hop->d_ok;
  $nf_app->done;

  my $nf_web = emit "Web server primary page";
  $nf_web->d_ok;

  my $nf_crontab = emit "Updating crontab jobs";
  $nf_crontab->d_ok;

  my $nf_restart = emit "Restarting web server";
  $nf_restart->done;

exit 0;
