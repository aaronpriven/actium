# New Signup Procedures

Aaron Priven, June 2015

A lot has changed since I created the first version of this, in
August 2011.

I am documenting the procedures I am using for the June 2015 signup
as I go about doing it. So this should help anyone going about this
in the future. Including myself.

## 1. Run actium.pl newsignup

The program newsignup is intended to encapsulate as much as possible
of the routine work of creating a new signup.

````Shell
actium.pl newsignup -b /Volumes/Bireme/Actium/db –s z00 –x Z00.ZIP
````

The -s argument should be the name of the signup, which will be
created in the base directory (Actium/db).

In this document I will use "z00", but this is just a placeholder.
Most of the time signups are something like "f11" or "sp12" --  f,
w, sp, su = fall, winter, spring, summer followed by a two-digit
year – f11, su10, sp08. Actually the name is arbitrary and could
be anything. This is the "signup directory".

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

## 2. Import AVL files into Perl

Run the program "readavl". This takes the AVL files and processes
them into Perl data structures, so they can be more easily read by
the other programs that deal with the data.

    actium.pl storeavl -signup z00

## 3. Download a copy of the Actium database, for backup

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

## 4. Import stops into FileMaker

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

## 5. Import places into FileMaker

a) Go into the Places\_Neue layout in FileMaker. Display all records.

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

## 6. Copy timepointorder.txt

Copy the file timepointorder.txt from the previous signup directory
to the new one. For this imaginary signup, the previous signup
diretctory will be called "y00." It's usually the previous season,
of course.

This file determines the timepoint order for schedules where the computer has trouble figuring out ambiguities. Only a small number of schedules are actually included -- most, the computer figures out by itself, but sometimes you have a route where no single trip has all timepoints in common, and the computer can't know which ones go first.  If you have trips with timepoints Red, Blue, Green and other trips with timepoints Red, Yellow, Green, there's no way for the computer to know whether Yellow or Green should come first. Sometimes it doesn't matter, but other times it does.

## 7. Create "raw" schedule files

Run this program:

    avl2skeds.pl -si z00 -raw

This creates the "raw" schedule files in the directory rawskeds.  These raw schedules are what is used for comparing schedules from one signup to another. (The regular schedules in "skeds" have the exceptions copied over to them.)

## 8. Create the file comparing the signups

````Shell
    cd Actium/db
    diff y00/rawskeds z00/rawskeds >diffs/y00-z00.diff
````

This creates the "diff" file that includes the differences between the two sets of directories.

A simple explanation of how a "normal" diff file can be read is here:

<http://www.markusbe.com/2009/12/how-to-read-a-patch-or-diff-and-understand-its-structure-to-apply-it-manually/#how-to-read-a-normal-diff>

## 9. Analyze comparison and make report

Go through the diff file and write down the changes for the comparison report. Opening the diff file in vim is nice because the syntax checking tools autmatically colorize everything: the previous signup is orange (or blue, on a light background) and the new one is green (or something else if the settings are different from mine).

This is basically analysis. Sometimes the changes are clear from the context, such as when the times are just off a minute or three. Sometimes it is clear that it matches whatever Planning and Scheduling has told us about the changes, which is nice. Other times, it's a mystery. Because the rawskeds do not contain information about whether trips are school-day-only trips or not, if one trip is changing it is useful to check in the Crew Schedule reports (traditionally known as headway sheets, hence their placement in the "headways" directory) whether the trips being changed are school-day only.

I write these up and save them in a file such as diffs/y00-z00-comparison.doc and then send them around.

## 10. Create exceptional schedules

There are always some schedules that don't come out quite right from the scheduling system. The AVL data doesn't include information about school day only running, so all school trippers on regular lines have to be exceptions.  The scheduling system contains times for intermediate timepoints on Rapid lines, which need to be removed. Lollipop-shaped routes like B and F need to be rewritten so that when the same bus serves as the end of the eastbound trip and the beginning of the westbound trip, it appears on both schedules.

Create a new directory called "exceptions" under the signup directory.  Copy the old exceptions from the previous signup directory to it, unless you know from step #7 that the schedule has changed. If it has, you'll need to rewrite it again.

## 11. Create final schedule files

This involves running avl2skeds again:

    avl2skeds.pl -si z00

This re-runs the avl2skeds.pl program, only this time it includes the exceptions and creates the "skeds" directory where the skeds that are actually used are stored.

## 12. Ensure that the "Lines" table is up to date

This is a manual process to make sure that the "Lines" table has current lines and associated information.

## 13. Import updated stop data into FileMaker

a) Run the avl2stoplines.pl program

    avl2stoplines.pl -s z00

That creates the file stoplines.txt

b) Go into the Stops layout in FileMaker. Display all records.

c) Import stoplines.txt

Go to Import -> File and select "stoplines.txt". Check "Don't import first record (contains field names)" and then select "Arrange by: matching names".

Then check "Update matching records in found set" and click the arrow next to "h\_stp\_511\_id" so it becomes double-headed arrow. (Arrange By will change to "custom import order")

Click "Import."  On the "Import Options" box, click "Import" again (it doesn't matter whether "Perform auto-enter options" is checked).

## 14. Create effective date file

Create the file "effectivedate.txt" in the signup directory. This is a one-line file with the date the service change is effective. The easiest way is using the Unix shell

````Shell
echo "August 28, 2000" >effectivedate.txt
````

But of course you can also use a text editor.

## 15. Create point schedule files

a) Run the avl2points command:

    actium.pl avl2points -s z00

This creates the files that have the actual times in them, one for each stop.  They are in an intermediate format not intended to be printed.

b) Run the actium k2id command:

    actium.pl makepoints -s z00

At the end it will say something like "20 skipped signs because stop file not found." Each of these signs has an entry in the Signs table in the FileMaker database. It will probably be necessary to go through each one of those and figure out why the stop is no longer there.

## 16. Replace the "current" link

There is a symbolic link "current" in /Volumes/Bireme/actium/db that points to the current signup. Replace it.

````Shell
rm current
ln –s z00 current
````

## 17. Create web schedules

Run the tabskeds program:

    actium.pl tabskeds -s z00

This creates a bunch of tab files in the folder tabxchange . Send these to IS with a request that they be made the preview schedules effective of the effective date.  Usually I put them in a zip file called tabskeds.zip

````Shell
zip -r tabskeds tabxchange/
````

Then send that to the Help Desk with a request that it be made previews soon and active on the effective date.

## 18. Run timetable program and update timetables

See the separate make timetables document.

## 19. Create stops lists

a) create the stop lists in "slists"

    actium.pl avl2stoplists –s z00

b) create the comparison lists

    actium.pl comparestops –o y00 –s z00

That creates the comparestops.txt that has the added stops, removed stops, and changed lines for each changed stop. Open in Excel, save as .xlsx and distribute to interested parties.

## 20) Update destinations for Nextbus

Run the program

    actium.pl avl2patdest –s z00

It will create the file Actium/db/z00/nextbus-destinations.txt. Email this file to Nextbus.

## 21. Get zip codes for new stops

Run the program

    actium.pl zipcodes >~/Desktop/zipcodes.txt

It will create the file zipcodes.txt and save it on your desktop. Then, import the file into the Actium database.

In FileMaker, go to Import -> File and select zipcodes.txt from the desktop. Check "Don't import first record (contains field names)" and then select "Arrange by: matching names".

Then check "Update matching records in found set" and click the arrow next to "h\_stp\_511\_id" so it becomes a double-headed arrow. (Arrange By will change to "custom import order")

Click "Import."  On the "Import Options" box, click "Import" again (it doesn't matter whether "Perform auto-enter options" is checked).

## 22. Create KML export

Run the program

    actium.pl stops2kml <outputfile>

Replace "<outputfile>" with the name of the file, which should probably be something like "Z00-bystops.kml". Once it's done, copy that file where others can see it, such as to the District Public Share area.

## 23. Update Dumbarton Express website

(instructions to come)

##24. Update flag and decal specifications

(also instructions to come)
