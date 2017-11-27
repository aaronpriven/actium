# New Signup Procedures

Aaron Priven, last modified Fall 2017

## Get files

There are three sets of files:

   1. The main XHEA export. This can be specified with -xhea in actium.pl newsignup
   2. The PlacePatterns.xml and xsd files which are usually separate. These need to be placed manually in the folder xhea under the signup folder.
   3. The school calendars. These need to be placed manually in the folder sch_cal under the signup folder.


## Run actium.pl newsignup

The program newsignup is intended to encapsulate as much as possible
of the routine work of creating a new signup.

````Shell
actium.pl newsignup -b /Volumes/Bireme/Actium/db –s z00 –x Z00.ZIP
````

The -s argument should be the name of the signup, which will be
created in the base folder (Actium/db).

In this document I will use "z00", but this is just a placeholder.
Most of the time signups are something like "f11" or "sp12" -- f,
w, sp, su = fall, winter, spring, summer followed by a two-digit
year – f11, su10, sp08. Actually the name is arbitrary and could
be anything. This is the "signup folder".

If present, the optional -x argument should be the name of the ZIP
file that contains the Xhea exports (the export files from Ajay).
XHEA originally stood for "XML Hastus Exports for Actium", but
really the exports are the format created for the AC Transit
Enterprise Database. That still begins with "A" so the acronym still
works.

This will take the XML files and convert them to tab-delimited text
files, which are easier to work with. Those wll be in the z00/xhea/tab
folder.

It will also create temporary Hastus Standard AVL files from the
XHEA data. 

## Download a copy of the Actium database, for backup

The FileMaker databases contain a lot of info that we enter that's
used to create the schedules. They are stored on an external server
at triple8.net.

As a precautionary measure, we download a copy of the Actium database
before we make the changes below.

a) Using a web browser, go to www.mytriple8.net

b) Log in. I am not putting the user name and password in a document
like this, but there is one, available on request.

c) Click on "FileMaker Hosting" under "Services"

d) One of the files is "ACTransit\_Actium.fmp12". Click the "Download"
button. A little box will appear saying "Downloading FileMaker
Database… zipping file." It will take a while to do that. Once it's
done, it will present you with a link that says "AC Transit\_Actium.fmp12
– click to download." Do that. It will save it in the Downloads
folder (or whatever you have set your web browser to do).

## Import stops into FileMaker

There are two files in the tab folder that should be imported into
FileMaker: stop\_with\_i.txt and place\_with\_i.txt. The "with\_i"
indicates that these tables have some additional fields added on
by the perl programs: all the fields beginning with i\_ in the
Places and Stops tables in FileMaker.

First, import the stops.

a) Go into the Stops\_Neue layout in FileMaker. Display all records.

b) import stop\_with\_i.txt

Go to Import -> File and select "stops\_with\_i.txt". Check "Don't
import first record (contains field names)" and then select "Arrange
by: matching names".

Then check "Update matching records in found set" and click the
arrow next to "h\_stp\_511\_id" so it becomes a double-headed arrow.
(Arrange By will change to "custom import order") Check "Add remaining
data as new records"

Click "Import."  On the "Import Options" box, click "Import" again
(it doesn't matter whether "Perform auto-enter options" is checked).

c) The last few entries displayed will consist of stops that are
newly imported, not just updated. Go through those and make sure
that the displayed names and connections are correct, to the best
of your knowledge.  The XHEA files have pretty much everything we
would want from Hastus, but still some things are imperfect, notably
direction of travel, which is not available in Hastus. In any event
we will still need to go through and check the connection information
and also the spellings of names.

Note that the "active" field will not have been updated yet.

## Get zip codes and work zones for new stops

Run the program

    actium.pl zipcodes >~/Desktop/zipcodes.txt

It will create the file zipcodes.txt and save it on your desktop. Then, import the file into the Actium database.

In FileMaker, go to Import -> File and select zipcodes.txt from the desktop. Check "Don't import first record (contains field names)" and then select "Arrange by: matching names".

Then check "Update matching records in found set" and click the arrow next to "h\_stp\_511\_id" so it becomes a double-headed arrow. (Arrange By will change to "custom import order")

Click "Import."  On the "Import Options" box, click "Import" again (it doesn't matter whether "Perform auto-enter options" is checked).

The stops with new zip codes will be showing. Those will also be the ones
without work zones. Go into Google Earth and find the locations of those stops.
Using the KML export from the previous signup, find the work zones of the 
nearest stops to the new one. Enter that workzone in the correct spot.

## Import places into FileMaker

a) Go into the Places layout in FileMaker. Display all records.

b) import place\_with\_i.txt

Go to Import -> File and select "places\_with\_i.txt". Check "Don't
import first record (contains field names)" and then select "Arrange
by: matching names".

Then check "Update matching records in found set" and click the
arrow next to h\_plc\_identifier" so it becomes a double-headed
arrow. (Arrange By will change to "custom import order") Check "Add
remaining data as new records"

Click "Import."  On the "Import Options" box, click "Import" again
(it doesn't matter whether "Perform auto-enter options" is checked).

c) The last few entries displayed will consist of places that are
newly imported, not just updated. Go through those and make sure
that they appear correct, to the best of your knowledge

## Import AVL files into Perl

Run the program "storeavl". This takes the AVL files and processes
them into Perl data structures, so they can be more easily read by
the other programs that deal with the data.

    actium.pl storeavl -signup z00

## Import stop lines into FileMaker

a) Run the avl2stoplines program

    actium.pl avl2stoplines -s z00

That creates the file stoplines.txt

b) Go into the Stops layout in FileMaker. Display all records.

c) Import stoplines.txt

Go to Import -> File and select "stoplines.txt". Check "Don't import first record (contains field names)" and then select "Arrange by: matching names".

Then check "Update matching records in found set" and click the arrow next to "h\_stp\_511\_id" so it becomes double-headed arrow. (Arrange By will change to "custom import order")

Click "Import."  On the "Import Options" box, click "Import" again (it doesn't matter whether "Perform auto-enter options" is checked).

## Create "raw" schedule files 

Run this program:

    actium.pl xhea2skeds -s z00

This creates the schedule files in the folder s. There are several types: Excel places (xlsx_p), Excel stops (xlsx_s), space-delimited, and memory dumps. The one that's actually used for reading is the Storable version, skeds.storable.

## Create the file comparing the signups

````Shell
    cd Actium/db
    diff y00/s/prehistorics z00/s/prehistorics >diffs/y00-z00.diff
````

This creates the "diff" file that includes the differences between the two sets of directories.

A simple explanation of how a "normal" diff file can be read is here:

<http://www.markusbe.com/2009/12/how-to-read-a-patch-or-diff-and-understand-its-structure-to-apply-it-manually/#how-to-read-a-normal-diff>

## Analyze comparison and make report

Go through the diff file and write down the changes for the comparison report. Opening the diff file in vim is nice because the syntax checking tools autmatically colorize everything: the previous signup is orange (or blue, on a light background) and the new one is green (or something else if the settings are different from mine).

This is basically analysis. Sometimes the changes are clear from the context, such as when the times are just off a minute or three. Sometimes it is clear that it matches whatever Planning and Scheduling has told us about the changes, which is nice. Other times, it's a mystery. Because the rawskeds do not contain information about whether trips are school-day-only trips or not, if one trip is changing it is useful to check in the Crew Schedule reports (traditionally known as headway sheets, hence their placement in the "headways" folder) whether the trips being changed are school-day only.

I write these up and save them in a file such as diffs/y00-z00-comparison.doc and then send them around.

## Create exceptional schedules

There are always some schedules that don't come out quite right from the
scheduling system.  The scheduling system contains times for
intermediate timepoints on headway-based schedules, which need to be
removed.  Lollipop-shaped routes need to be rewritten so that when the
same bus serves as the end of the eastbound trip and the beginning of
the westbound trip, it appears on both schedules.  Some lines (like LA)
have "opportunity trips" that show up as separate lines on the schedule,
though they are really continuations of the previous trips. 

Create a new folder called "exceptions" under "s" under the signup
folder.  Copy the old exceptions from the previous signup folder to it,
unless you know from step #7 that the schedule has changed. If it has,
you'll need to rewrite it again, presumably using as a starting point
the stop schedules output from the scheduling system (found in the
"received" folder under "s" in the signup folder).

Note that these are schedules for _stops_, so that each stop has to be
listed, with a time. Although this is not implemented yet, I plan to
allow "i" to be used to have the program interpolate times stops between
timepoints, and "f" to be used for flexible stops (on Flex lines).

At this time there is no way to delete an incoming schedule so it is not
used.

## Create final schedule files

This involves running the finalizeskeds program:

    actium.pl finalizeskeds -s z00 

This loads the received schedules, adds the exceptional schedules
(replacing these if necessary), and then sends the results to the
"final" folder under "s" in the signup folder.

## Ensure that the "Lines" and "Timetable" tables are up to date

This is a manual process to make sure that the "Lines" table has current
lines and associated information.

Importantly, all changed lines should have their Timetable Date updated.

## Create point schedule files

a) Run the avl2points command:

    actium.pl avl2points -s z00

This creates the files that have the actual times in them, one for each stop.  They are in an intermediate format not intended to be printed.

b) Run the actium k2id command:

    actium.pl makepoints -s z00

At the end it will say something like "20 skipped signs because stop file not found." Each of these signs has an entry in the Signs table in the FileMaker database. It will probably be necessary to go through each one of those and figure out why the stop is no longer there.

## Replace the "current" link

There is a symbolic link "current" in /Volumes/Bireme/actium/db that points to the current signup. Replace it.

````Shell
rm current
ln –s z00 current
````

## Create web schedules

Run the tabskeds program:

    actium.pl tabskeds -s z00

This creates a bunch of tab files in the folder tabxchange . Send these to IS with a request that they be made the preview schedules effective of the effective date.  Usually I put them in a zip file called tabskeds.zip

````Shell
zip -r tabskeds tabxchange/
````

Then send that to the Help Desk with a request that it be made previews soon and active on the effective date.

## Run timetable program and update timetables

See the separate make timetables document.

## Create stops lists

a) create the stop lists in "slists"

    actium.pl avl2stoplists –s z00

b) create the comparison lists

    actium.pl comparestops –o y00 –s z00

That creates the comparestops.txt that has the added stops, removed stops, and changed lines for each changed stop. Open in Excel, save as .xlsx and distribute to interested parties.

## Update destinations for Nextbus

Run the program

    actium.pl avl2patdest –s z00

It will create the file Actium/db/z00/nextbus-destinations.txt. Email this file to Nextbus.

## Update flag and decal specifications

(instructions to come)

## Create KML export

Run the program

    actium.pl stops2kml <outputfile>

Replace "<outputfile>" with the name of the file, which should probably be something like "Z00-bystops.kml". Once it's done, copy that file where others can see it, such as to the District Public Share area.

## Update Dumbarton Express website

(instructions to come)

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
