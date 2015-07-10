# Legacy Status of programs #

The Actium system has been developed, if one can call it that, since the year 2000.  In that time, there have been several stages of development. I'm trying to label each of the files with the stage they are from, in order to make it clear just how obsolete they are.

## Stage Zero ##

The very first versions of Actium were designed to run on Windows, and included a GUI front end to the flat file databases. This ended about 2002, and no complete programs remain in the code base that date from this period, but a few of them still have code that dates from this era.

## Stage One ##

This code inaugurated Actium as we know it today, using FileMaker Pro as the database, Adobe InDesign as the layout program, and various perl programs.  Programs written in this era read the schedule reports, rather than the Hastus Standard AVL data, for its input. There was no directory structure, and all libraries and binaries were combined in the same single directory.

This code has some very old style perl (global variables, bareword filehandles, code that does not pass "use warnings") and should be rewritten.

## Stage Two ##

In about 2006, when we started using the Hastus Standard AVL data, I decided to make a new start. I combined a number of helper routines into the Actium.pm module, and new programs occasionally used object-oriented techniques. Most of the "avl" programs are of this era.

A few of the modules in the Actium/ directory were created in this period.

## Stage Three ##

In late 2009 I decided again that a new start was necessary. I began keeping the system in version control, and decided that a single program should dispatch commands rather than creating a multiplicity of several different commands.

## Stage Four ##

Stages two and three were attempts to restart the programs, without integrating the older programs into the new code base. It is clear to me now that an incremental approach is going to be better than such a radical change. Thus, I moved all the files into the new version control structure, and decided that no matter how ugly the code was, it ought to be made public, so I moved the repository from my own server to Google Code.

The effort here is going to be incremental simplification of code, as well as documentation of the code and how to use it.