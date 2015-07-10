# At-stop schedule program #

Aaron Priven, Publications and Signage Administrator, AC Transit

August 29, 2011

AC Transit's current program of placing schedules at bus stops began in the year 2000, and has been evolving ever since.  The programs work well together to allow the very efficient production of a large number of schedule signs – currently over 1700. It is not currently in a form suitable for easy transplantation to another transit agency – the code is too specific to AC Transit and is not documented in a way that would allow easy implementation by someone not already familiar with the code. I created and maintain the system, so I have been able to work on it without much difficulty. However, we at AC Transit want to get the system to be usable by others as well.

## Agency Context ##

The at-stop schedule program does not exist on its own; it is operated by the Marketing and Community Relations department, receives schedule data from the AC Transit scheduling department ,and provides the printed materials to various installers.

Marketing and Community Relations Department

At-stop schedules and service information generally is only one of the Marketing  and Community Relations department's functions. Currently there are only two people who work on the at-stop schedules, and this is in addition to their other duties, which include oversight of the cartographic firm which maintains the system map, overseeing the public outreach for quarterly schedule changes, posting electronic notices and temporary signs for detours and other temporary service changes, overseeing work contracted by MTC to AC Transit to update and maintain signs at the MTC-designated connectivity hubs, and recently, preparing customized bus stop flags (metal overhead signs) for each stop, and creating PDF printable timetables for some lines in lieu of the timetables traditionally prepared by the Scheduling Department and the AC Transit Print Shop. (An additional half-time employee is dedicated primarily to updating the connectivity hub information and  working with the maintenance crew.)

The ability of such a small staff of people  to create and update the more than 1700 signs is testament to the power of the computer systems that have been created.

Scheduling Data

AC Transit uses the Hastus system to schedule its transit services. Data is provided to Marketing in two forms: a "Schedule Report" which  resembles a timetable, and a more complete export of the scheduling data called the "Hastus AVL Standard Export." (Describing this is outside the scope of this document, but , while differing in specifics, it resembles in general form the data given in the General Transit Feed Specification used by Google Transit. Unlike plain GTFS, it includes interpolated times for each stop; some agencies have extended GTFS to include this data but AC Transit has not.)

Historically, the Schedule Report was used as the primary basis of the schedules printed at stops, but this is no longer true. Currently, the Schedule Report is used only to differentiate school-day-only service from every-weekday service, and the Hastus AVL Standard Export is the primary data used to create the at-stop schedules.

Installation Crews

A crew of four maintenance employees is responsible for posting the schedules in the cases at the bus stops, in addition to their many other duties of installing and maintaining bus stop poles and signs. The bus stop maintenance workers currently report to Transportation Supervision. At this point, the main limitation to adding additional schedule signs is not the difficulty of producing them, but the need to have the limited number of bus stop maintenance workers change the schedules out during quarterly service changes, during the same period when they must make changes to the bus stop flags and add new stops for new routes.

AC Transit provides customized schedules not only in pole-mounted cases, but also at its bus shelters. One of the cities operates its own bus shelter program, and their public works department installs the shelter inserts. The other cities contract with Clear Channel Outdoor to provide advertising-supported bus shelters, and so Clear Channel's maintenance crews install the shelters in those cases.

## Components of the Actium System ##

Actium is the Marketing department's name for its system that works with schedule data. ("ACTium" for "AC Transit.") There are three basic components to the Actium system: a pair of FileMaker databases, a series of document files in Adobe InDesign, and a number of programs in the Perl lanugage. There are also some Applescript programs that work with the InDesign document files. Actium operates on Mac OS X 10.6.

FileMaker databases

Actium's FileMaker databases exist primarily to provide a convenient user interface to allow editing of data used by the Perl programs. There are a series of tables. Some, such as "Timepoints" or "Stops" contain information that is intended to augment the data from Scheduling; for example, timepoint and stop descriptions from Scheduling can be overridden (to improve the quality of the language or to reflect name changes). Also, there are tables with information on each sign, with information on where it is (which stop, if it's  at a stop, or a description if it's not, such as inside a BART station) and what last happened with it (we track when the signs are installed or removed, when we print the signs and when we survey them to check their condition).

A major purpose of the FileMaker database originally was to allow selection of the relevant timepoint from the schedule. Until we received interpolated time information from each stop via the Hastus Standard AVL export, we had to provide the times for the nearest previous timepoint rather than a time for that particular stop. We had to determine which line stopped at each stop and which timepoint of each schedule was the most appropriate to provide. The user interface for selecting the appropriate schedule for each route and then the timepoint for that stop was built in FileMaker. These days, timepoint selection is generally used only at signs not at bus stops (BART stations, primarily), but the capability remains.

The FileMaker data is exported into flat files for use by the Perl programs. Older programs use comma-separated value exports (FileMaker's "Merge" format). The newest ones use one of FileMaker's XML exports, which allows UTF-8 encoding.

Perl programs

Most of the functionality of the system exists in the Perl programs. The Perl code is now publicly available at Google Code: the URL is http://code.google.com/p/actium and anyone can look at it.

Unfortunately, it is not very readable at the moment. The code base goes back to 2000, and documentation for earlier code is sparse. Much of the recent work is better documented, but many of the older programs are still in use and have not yet been replaced.

In general, the process is that Marketing receives Hastus Standard AVL data from the Scheduling department. A program called "readavl" processes the Hastus data into Perl structures and stores them for later processing. Then, a series of other programs are used that read the FileMaker data and combine it with the Hastus data. "avl2skeds" creates tab-delimited text files containing the schedules, which are used by a number of other programs. One of those is  "makepoints," which uses the user-selected timepoints from FileMaker to create InDesign Tagged Text files containing the selected schedule data. That is the older style of point schedule. The newer style is made by"avl2points," which creates  a set of files, one for each stop, containing the times that buses pass that stop according to the Hastus data. "k2id" takes those files, combines it with the sign data from FileMaker, and creates an InDesign Text file in more or less the same form as the earlier "makepoints" data, only with interpolated times instead of times from the schedule.

Those are the primary programs that create at-stop schedules. There are also many other programs in the Google Code base, for doing such things as working with lists of stops for each route, creating customized flags for each stop, and creating printed timetables.

InDesign documents

Once makepoints and k2id have been run, the resultant InDesign Tagged Text files are placed into an InDesign file. Each page in the InDesign file corresponds to a single sign and, using the Numbering and Section options, is given the same page number as the sign number in the FileMaker database. The user navigates in InDesign to the page that corresponds to the sign he or she wishes to update, and runs an Applescript that places the item on the page. (Actually the Applescript has not yet been updated for our very recent upgrade to InDesign CS 5.5.) Most signs have a segment of the AC Transit system map (centered at that location, with a "you are here" marker) as well as other subsidiary items placed on the page such as fares (in one of nine different languages depending on the location), bicycle instructions, solicitations to subscribe to our e-mail update service, and so forth.  In general these have to be placed only once even if the scheduled times change.

Once the sign is ready we print it on a large-format inkjet printer. AC Transit has two, an Epson Stylus Pro 10600 purchased several years ago, and a newer Epson Stylus Pro 11880 purchased as part of our MTC work. Each uses Epson color-fast ink; we have not had problems with fading, even in color. We use a special resin-coated, UV- and water-resistant paper (Paper #4301 by Cartolith Group). This paper does not require lamination for outdoor use.

Since we have many different sizes of cases, we order the paper cut in rolls to size – different widths for each size of sign. The large-format inkjet printers have cutting blades that cut the roll paper at the page border. The upshot is that what comes out of the large-format inkjet printer is ready to post. We log the printing of the insert in our database, package them and send them to the appropriate installation crew.