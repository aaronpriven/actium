#!/usr/bin/env perl

# actium.pl - command-line access to Actium system

use FindBin qw($Bin);    ### DEP ###
use lib ("$Bin/../lib"); ### DEP ###

use Actium::Preamble;
use Actium::O::Cmd;

our $VERSION = 0.011;

Actium::O::Cmd::->new(
    commandpath => $0,
    system_name => 'actium',
    subcommands => {
        ems           => 'Ems', 
        flickr        => 'Flickr_Stops', 
        frequency     => 'Frequency', 
        headwaytimes  => 'HeadwayTimes', 
        indd_encode   => 'InDesignEncode',
        pr_add_stop   => 'PRAddStop', 
        scratch       => 'Scratch', 
        sqlite2tab    => 'SQLite2tab', 
        tempsigns     => 'TempSigns',
        theaimport    => 'TheaImport', 
        time          => 'Time', 
        xhea2hasi     => 'Xhea2Hasi', 
    },
    argv => [ @ARGV ],
);

# a reference is an alias, so tabulae => \'tabula' means if you type
# "tabulae" it will treat it as though you typed "tabula"

__END__
