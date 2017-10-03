Box points - change point schedules from the columnar format to a box format, allowing for horizontal headers
as well as (maybe) less wasted space.

Skeds become typeset in tables.  Basic unit of layout is one cell wide by one cell tall. 
Cell is width and height of one time (e.g., "12:59a*" where * is a note character). 
Everything in the main part of the schedule (not location and smoking text) is part of one big
InDesign frame.

Each point sked has a header with line, days, dest, and a body with times, like now.  But arranged in a box.

Box can vary in height and width and still work:

    +---------------------+
    | 59                  | 2x5
    | Monday thru Friday  |
    | To Piedmont Ave.    |
    |                     |
    |  7:15a  12:15p      | 
    |  8:15a   1:15p      |
    |  9:15a   2:15p      |
    | 10:15a   3:15p      |
    | 11:15a              |
    +---------------------+

    +--------------------------+
    | 59   Monday thru Friday  | 3x3
    |      To Piedmont Ave.    |
    |                          |
    |  7:15a  10:15a  1:15p    |
    |  8:15a  11:15a  2:15p    |
    |  9:15a  12:15p  3:15p    |
    +--------------------------+

    +---------------------------------------+
    | 59   Monday thru Friday               | 5x2
    |      To Piedmont Ave.                 |
    |                                       |
    |  7:15a   9:15a  11:15a  1:15p   3:15p |
    |  8:15a  10:15a  12:15p  2:15p         |
    +---------------------------------------+

Headers take up different amounts of room (due to empty space at
right, and need to leave big space for line number) and will have
to be measured for length too. (Any text measurement will have to
be approximate using font metrics and a guess about how it will be
line-broken, since this can't be determined a priori without feeding
it through InDesign line break composer. Afterwards, script should
go through each table cell and repeatedly reduce point size by .25
pt until there is no overset.)

System should try to fit sked boxes in the smallest InDesign frame
available, while still retaining order of the lines and the aesthetic
part wherever possible.

For each sked box, it determines all potential valid sizes (from
minimum to maximum width -- too narrow, header lines can't be read;
too wide, it's odd to read the columns ordered down. My guess is 2
or 3 for min and 6 for max. Need to test appearance in layouts)

First time trying to fit, takes all skeds with the same line and
direction and treats them as a unit for fitting purposes.  If it
doesn't fit in the frame that way, it breaks it up and allows e.g.
putting Saturdays on the next column over from weekdays.

Fitting algorithm looks like this:

Try each possible width, from minimum to maximum.

For each possible column width, see how much room is left at the
end.  Keep adding boxes to the first column as long as the height
of the frame will accommodate the boxes.  Left over space at the
bottom is waste.

Use whichever first column has the least amount of waste, and then
go on and repeat with the second, third, etc. columns.

Check to make sure hasn't gone over size of frame. If has, ... 

one possibiity is to retry fitting with different sized columns
(e.g., backtrack). But may be very time-consuming and not often
produce results. (need to keep track of all possible widths, in
least-waste order, of each column.) not sure if it's worth doing.

Otherwise, first, split up linedir-sets into individual line-dir-dest sked boxes, and try again.

If *still* doesn't fit, go to next size frame (the master page with the next biggest area).

On very last frame only, rather than giving up and forcing use of larger or more signs, 
try reordering boxes and retrying fit to see if it makes a difference.

Once it fits, it saves the solution to the fit, and outputs InDesign tagged text to a file

(I looked into bin-packing algorithms; variable width of rectangles
makes them not easily applicable, and anyway, results are efficient
but ugly and not sure that's really desireable. One on CPAN is
Algorithm::BinPack::2D)

--

Rather than putting smoking and location texts in InDesign text file, put it in the pointlist, and have the
script check to see if frames with correct script labels exist before trying to put smoking and location in
the file. Avoids unnecessary location and smoking on TIDs, etc.

(Maybe put location as mandatory last box in table? Then will waste as little
room as possible)

--

More things

* Will always be a note column at far right. Minimum width of note column is always something (2 cells? 3
  cells?). Any fractional cell space should be added to note column. text in n ote column must be measured and, if not
  fit, width made larger. 

* Very frequent service noted by an inline note

    +--------------------------------------------+
    | 59   Monday thru Friday                    | 
    |      To Piedmont Ave.                      |
    |                                            |
    |  7:15a   8:05a   8:25a  ...                |
    |  _ and every 10 minutes or better until_   |
    |  7:15p   7:35p   8:15p  9:15p              |
    +--------------------------------------------+

Also need to measure note text of course and add to length

* Consider storing dual-signs (where we have two Oak11s or two R22s) as two-pages-on-a-spread masters, rather
than listing them as separate signs. Have to modify packing algorithm to accept two frames. Two-frame
algorithm should allow moving line-days-dir box sets between frames without regard to order 
(so frame 1 might have lines 1 and 10
while frame 2 has 6 and 20), but not allow breaking them apart betewen
frames -- don't want Sunday schedules on other sign from Saturday schedules.

* In any event, some templates have multiple boxes -- like the T24s with the area at the bottom -- need to work out
how to deal with that. 

* Think of visual ways to distinguish daily, weekday, weekend, saturday, sunday, and different directions if
found in same sign (or pair of signs)

* Adding the list of intermediate destinations and points of interest served by this stop. Want to do this, 
but don't want it to cost adding signs. (Was thinking this would be part of sked box, but of course shared 
between different schedules. 

* Rather than having W/S/S boxes be separate, should they be combined into one box?

    59 To whatever

    Weekdays   Saturdays   Sundays

How to show this without taking up extra room?  Many different possibilities here: separate columns, or 
separate areas one below the other, or even

    Weekdays     Saturdays
    ...          ...
                 Sundays

Can be best fit if substantially less service weekends...

Downside is, adds more possibilities for fitting, and I don't 
want to have radically different appearance on some pole schedules versus others.
