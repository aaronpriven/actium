# Point Schedules 2016

This is very rough documentation of how the 2016 point schedule
system works.  It works a lot like the flag system, much more so than like than the old point
schedule system.  The idea is that the program does as much as
possible -- laying out the columns of schedules and other information 
without a lot of human intervention. 

The idea is that almost all the time, nobody will need to do anything to
the generated point schedules. You'll run the program, do a quick check
just to be sure nothing got screwed up, and then print. It should take 
a lot less time than the old version.

### The programs

There are three programs that run the system.

* export_pointmaps.scpt

This is a program that exports the maps from InDesign to PDF.

* actium.pl makepoints

This is a perl program that combines the schedule data and the data from FileMaker and turns it into text files.

* makepoints.app

This is an Applescript program that places the exported PDF maps and the text files from actium.pl makepoints onto the templates, and saves them. Unlike the old system, the same files are not used again and again. A new point schedule file is made each time.

## Templates and sign types

The templates are stored in Pixelapse under "AtStopSchedules". There should be one InDesign document per sign type, named after that sign type: so "R22.indd" is the template for R22 signs, "CN.indd" the template for CN signs, etc.

Each template file has one or more master pages. Information on each master page has to be entered into the SignType table in the Actium database.

The perl program tries each point schedule on each master page of the correct sign type  to see if it will fit.  It looks at the master pages in alphabetical order: it will first try "R22-A", then "R22-AA", then "R22-AB", then "R22-B", etc., to see if that schedule will fit on that template. If it does, then it uses that template. 

So that master pages with the most entries should be later alphabetically. If master page "Z" has five columns and master page "Y" has six columns, and the columns are the same height, it will always use master page "Y".

Several items on the master pages are particularly important as the program uses them to place the information on each sign. Script labels are used to identify individual objects.  The script labels can be seen by selecting the object and then viewing the "Script label" palette in InDesign.

#### Columns of times and other text frames

Each master page needs to have a long series of threaded text frames, in the order given. 

1. Pairs of frames for each column: a header frame and a column frame. The number of columns and height in lines of each column needs to be entered into the SignType table in the Actium FileMaker database.

2. A box to display the words "Stop ID" and their Spanish and Chinese translations, and the stop ID itself. This is left blank when the sign is not at a stop (such as inside a BART station), but the box still needs to be present somewhere.

3. A box to display the legal code reference that goes with the "no smoking" notice.

4. The box with the location of this sign.

5. The side note boxes, where the effective date and footnotes are placed.

The side note boxes are last because there can be more than one side note box, and if it is other than last, it will interfere with the placement of the stop ID and no smoking frames.

The threaded text frames must be grouped in a single group. The group must have a script label of "TextGroup" and the first header box (the first frame of the threaded story) must have a script label of "FirstHead".

#### Other items

There are two other items that are placed.

* The map. At this point there can only be one map per sign. In addition, there can only be one *size* of map for each sign type.  The map frame must have a script label of "MapFrame".

This is optional; not every sign has a map.

* A non-printing stop ID. I thought it would be good to display the stop ID large on screen, but not have it printed out. This frame should have the "Nonprinting" box checked in the "Attributes" palette and have the script label "NonPrintingStopID".

## Actium database


### SignType

Currently, every master page has to have a separate SignType entry. Eventually, I will change this, but not today.

Each master page has a Signtype entry whose name is the signtype followed by an equals sign and the letter of the master page. So, "R22=A" is the signtype entry for the master page A in the R22 template. (These =A, =B entries should *not* be used in the Sign table, even though for now it will let you do that.) 

The letter can be anything, but it must match up the letter of the master page in the template file.  

The sign type table in the Actium database has some important fields that must be filled out for each master page.

* SignType

This should be the sign type followed by = and the master page letter.  "R22=A", "CN=B", etc. If a sign type has no sub types, it will not be generated.

* TallColumnNum, ShortColumnNum, TallColumnLines, ShortColumnLines

At the moment each master page can have two areas of schedules: a tall one and a short one. These entries should hold the number of columns and the height of that column in terms of the number of lines of times that fit there.  If there's only one area, the "short" entries should be left blank.

The perl program uses these entries to figure out whether the point schedule fits on this template. It tries to keep schedules on the same line together in the same area as much as it can. 

* StopIDsInAFile

This column is used to tell the perl program whether it should break this sign type into multiple files. We have something like 1300 R22s but only 12 T24s, so it makes sense to divide some and not others.

### Signs

Actually, nothing needs to change much with the Signs database, although it now uses the city to determine what the smoking text shoudld be. Also, the program can optionally generate only schedules where the status is "Needs Update."

### Cities

There is a new "SmokingText" field containing the legal code reference.

### i18n

This contains multilingual text. ("I18n" is an example of a newly geeky kind of acbbreviation: "internationalization" has 18 letters betwen the i and the n, hence "i18n". They also use "a11y" for "accessibility.")

At the moment, the way my perl stuff handles this is completely broken and needs to be redone, so it's probably best left alone for now.

## Maps

The maps are stored in the directory "Bireme:ACTium:signart2016:maps". 
At the moment, there is one InDesign file for each size, but there's no specific rule about this, it was just easier to set up that way.  Each file should have the signtype be everything before the first hyphen, underline, or equals sign, but you could have "R22_1-500.indd" and it would work fine. I think breaking up R22.indd with 1300 pages would be a good idea at some point.

Each page of the InDesign file is the map for the sign with that sign ID. The page number is the sign ID. 

The actual content could be anything. At the moment, they all have the maps copied over from the old signs. One difference is that a new You Are Here symbol is used -- the old one was in English and was terrible anyway. Currently there is a sort of map pin. I think this will be understood today in a way that it would not have been a decade ago when the old You Are Here symbol was created.

The program export_pointmaps.scpt exports all the pages in the file to a separate PDF file which is placed into each sign. Those exported files are located in "Bireme:Actium:signart2016:maps:export:[signtype]" and are called just the signnid and extension: "5.pdf" or whatever. 
For exporting one or two signs, it's just as easy to do manually, but for a bunch of signs, it's easier to start the script and go do something else while it finishes. 

(I tried having separate InDesign files, but it meant that one had to open each InDesign file individually whenever any of its components were updated.)

## Creating the schedule text files

The actium.pl makepoints program creates the schedule text files and two other files that are used.  Basic usage is:

    actium.pl makepoints -s signup
    
There are a number of useful things that can go on the command line that one should know. You can see them all by doing "actium.pl help makepoints", but here are the really useful ones:

* -update

The -update flag will have the program only create schedules for signs that have been labeled "Needs Update" in the Sign database.

* -type xxx

This flag will have the program only create schedules for a particular sign type.

* SignIDs

At the end of the command line, you can enter numbers to process only particular sign IDs. (This was actually always true.)

Each of these acts to remove signs that don't qualify, so you can specify more things to further limit them, so "-type CN -update" will only create those signs that are CN signs *and* are marked "Needs update." 

When you use any of these flags, a run name is created that is used as part of the folder names where the generated InDesign files are stored. You can override this using the "-name" flag. You can specify no run name by using "-name _".

The program will overwrite previously generated InDesign files with the same run name, so run names are important to avoid this.

Some examples:

    actium.pl makepoints -s signup

This will generate text files for all the schedule signs for this signup. There will be no run name.

    actium.pl makepoints -s signup -u
    
This will generate text files for the schedule signs for this signup that are marked "Needs Update." The name of this run will be "U".

    actium.pl makepoints -s signup 37 372 473
    
This will generate text files for signs 37, 372, and 473, assuming each of those are marked "Active." The name of this run will be "37\_372\_473".

    actium.pl makepoints -s signup -type T24 -u -name tuba
    
This will generate text files for signs marked "Needs Update" that are of type T24. The run name will be "tuba" (instead of "T24_U").

    actium.pl makepoints -s signup 2 -name _
    
This will generate a text file for sign 2. It will use no run name.

### Results

In addition to the InDesign point files, which are stored in the directory "idpoints2016", it also creates two files in the directory "pointlist". 

* pl.[runname].txt

This file is used as the input to the makepoints.app program.

If there is no run name, the file is just "pl.txt". 

* err.[runname]txt

This file contains errors that the script found when processing the database. The first column is the sign ID and the second is the error.

Generally, there are three kinds:

1. Stop 5xxxx not found

   A schedule for this stop was not found in the data. Either 
   this just changed, or it represents a stop on a line 
   that isn't always given to us in the data -- such as the
   Broadway Shuttle, Dumbarton Express, or (in summertime) 
   600-series routes.

2. Line x found in omit list but not in schedule data.

   This line was not found at the stop, but the Actium database
   has it in the omit list for this stop (the list of lines
   to be omitted when this sign is printed).
   
3. Couldn't fit in any [signtype] template

   This sign had so many columns that no template given can fit
   it. There's not an easy way of dealing wtih this at this
   point. The options are (a) have the pole crew put up
   more, or at least different, hardware, or (b) create a new
   master page that still fits this hardware but is tailored to
   this particular sign's needs.  This involves loading the 
   text file manually in some very large template, counting out
   the necessary columns and lengths, and then creating a new 
   master page with just the right number. Normally this would 
   then be put at the end alphabetically of the master pages 
   in that template, and once you put the number of columns and
   lines per column in the SignType table in FileMaker, the    
   program will find it next time.

If there is no run name, the file is just "err.txt". 

## Creating the InDesign files

This is a similar process to creating flags. Open up makepoints.app in Script Editor and click the triangular "run" button at the top. It will then prompt you for a text file. It is looking for the "pl.txt" file, or "pl.[runname].txt" file, in the "pointlist" directory of the current signup. Seelct it.

Once you select it, it will run for a while, creating a new series of InDesign files in a folder under "Bireme:Actium:signart2016" named after the signup and the run name. So if the signup is "su16" and the run name is "U", it will be "su16_U." Being able to change the run name manually, as well as it giving a run name automatically, makes it easy to tell it whether to overwrite the previously generated files or not.

It should all just work. It probably won't, because I probably made mistakes I don't know about yet. Sorry...

Each file is named something like "signtype\_signup\_range.indd". (Probably the signup doesn't need to be both in the folder and the file name, oh well.) For example, "CN\_su16\_1-2500.indd". At this point there's always a range even when it will always encompass all the signs.

## Opening the InDesign files and printing them

This should be much easier than previously. Because there can be many master pages in the templates and the program automatically choses between them, there should never be a need to place any new objects on the template or break up columns to make them fit better. The program just does it automatically. 

You will have to go through and check for a few things.

1. Do any of the boxes have too much text, overflowing their bounds? This can happen when the column header is long, as on "Clockwise loop to..." lines. Most likely this will show up as an error in the Preflight, but not necessarily.

2. Is the map present and correct? If not, it will need to be fixed and re-exported.

But the odds are pretty good that, just as it is, the pole schedule will be ready to printed. 
 



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
