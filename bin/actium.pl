#!/usr/bin/env perl

# actium.pl - command-line access to Actium system

use FindBin qw($Bin);    ### DEP ###
use lib ("$Bin/../lib"); ### DEP ###

use Actium::Preamble;
use Actium::Cmd;

our $VERSION = 0.011;

Actium::Cmd::run(
	commandpath => $0,
	system_name => 'actium',
	subcommands => {
		addfields     => 'AddFields',
		avl2patdest   => 'AVL2PatDest',
		avl2points    => 'AVL2Points',
		avl2skeds     => 'AVL2Skeds',
		avl2stoplines => 'AVL2StopLines',
		avl2stoplists => 'AVL2StopLists',
		bags2         => 'Bags2',
		bartskeds     => 'BARTSkeds',
		comparestops  => 'CompareStops',
		compareskeds  => 'CompareSkeds',
		crewlist      => 'CrewList',
		dbexport      => 'ActiumDBExport',
		decalcount    => 'DecalCount',
		decalcompare  => 'DecalCompare',
		decallabels   => 'DecalLabels',
		ems           => 'Ems',
		flagspecs     => 'Flagspecs',
		flickr        => 'Flickr_Stops',
		frequency     => 'Frequency',
		headwaytimes  => 'HeadwayTimes',
		htmltables    => 'HTMLTables',
		iph           => \'iphoto_stops',
		iphoto_stops  => 'IPhoto_Stops',
		k2id          => \'makepoints',
		linedescrip   => 'LineDescrip',
		linesbycity   => 'LinesByCity',
		makebags      => 'MakeBags',
		makepoints    => 'MakePoints',
		matrix        => 'TimetableMatrixText',
		mr_copy       => 'MRCopy',
		mr_import     => 'MRImport',
		nearbyroutes  => 'NearbyRoutes',
		newsignup     => 'NewSignup',
		orderbytravel => 'OrderByTravel',
		pr_add_stop   => 'PRAddStop',
		prepareflags  => 'PrepareFlags',
		storeavl      => 'StorableAVL',
		slists2html   => 'Slists2HTML',
		sqlite2tab    => 'SQLite2tab',
		stopsofline   => 'StopsOfEachLine',
		ss            => 'StopSearch',
		stops2kml     => 'Stops2KML',
		stopsearch    => \'ss',
		tabula        => \'timetables',
		tabulae       => \'timetables',
		tabskeds      => 'TabSkeds',
		theaimport    => 'TheaImport',
		time          => 'Time',
		timetables    => 'Timetables',
		xhea2hasi     => 'Xhea2Hasi',
		xheaimport    => 'XheaImport',
		zipcodes      => 'ZipCodes',
		zipdecals     => 'ZipDecals',

		# more to come
	},
);

# a reference is an alias, so tabulae => \'tabula' means if you type
# "tabulae" it will treat it as though you typed "tabula"

__END__
