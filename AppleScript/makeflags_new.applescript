set FlagListFileSpec to choose file of type {"public.text"} without invisibles
set FlagListFileSpec to FlagListFileSpec as string

global OriginalIDFileFolder
global IDFileFolder

set OriginalIDFileFolder to (POSIX file "/Users/Shared/Dropbox (AC_PubInfSys)/AC_PubInfSys Team Folder/Flags/Flag Artwork" as string) & ":"
set IDFileFolder to "Bireme:Actium:flagart:generated:"
set EPSFileFolder to (POSIX file "/Volumes/Bireme/ACTium/flagart/Decals/export_eps" as string) & ":"
set FlagListFile to open for access file FlagListFileSpec
set FlaglistLines to read FlagListFile for (get eof FlagListFile) using delimiter ASCII character 10 -- LF
close access FlagListFile

tell application "Adobe InDesign CC 2017"
	
	-- open first file
	
	set theFirstLine to item 1 of FlaglistLines
	set OriginalIDFIle to (item 2 of my tabfields(theFirstLine))
	set myDocument to my openOriginalIDfile(OriginalIDFIle)
	
	try -- only used to show InDesign document window in the event of an error
		set FirstSpreadAlreadyPresent to true
		
		set FlaglistLines to rest of FlaglistLines
		
		repeat with theLineItem in FlaglistLines
			
			set theLine to contents of theLineItem
			set theLineFields to my tabfields(theLine)
			
			if ((item 1 of theLineFields) = "FILE") then
				-- close previous and open subsquent file
				close myDocument saving yes
				set OriginalIDFIle to second item of theLineFields
				set FirstSpreadAlreadyPresent to true
				set myDocument to my openOriginalIDfile(OriginalIDFIle)
			else
				
				set MastertoUse to first item of theLineFields
				set phoneID to item 2 of theLineFields
				set desc to item 3 of theLineFields
				set decalList to item 4 of theLineFields
				set decals to my spacefields(decalList)
				
				set EPSFileList to {}
				repeat with decal in decals
					set end of EPSFileList to EPSFileFolder & decal & ".eps"
				end repeat
				
				if FirstSpreadAlreadyPresent then
					set FirstSpreadAlreadyPresent to false
				else
					tell myDocument to make page
					tell myDocument to make page
				end if
				
				set FrontPage to page -1 of myDocument
				set BackPage to page -2 of myDocument
				
				set myMaster to master spread named (MastertoUse & "-Master") of myDocument
				set applied master of BackPage to myMaster
				set applied master of FrontPage to myMaster
				
				my overridetext("bStopID", BackPage, phoneID)
				my overridetext("fStopID", FrontPage, phoneID)
				my overridetext("Description", BackPage, phoneID & " Ñ " & desc)
				
				set thisBox to 0
				repeat with myEPS in EPSFileList
					set thisBox to thisBox + 1
					my overridegraphic("bbox" & thisBox, BackPage, myEPS)
					
					my overridegraphic("fbox" & thisBox, FrontPage, myEPS)
					
				end repeat
				
				
			end if
			
		end repeat
		
		close myDocument saving yes
		
	on error s number i partial result p from f to t
		try
			tell myDocument to make window
		end try
		error s number i partial result p from f to t
	end try
	
end tell

beep
display alert "Finished making flags."

-- ------------------------- handlers ----------------------------------

on hyphenDateString()
	set {year:y, month:m, day:d} to current date
	tell (y * 10000 + m * 100 + d) as string to text 1 thru 4 & "-" & text 5 thru 6 & "-" & text 7 thru 8
	-- http://macscripter.net/viewtopic.php?id=24737
	-- the last statement uses "result" as the implicit thing being told, apparently
end hyphenDateString

on openOriginalIDfile(OriginalIDFIle)
	tell application "Adobe InDesign CC 2017"
		
		set OriginalIDFileSpec to OriginalIDFileFolder & OriginalIDFIle & ".indd"
		set myDocument to open OriginalIDFileSpec without showing window
		set NewIDFile to IDFileFolder & OriginalIDFIle & "_" & (my hyphenDateString()) & ".indd"
		set myDocument to save myDocument to NewIDFile with force save
		return myDocument
	end tell
end openOriginalIDfile

on tabfields(myLine)
	tell AppleScript to set the text item delimiters to tab
	set myFields to text items of myLine
	return myFields
end tabfields

on spacefields(myLine)
	tell AppleScript to set the text item delimiters to space
	set myFields to text items of myLine
	return myFields
end spacefields

on overridetext(myLabel, myPage, myText)
	tell application "Adobe InDesign CC 2017"
		--set myMasterItem to page item myLabel of all page items of applied master of myPage
		set myMasterItem to item 1 of (all page items of applied master of myPage) whose label is myLabel
		
		tell myMasterItem
			set myItem to override destination page myPage
		end tell
		set contents of myItem to myText
	end tell
	return
end overridetext

on overridegraphic(myLabel, myPage, myEPS)
	tell application "Adobe InDesign CC 2017"
		--		set myMasterItem to page item myLabel of applied master of myPage
		
		set myMasterItem to item 1 of (all page items of applied master of myPage) whose label is myLabel
		tell myMasterItem
			set myItem to override destination page myPage
		end tell
		tell myItem to place file myEPS
		return
	end tell
end overridegraphic


(*

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 DESCRIPTION

A full description of the module and its features.

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.

*)
