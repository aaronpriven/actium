# Using the Information Center Matrix

The Information Center Matrix is a tool used for packaging timetables to information centers.  The program `actium.pl matrix` turns the matrix into a text file containing a list of information centers and the number of timetables that should be packed for them.

The matrix itself is a simple Excel spreadsheet, with each row representing an information center and each column a timetable. If an entry is not blank in the row, it will put that timetable on the list for that information center.

Here's the top left part of the spreadsheet:

|                      | #    | 1 1R | 7  | 11 | 12 |
|----------------------|------|------|----|----|---|
| Output group         |      |   A  | A  |    |  B |
| **BART STATIONS**    |      |      |    |    |    |
| Richmond             | 100  |      |    |    |    |
| El Cerrito del Norte | 100  |      | X  |    |    |
| El Cerrito Plaza     | 75   |      |    |    |    |
| North Berkeley       | 75   |      |    |    |    |
| Downtown Berkeley    | 100  | 1.5  | X  |    |  X |

This shows that 100 Line 7 timetables should be sent to each of El Cerrito del Norte and Downtown Berkeley, and 100 Line 12 timetables should also be sent to Downtown Berkeley. It also shows that 150 Line 1/1R timetables should be sent to Downtown Berkeley.

## About the matrix

### Rows

The top two rows are treated specially by the program.

#### Timetable names

The first row contains is the names of the timetables, with multiple lines separated by spaces or slashes.  

#### Include in the list: Output groups

The second row controls whether this timetable will be included in the list or not. If the entry under this timetable is blank, it will not be included. If it is not blank, it will be included. Entries should not be blank in this row if the timetable was updated for this service change.

It is called "output group" because it is possible to specify different groups of timetables for output. The idea is that some timetables are ready earlier than others. For example, in the example matrix, the timetables for 1/1R and 7 will be ready first, while the timetable for Line 12 will be ready later.  The program knows that B comes after A, so it will put Downtown Berkeley in the list under group B, while El Cerrito del Norte will be put in the list under group A. This allows El Cerrito del Norte to be done now, while Downtown Berkeley has to wait until the Line 12 timetables come in.

If all the output groups are the same, then it just treats it as one big list and doesn't mark them in groups. It's possible to just mark everything that should be shipped with an X and it will just work.

#### Information center rows

The remaining rows represent the information centers and the timetables that should be shipped to them.

### Columns

#### Information Center Names

The first column has the names of the various information centers (libraries, train stations, etc.).

The information centers are broken into sections by section headers in the first column. (It knows it's a section header because section headers don't have a number in the second column.) 

If the section header has "BART" in it, it will put "BART" after the names of all the information centers in that section. This allows the information center to be given as "12th St." and the program knows to actually output "12th St. BART."

Similarly, if the section header has "LIBRARIES" in it, it will put "Library" after the names of all the information centers in that section.

Other section headers are just ignored.

#### Quantity to ship

The second column contains the quantity of each timetable to ship to that information center. In the example matrix, we would ship 100 of each timetable to Richmond, El Cerrito del Norte, and Downtown Berkeley BART stations, but only 75 of each timetable to El Cerrito Plaza and North Berkeley BART stations.

If the quantity is blank, the row is a section header.

#### Ship this timetable

The rest of the columns are entries representing whether a timetable should be shipped to that center. If an entry is not blank, it will put that timetable on the list for that information center.

If the entry is anything that is not a number, it will list the number of timetables in the second column. So in the example matrix, it will use 100 for the number of Line 7 timetables sent to Downtown Berkeley or El Cerrito del Norte.

If the entry is a number, that number will be multiplied by the quantity in the second row to get the final result. In the example, Line 1/1R at Downtown Berkeley is given as "1.5", so 1.5 times the number in the second row, or 150, will be listed.

## Running the program

To run the program, start a terminal session on the server and send the `actium.pl matrix` command. Typical usage would be:

````bash
cd "/Volumes/Bireme/Print projects/Public timetables/shipping"
actium.pl matrix Information_Center_Matrix.xlsx
````

That will result in two different files: *name*-counted.txt and *name*-ttlist.txt. The first part of the name will be the same as the matrix itself, so if the matrix is `Information_Center_Matrix.xlsx`, the files will be `Information_Center_Matrix-centers.txt` and `Information_Center_Matrix-ttlist.txt`.

### Centers file

The first one is `Information_Center_Matrix-centers.txt`. This contains the list of timetables for packaging. Copy and paste this into the "Your Timetable Mission" document to get a list of packaging tasks for people.

An example:

    El Cerrito del Norte BART. (Group A) Weight: _________________________
    100 of these timetables: 7 (total: 100)

    Downtown Berkeley BART. (Group B) Weight: _________________________
    These timetables: 100 each of 7 & 12. 150 each of 1/1R. (total: 250)


### List file

The second file is `Information_Center_Matrix-ttlist.txt`. This contains the same information as the other list, but listed by timetable instead of by center.

    Timetable for 1/1R:
    Downtown Berkeley BART: 150

    Timetable for 7:
    Downtown Berkeley BART: 100
    El Cerrito del Norte BART: 100



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
