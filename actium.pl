#!/ActivePerl/bin/perl

# actium.pl - command-line access to Actium system

use FindBin qw($Bin);    ### DEP ###
use lib ($Bin);          ### DEP ###

use Actium::Preamble;
use Actium::Cmd;

our $VERSION = 0.010;

Actium::Cmd::run(
    {   flickr          => 'Flickr_Stops',
        dbexport        => 'ActiumDBExport',
        slists2html     => 'Slists2HTML',
        theaimport      => 'TheaImport',
        makebags        => 'MakeBags',
        time            => 'Time',
        ss              => 'StopSearch',
        iphoto_stops    => 'IPhoto_Stops',
        iph             => \'iphoto_stops',
        stopsearch      => \'ss',
        sqlite2tab      => 'SQLite2tab',
        flagspecs       => 'Flagspecs',
        timetables      => 'Timetables',
        tabula          => \'timetables',
        tabulae         => \'timetables',
        ems             => 'Ems',
        orderbytravel   => 'OrderByTravel',
        prepareflags    => 'PrepareFlags',
        adddescriptionf => 'AddDescriptionF',
        makepoints      => 'MakePoints',
        stops2kml       => 'Stops2KML',
        k2id            => \'makepoints',
        nearbyroutes    => 'NearbyRoutes',
        mr_import       => 'MRImport',
        mr_copy         => 'MRCopy',
        htmltables      => 'HTMLTables',
        linedescrip     => 'LineDescrip',
        decalcount      => 'DecalCount',
        decallabels     => 'DecalLabels',
        xheaimport      => 'XheaImport',
        xhea2hasi       => 'Xhea2Hasi',
        headwaytimes    => 'HeadwayTimes',
        zipdecals       => 'ZipDecals',
        zipcodes        => 'ZipCodes',
        crewlist        => 'CrewList',
        matrix          => 'TimetableMatrixText',
        newsignup       => 'NewSignup',

        # more to come
    }
);

# a reference is an alias, so tabulae => \'tabula' means if you type
# "tabulae" it will treat it as though you typed "tabula"

__END__
