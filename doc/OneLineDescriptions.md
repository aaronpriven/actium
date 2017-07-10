The Actium Programs

The system that is used to manipulate schedule data for marketing is called Actium. All the files are located on the Bireme hard drive in the directory Actium. The perl programs are supposed to be located in Bireme/Actium/bin. Actually I haven't been very good at separating a release version from a development version, so a number of the programs have mostly been used from my working copy on my laptop. This document describes the programs in that development area.

I also haven't been good at getting rid of old files. This describes everything, even obsolete files.

There is a Google Code repository (http://code.google.com/p/actium) that contains all the programs (and old versions), and also some other brief documentation.

There are a large number of different programs. This only describes the different main programs (invoked directly from the command line), not the library modules that are shared between commands or which are subsidiary to commands. These have the file extension .pl rather than the file extension .pm .

Some of the perl programs have further documentation inside them, which you can get at by running perldoc on them. Some other documentation is in Bireme/Actium/documentation

ExportAllData

This is a shell script, not a perl program. It is a shell wrapper for a simple Applescript that tells FileMaker Pro to run the "ExportAllData" script. It is the same as running that script from within FileMaker.

actium.pl

At one point I thought it was a good idea to have one command-line program that had subcommands for the various actium commands, rather than giving them all their own command line entries. I was inspired by the svn command line program, which has subcommands.

All the subcommands are modules under the Actium/Cmd folder.

> adddescriptionf => 'AddDescriptionF',

actium.pl adddescriptionf is a routine that takes a tab-delimited list of stops, where the first field in each column is a stop ID, and adds the DescriptionCityF field from the Stops.fp7 file (really, from the XML export) as the second field.

> flagspecs       => 'Flagspecs',

This is the program that creates the flag specifications it figures out from AVL data what flag decals need to exist and what flag decals should go on each stop. Very complicated, needs to be rewritten so it's not such spaghetti code.

> headways        => 'Headways',

An older program that creates sked files from the headway sheets. I'm not sure this is still working given changes to some of the modules that run it.

> k2id            => 'MakePoints',

This is the program that creates the indesign\_point files (the text files loaded into InDesign that make up the times for the at-stop schedules). This one is based on the times given for individual stops in the AVL files, rather than the old makepoints.pl program, which uses the times from the timepoints and uses the Skedspec table in Actium.fp7)

> makestoplists   => 'MakeStopLists',

Unfinished - a program to make stop lists from AVL data. To replace older programs such as avl2stoplists.pl

> mr\_coffee       => 'Joke' ,

Tony looked at mr\_copy and mr\_import and he decided he wanted mr\_coffee, so this displays an ASCII art picture of a cup.

> mr\_copy         => 'MRCopy' ,

Makes a copy of the latest maps in the map repository. See the map repository documentation.

> mr\_import       => 'MRImport',

Imports new fles into the maps repository. See the map repository documentation.

> nearbyroutes    => 'NearbyRoutes',

Takes an address, geocodes it using the Perl module Geo::Coder::US, and finds the nearest stops from the Stops XML export.

> orderbytravel   => 'OrderByTravel',

From the file given on the command line, creates a list of stops ordered by travel order -- traveling down first one bus line and then the next bus line until all the stops on the list are given, without repeating any. Useful for pole crew assignments and the like.

> patterns        => 'Patterns',

Another part of the partially-completed stop lists and route list programs. These are not actually used.

> slists2html     => 'Slists2HTML',

Uses the data in the db/slists folder to make stop lists suitable for posting on the web.

> tabula          => 'Tabula',

This is the program that takes the schedules and prepares the InDesign files for them, for the printed timetables and the full-schedule signs.

> theaimport      => 'TheaImport',

Not yet completed program that imports the THEA data and makes schedules out of it.  (I have already forgotten what THEA stands for and I made it up. This is the new data that Ajay has started to give me as Hastus exports).

> time            => 'Time',

Program that tests the Actium::Time module, converting time numbers (minutes since midnight, or if negative, before midnight) to the usual formats like "6:50p". Actium::Time is very flexible, possibly overly so

The other programs are mostly older.

allroutes.pl

Lists all linegroups and the routes in them, deriving this from the skeds files.

assignments-addnewsignup.pl

A program that takes flags/assignments.txt (the file that keeps track of what flags have been printed, or will be printed) and adds the new stops from the stoplines-dir program to it. Basically designed to update assignments.txt for each new signup

avl2flags.pl

Contrary to its name NOT the flag data program. It is a variant of avl2stoplines, which makes a list of stops and the flags that go with them. This is obsolete since the definition of what flags are unique is old (it assumes only loop routes have separate flag decals for each direction).

avl2patdest.pl

Takes the AVL data and creates the nextbus-destination file used by nextbus to display destinations on its web site.

avl2points.pl

avl2points reads the data written by readavl and turns it into  a list of times that buses pass each stop. It is saved in the directory "kpoints" in the directory for that signup. This is used by actium.pl k2id

avl2skeds.pl

The program that creates skeds files (Actium/db/f12/skeds) from the AVL data

avl2stoplines-dir.pl

Creates a list of stops from the AVL data. This one contains the directions as well as the lines. This is the one that is still used.

avl2stoplines.pl

Creates a list of stops from the AVL data, listing the lines that are served.

avl2stoplists.pl

Creates the stop lists in db/f12/slists from the AVL data.

avl2stopnames.pl

Takes the description field (provided by Scheduling) from the AVL data and cleans it up a bit. Obsolete since this is now done by the data manipulation in the Stops.fp7 database, and the fields DescriptionF or DescriptionCityF from there used instead.

avl2stops\_of\_each\_line.pl

avl2stops\_of\_each\_line reads the data written by readavl and turns it into a list of lines with the number of stops. It is saved in the file "stops\_of\_each\_line.txt" in the directory for that signup. Used to calculate the number of route decals needed in the inventory.

avl2tpimport.pl

avl2tpimort reads the data written by readavl.
It then outputs a list of timepoints suitable for import to FileMaker.

baglist4polecrew.pl

Takes the lists of service change bags (baglist.txt, baglist-add.txt baglist-rm.txt) and prepares them for presentation to the pole crew.

bags-adj.pl

A variant of bagtext.pl, which makes the service change bag text fles (loaded into Indesign) from the stop comparison list. I thin this must be obsolete; I can't remember what the differences are.

bagtext.pl

Makes the service change bag text fles (loaded into Indesign) from the stop comparison list.

blanktps.pl

Displays timepoitns that don't have names from the Timepoints table in Actium.fp7

cellpoints.pl

A completely obsolete program that makes text versions of all the skeds in /skeds for dumb cellphones or iPods or something that can only read text files. A test a long time ago. In fact I'm deleting this now, so you shouldn't even see it anymore except in the old code.google.com versions.

comparestops.pl

comparestops reads the data written by readavl.
It then assembles a list of stops and the routes that stop at each one for old and new signups. Finally, it saves a list of new, deleted, and changed stops.

crewlist.pl

Makes lists of service change bags for the pole crew.

decal\_compare.pl

Compares old and new decalspec.txt (output from actium.pl flagspecs) to see if new decals have been specified. A lot of the time differences between signups yield new decals that, really, should be caught in the exceptions and not create new decals.

decalpage.pl

Goes through a series of (non-outlined) EPS files exported from InDesign, and gives them the filename associated with the decal number. This is how decal 25-c gets the name 25-c.eps instead of whatever page number it has in the InDesign file

decalspec-assign.pl

The assignments.txt file has the print assignments for flags (which flags are part of which assignment to be printed). This program takes those assignments along with stop-decals.txt and creates assignments used by the Applescript program that generates flag artwork, to choose which flags are created.

decalspec-compare.pl

Compares old and new stop-decals.txt (output from actium.pl flagspecs) to see if stops have changed and need to have their decals updated. The name is wrong, should be stopdecals-compare.pl, oh well

exskeds.pl

This simple script allows two files of the same name to be opened up in Excel since Excel doesn't like to have two files of the same name opened at the same time.

first\_field\_compare.pl

Compares tab-delimited files. Reads the first one and keeps track of the lines, indexed by the first column. Then displays the line from the next files that corresponds to lines from the first file, where the first column is the same.

foldpages.pl

Takes headway sheet pages that are overly wide (if there are too many timepoints to fit on a single page) and merges them so they are really really wide but each trip is on its own line.

fullindex.pl

This regenerates the index files from the files in db/f12/skeds. Used to create files imported into Actium.fp7 (Skedidx and Skedtps) each signup.

idname.pl

prints the number needed to get a specific letter name in an Indesign page - a = 1, b = 2, … z = 26, aa = 27, ab = 28, etc.

iphoto\_stops.pl

Goes through the current selection in iPhoto, and geocodes the photos if they have a stop id, or adds a stop id if it only has a lat/long. I have to say I think this is pretty cool

linefinder.pl

Creates HTML file with the line descriptions for each line

linelist.pl

List active lines (from the Skedidx table in Actium.fp7)

linesbycity.pl

List each city and the lines that are found there, according to the Stops.fp7 exported data

makepoints.pl

Uses the Skedspec table in Actium.fp7 to create point schedule files to be imported into InDesign

makepreview.pl

Uses the epstool program to make high-resolution TIFF previews of EPS files.

map2jpeg.pl

Creates multiple resolution JPEG files of line maps

merge-stop-ids.pl

Takes an old and new assignments.txt file and merges the data together so it's on the same line

nearbyroutes.cgi

CGI version for the web of the NearbyRoutes routine, to allow web queries for the nearest stops to an address

nonotes.pl

Make a copy of the /skeds files without notes in them, so different sets of skeds files can be compared, some with and some without notes

notpnames.pl

Find sked files with timepoints that have no names

pat-directions.pl

Identify the last place (the destination) for each pattern. Pretty sure this isn't used right now

polelist.pl

A variant of crewlist.pl that creates lists of service change bags. Don't remember right now what all the differences are

readavl.pl

Takes the AVL files, reads them into Perl structures, and saves them out as a memory dump (using Storable). Almost all the avl2

&lt;whatever&gt;

 programs use these memory dumps, not the original AVL files.

schoolnotes.pl

Takes the notes for the school trips in the headway sheets and processes them so they are easier to read (putting them in proper case, replacing backslashes with slashes, etc.

sdsh.pl

Finds all the lines beginning SH or SD from the headway sheets

signslines.pl

> This program lists the signs and what lines are associated with each one in Skedspec table of Actium.fp7. Not too much uses Skedspec these days though

skedsize.pl

This program determines how big the schedules are, in timepoints wide by trips tall. Useful for figuring out timetable size

skippedids.pl

Identifies any sign IDs that aren't used in Signs table of Actium.fp7

slists2bagorder-as.pl
slists2bagorder-rs.pl
slists2bagorder.pl

slists2bagorder makes the order for bags (that is, listing stops by route in order of traversing that route) from the line.storable file. Same idea as actium.pl orderbytravel, only less general. Three separate programs, one for Added Stop bags (-as.pl), one for Removed Stops bags (-rs.pl), and one for changed stop bags (plain slists2bagorder.pl).

st.pl

A quick stop lookup program. Using SimpleStops.tab, looks up the stop (given a PhoneId, StopId, or portion of a description) and gives PhoneId, topId, description, and optionally latitude and longitude

tableclean.pl

Program to clean up exported Service CHange Charts and add links to the schedules

tablepoints.pl

An experimental program to create new format point schedules. Never completed

tabskeds.pl

This is the program that creates the "tab files" that are used in the
Designtek-era web schedules

temp.pl

Testing of thea-import routines

tpbyline.pl

This produces a cross-tabulation of line groups and timepoints. I don't remember why I wanted this... or why I wanted it in HTML...

xl2sked.pl

Excel for Mac outputs text files that use CR instead of LF as line boundaries, and which may have extra fields tacked on to the end which confuse the sked reading program. This truncates those.



## COPYRIGHT & LICENSE

Copyright 2011-2017

The Actium system is free software; you can redistribute it and/or
modify it under the terms of either:

* the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

* the Artistic License version 2.0.

This system is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
