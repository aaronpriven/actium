#!/usr/bin/env perl 
use strict;
use warnings;
use Actium::Env::CLI::Crier;

our $VERSION = 0.015;

my $crier = Actium::Env::CLI::Crier->new( { step => 3 } );

my $cry_config = $crier->cry("Updating Configuration");

my $cry_parameter = $crier->cry("System parameter updates");
my $cry_clock     = $crier->cry("CLOCK_UTC");
$cry_clock->ok;
my $cry_servers = $crier->cry("NTP Servers");
$cry_servers->ok;
my $cry_dns = $crier->cry("DNS Servers");
$cry_dns->warn;
$cry_parameter->done;

my $cry_app = $crier->cry("Application parameter settings");
my $cry_adm = $crier->cry("Administrative email contacts");
$cry_adm->error;
my $cry_hop = $crier->cry("Hop server settings");
$cry_hop->ok;
$cry_app->done;

my $cry_web = $crier->cry("Web server primary page");
$cry_web->ok;

my $cry_crontab = $crier->cry("Updating crontab jobs");
$cry_crontab->ok;

my $cry_restart = $crier->cry("Restarting web server");
$cry_restart->done;

$cry_config->done;

exit 0;
