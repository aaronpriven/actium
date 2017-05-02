# Perl installation for Actium

Notes about perl installation via perlbrew: how it worked for me today 
(8/1/14). 

1. installed the FileMaker ODBC driver. 

2. installed ODBC Manager 

3. Created a "System DSN" for ActiumFM (fm54.triple8.net, ACTransit_Actium, 
etc. In "Language Options" unchecked automatic and checked utf-8 --
this might change later if unixodbc can support Unicode directly instead
of having to re-encode the results, as I have to currently). 
I think there were permissions issues here.

4. Installed perlbrew from perlbrew.pl

5. perlbrew install 5.20.0 -Accflags="-DPERL\_USE\_SAFE\_PUTENV" 

6. perlbrew install-cpanm

7. installed lots of modules with cpanm including DBI and all other 
relevant ones except DBD::ODBC. First I installed App::Ack, then ran 
the "get-modules" script in ~/bin, then installed the relevant modules.

8. installed homebrew.

9. installed unixodbc via homebrew.

10. the Homebrew ODBC home is /usr/local/Cellar/unixodbc/2.3.2. I replaced
the .ini fles in /usr/local/Cellar/unixodbc/2.3.2/etc with symlinks to the
system .ini files. (I wonder if I could have just changed the ODBCHOME 
environment variable to /usr/local/Cellar/unixodbc/2.3.2 before trying to
install DBD::ODBC? Oh well)

11. cpanm DBD::ODBC

So far, so good!

## notes as of July 28, 2015

There are a few test failures when installing modules.

* DBD::ODBC

That is solved by making sure the ODBC is installed properly, as above.

* Flickr::API2

Tests pass once a version of Mozilla::CA from 2012, rather than the current
version, is installed.

* LWP::Protocol::https

It fails a couple of tests trying to load the apache.org site. I think
these are due to changes at apache.org and not real problems with the module.
I force installed this (cpanm -f LWP::Protocol::https)

## notes as of May 1, 2017

* LWP::Protocol::https 

Now works as long as one installs a homebrew version of openssl first, 
and follows the instructions regarding adding items to environment variables
(including PATH).

* DateTime::Format::CLDR

There's some bug in either this or DateTime::TimeZone that makes it fail with
DateTime::TimeZone 2.10 or 2.11. I installed DateTime::TimeZone 2.09 and it 
passed.

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
