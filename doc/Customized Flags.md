Tools for Printing Customized Decals and Flags
==============================================

Aaron Priven, February 2015

Customized information on flags
-------------------------------

It's actually a bit misleading to say that information is "customized" for each stop. Actually, what happens is that a computer program (actium.pl flagspecs) identifies what information is relevant for each line at each stop.

The program determines, for each stop, what the destination should be and which connection or other icons should be shown, and then establishes a code for that combination of destination and icons.

That code is the line number followed by a hyphen and then a lowercase letter (or letters, but there aren't any lines with 27 combinations yet). So, the third combination for line 72 will be “72-c”.  Of course many stops have the same combinations.

A separate process creates artwork (in InDesign) for each of those combinations. The result is a series of art files, which can be used to create decals or which can be placed in an InDesign file to create full flags. (Generally, the term "decals" is used even when the line information is printed directly on the flag.) In practice, there are two sets of decal artwork: a "bleed" version that is used for printing decals, and a non-bleed version used for placement in InDesign.

Although it's easy enough to create a single flag in InDesign and have that printed, or send a single decal to be printed by the print shop, there are some helpful tools that are designed to make this process easier.

Printing custom decals
----------------------

Custom decals are sent to the print shop for printing. Some tools have been created to make it easier to count the number of decals to print, to prepare the print orders, and to prepare labels for envelopes

### decalcount

This tool is used to help count the number of decals to be printed. It takes an Excel file that is a list of stops, and creates a new Excel file that counts the decals to be printed.

The first task is to create the Excel file that is the list of stops. The first column should contain stop IDs.

The second column should contain a list of lines (separated by spaces). Only these lines will be included in the decal count. If this list is blank, then all lines at that stop will be included. It frequently happens that a flag has all the correct customized decals except for one or two lines. The second column makes it easy to make sure that only some of the decals for that stop are printed.

Other columns to the right are ignored by decalcount, but the idea was that the third column would contain stop descriptions and the fourth column would contain special instructions to the pole crew about this stop. (See "decallabels" below.)

|       | A      | B     | C           | D            |
| ----- | ------ | ----- | ----------- | ------------ |
| **1** | StopID | Lines | Description | Instructions |
| **2** | 50243  |       | West Midway Ave. at Orion St., Alameda, near side, going north | Replace 31-a "To Alameda Point" with 31-c "To Lexington Street, Alameda Point" |
| **3** | 50244  | 215   | Paseo Padre Pkwy. at Mission View Dr., Fremont, far side, going east | & Make sure 212 is whited out |
| **4** | 50663  |       | Martin Luther King Jr. Way at Virginia St., Berkeley, far side, going north | P |
| **5** | 50773  |       | Castro Valley Blvd. at Santa Maria Ave., Castro Valley, near side, going west |   |

Note that all the lines will be given for all the stops, except that only Line 215 will be printed for stop 50244.

This Excel file needs to be saved where it can be seen by the Rex server, such as on Bireme. To run the program, issue the command:

    actium.pl decalcount mydecals/workbook.xlsx

Of course, enter the name of the spreadsheet file you saved in place of "mydecals/workbook" above.

Once you do that, a new spreadsheet will be created, in the same folder and with the same name, with "-counted" added to the end (so, in this case, it would be "workbook-counted.xlsx" in the "mydecals" folder).

This will result in a new workbook, with two sheets: "Count" and "Stops."

#### Count sheet

Here is a sample "Count" sheet (the data shown here implies more stops were listed than given above):

|     | A     | B     | C     | D      |
| --- | ----- | ----- | ----- | ------ |
| 1   | Decal | Print | Stops | Adjust |
| 2   | 25-p  | 36    | 17    | 0      |
| 3   | 31-a  | 3     | 1     | 0      |
| 4   | 32-e  | 9     | 4     | 0      |
| 5   | 215-c | 5     | 2     | 0      |
|     |       | 53    |       |        |

For each decal, it provides a calculation of how many decals to print, based on the number of stops and the "adjust" number (which is added to the calculation, or if it is negative, subtracted). The last item in the column is the sum of the number of decals to print.

(The calculation is simply that it doubles the number of stops [since decals 
have to be printed twice for each stop, once on the front and once on the 
back], adds ten percent for spoilage, and rounds up. So if there's one stop, 
it will always be three decals; four stops, always nine decals; and so forth.  
Finally, it adds the value in the "Adjust" column.)

The formula on the Count sheet is "live", so that if you alter the number of stops, or the "adjust" number, it will also alter the number of decals to print. This is so that you can make manual overrides.  Perhaps a stop needs to be added at the last minute.

The "adjust" column is for other manual overrides. For example, one frequent occurrence is that we have a number of decals on hand that do not need to be reprinted. To print ten fewer decals, enter "-10" into the adjust column for the appropriate decal.

Normally, I send the first two columns with the print shop order. The calculation is in the second column specifically to make this process easier than if it were the last column.

#### Stops sheet

The Stops worksheet is just for checking that it did what you think it should have done. It will have the stop IDs and the decals that go with them:

|     | A       | B             | C           |
| --- | ------- | ------------- | ----------- |
| 1   | Stop ID | Decals to use | All decals  |
| 2   | 50243   | 31-a          | 31-a        |
| 3   | 50244   | 215-c         | 215-c 239-a |
| 4   | 50663   | 25-p          | 25-p        |
| 5   | 50773   | 32-e          | 32-e        |

Note that 52044 only has 215-c listed "to use", because line 215 was specified for stop 50244 in the first spreadsheet.

### zipdecals

The zipdecals tool is used to package up the appropriate decal artwork.  It is relatively simple. Issue the command:

    actium.pl zipdecals mydecals/workbook-counted.xlsx

It will create a new ZIP archive of all the decals listed in the first sheet of the specified workbook. It will save it to a file in the same folder as the worksheet, with a name that's the same as the worksheet (except that it will remove "-counted" and put the proper extension on). In this case, that would be "workbook.zip" .

### decallabels

The decallabels tool is used in the process of making labels which can be attached to envelopes, suitable for the pole crew's use. It creates a spreadsheet of label texts, which is designed to be copied and placed into a Word document that has labels.

The labels that are created contain the stop ID, an abbreviated stop description, and a set of instructions to the pole crew. What the instructions say depends on the input file.

#### Input file

The decallabels program reads the same file that was used in decalcount.

    | A      | B     | C   | D   
--- | ------ | ----- | --- | ---
1   | StopID | Lines | Description | Instructions
2   | 50243  |       | West Midway Ave. at Orion St., Alameda, near side, going north | Replace 31-a "To Alameda Point" with 31-c "To Lexington Street, Alameda Point"
3   | 50244  | 215   | Paseo Padre Pkwy. at Mission View Dr., Fremont, far side, going east | & Make sure 212 is whited out
4   | 50663  |       | Martin Luther King Jr. Way at Virginia St., Berkeley, far side, going north | P
5   | 50773  |       | Castro Valley Blvd. at Santa Maria Ave., Castro Valley, near side, going west |

The decallabels program uses the same first two columns as decalcount:  The first column should contain stop IDs, and the second should contain a list of lines (separated by spaces), where only these lines will have decals created for them. If this list is blank, then all lines at that stop will be included.

The third column is intended to contain a stop description (although the label program doesn't use this). The fourth column contains special instructions to the pole crew.

#### Instructions

The last part of the label contains special instructions to the pole crew. What, specifically, they contain depends on the contents of the fourth column.

- If the fourth column is blank, the instructions will say "Replace generic decals with \<list of decals\>", that is to say, it includes the list of decals for this stop. If "Lines" is not blank, then it adds "Leave other decals." Note that this list will not include 600-series lines.

- If the last column begins with an ampersand ("&"), it will contain the same text as above, but any remaining instructions will be added to the end.

- If the last column is just the letter "P", it just says "Place decals <list of decals> on the flag." This list, unlike the one if the last column is blank, will include 600-series lines.

- If the last column has anything else, that text is used for the instructions.

#### Output file

The output file is an Excel spreadsheet with three columns. The first one and third one contain the labels; the second one is empty. (Actually it has a blank space in each cell.) This is because when Word creates a label template of the type we normally use, it creates a table with three cells, where the middle cell is just there to create space between columns.

To use it, first open Excel, and copy the first three cells in each row. Note how many rows you're copying.

Then open Word, and select "Labels" in the "Tools" menu. It will give a dialog box asking about details of the label. Pick a type of label such as 5161 (4" by 1") or 5162 (4" by 1.33"). (There should be two columns of labels with an empty column in the middle.)

Do not type anything into the box where the label content is located, but select "Full page of the same label" and click "OK."

It will create a single page of labels. If there were more rows in the Excel spreadsheet than are displayed on this page, create more rows by selecting "Insert → Rows Below" from the Table menu. (It is useful to type Command-Y to repeat this if necessary.) Keep inserting rows until there are as many rows in the label sheet as there were in the Excel document.

Then, and this is tricky, _by dragging from the top left cell, select all the cells in the table._ Word is very persnickety about the way it allows you to copy and paste, so (for example) selecting the whole table by clicking on the little box at the upper left will not work: Word will resize the table cells, which will screw up the label placement.

Then select Paste, and the cells will be pasted into the document. Note that if you select too many rows when you paste, the top rows will be repeated again at the bottom, filling out the empty cells.

You can then print the labels (select "Paper Feed: All Pages from Bypass Tray" from the "Paper Feed" section of the print dialog box to print out labels on the Toshiba copy machine by inserting them, face-down, in the bypass tray.)

Tools for custom flags
----------------------

### prepareflags

The prepareflags tool is used to create a list of which flags should be printed and what decals should be present.

There two ways to tell the program what flags to print: using the FileMaker database or using a separate list of stops in a file.

#### Specifying flags from a file

To use a list of stops in a file, create the file. It can be either a plain text file (with a file name ending in `.tsv`, `.tab`, or `.txt`), or an Excel `.xlsx` file.  The program will use anything in the first column that could be a stop ID as one, and ignore everything else.  (For plain text files, columns need to be separated by tabs. A plain text file with just Stop ID numbers should still work.)

#### Specifying flags from the database

The other way to specify what files are to be printed is to use data in the FileMaekr database. In the database, there is a checkbox "Print next run." It is located under the Flag tab, in the "Stops Neue" layout. 

The "Print next run" checkbox needs to be checked for those stops, and only those stops, that are to be printed. This box is located on the "Flag" tab of the Stops Neue layout.

#### Zeroing out the current stops

First, to make sure that no boxes are still checked from the last time flags were printed, go into Find mode, click the "print next run" box, and then perform the find by pressing the return key. This will display all the records where the box is checked. Turn them all off by clicking the box (so it is not checked) and then select "Replace field contents" from the Records menu. This will open up a little dialog box. Make sure “Replace with: ' ' ” (the empty string) is selected, and select "Replace." This will turn off all the pre-existing checkboxes.

Then, find the stops for the flags you want to print, and click the boxes for those flags.

#### Selecting the flag type

One reason to use the database to specify stops is that each flag must have a flag type selected in the database, or it won't be created. The flag type corresponds to the particular art template that will be used.

The flag type consists of a number, which represents the number of bus lines that can fit on the front of the flag (the number of boxes), followed by a letter suffix that indicates a variant on the usual flag. Current flag types are:

* 3, 4, 6, 8, 10: Typical flags, 19.5" wide by various heights depending on the number of decals. Almost all new flags printed should be one of these sizes.
* 5, 9: Flags that are very similar to the typical flags, but which are at odd heights. I created these to use up old metal that were cut to these sizes, but once that old metal is used up these heights should no longer be used.
* 2R, 4R, 6R,10R: These are regular flags, but with the 10.5 inch "Rapid" banner at the top. They should be used where the 1R or 72R are present.
* 2N, 3N, 4N, 5N, 6N: These are narrow flags, of old sizes created in order to re-use old metal (from 1990s-style flags). These should not be used except where old metal exists.
* 2D: This is the Dumbarton Express branded flag, to be used where Dumbarton Express branding is required.
* 7W: This flag is an extra wide flag, used where space on a pole is very limited (due to sharing a pole with other signs) and we can't use a typical size flag. This should only be used where absolutely necessary. (I believe at this writing there are exactly two in use.)
* 13W, 15W: These are extra wide flags used where there are more than ten bus lines at a single stop.

#### Running prepareflags

Issue the command (replacing "z00" with the current signup, of course):

    actium.pl prepareflags  -signup z00 /path/to/your_list_of_stops.txt

Of course, don't include the list of stops if you're using the checkboxes in
the file.

If you did specify a list of stops, the file "your_list_of_stops-assignments.txt" will be created in the folder where your list of stops was found. Otherwise, it will create the file flag\_assignments.txt in the signup folder. The flag assignments file is a plain text file that can be edited if desired.

### makeflags\_new.app

This is the Applescript program that creates the flag artwork.

Find the program (on Bireme in Actium/Applications). Double-click it to open it. It will open up a dialog box that allows you to choose a file. Choose the flag assignments file created from `actium.pl prepareflags`. InDesign will do a lot of work in the background creating the flags. It will write new InDesign files in Bireme/Actium/flagart/generated. The InDesign files have the same name as the original flag file (the size), with a date added to the name.

When makeflags\_new is done, it will put up a dialog box that says "Finished making flags."

Once the program is complete, you can look at the InDesign files it created. It's always good to check them for any obvious errors. Also, it is important to make sure that if trim lines or other features are requested by the AC Transit Print Shop or another sign manufacturer, that layers representing these are turned on.

### Save InDesign As EPS ask.app

This is the new program that saves the individual flags as EPS files. There are two ways to run it. If you double-click on it, it will save all the pages of the InDesign file you are currently editing as EPS files. Or, you can drag one or more InDesign files to the icon in the Finder, and it will do them all.

It will first ask you whether you want to leave any bleed around the edges (enter "0", since flag artwork has bleed built into it already). Then it will ask if you want to convert the text to outlines (which our print shop will request). It will then save a PDF of each of the InDesign files and then use Illustrator to save each of those PDF files as EPS files. It will save them in the folder "PRINT" in the same folder where the InDesign file was located.

Those EPS files can then be zipped and sent to the print shop.
