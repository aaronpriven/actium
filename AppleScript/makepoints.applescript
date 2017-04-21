set override_library to load script file "Bireme:Actium:Applications:override_library.scpt"

global Signup
global OriginalIDFileFolder
global NewIDPath

set ListFileSpec to choose file of type {"public.text"} without invisibles
set ListFileSpec to ListFileSpec as string

set AppleScript's text item delimiters to ":"
set ListFileName to last text item of ListFileSpec
set ListPath to (reverse of rest of reverse of (text items of ListFileSpec)) as text

set SignupPath to (reverse of rest of reverse of (text items of ListPath)) as text

set Signup to (last text item of SignupPath)
set IDPointPath to (SignupPath & ":" & "idpoints2016:")

set ListFile to open for access file ListFileSpec
set ListLines to read ListFile for (get eof ListFile) using delimiter ASCII character 10 -- LF
close access ListFile

local NewIDFolder

set AppleScript's text item delimiters to "."
set ListFileWords to text items of ListFileName
if (count of ListFileWords) is 2 then
	set NewIDFolder to Signup
else
	set NewIDFolder to Signup & "_" & item 2 of ListFileWords
end if


set OriginalIDFileFolder to (POSIX file "/Users/Shared/Dropbox (AC_PubInfSys)/AC_PubInfSys Team Folder/AtStopSchedules/") as text
set NewIDPath to "Bireme:Actium:signart2016:" & NewIDFolder
my EnsureFolderExists(NewIDPath)
set MapPath to "Bireme:Actium:signart2016:maps:export:"
local SignType, SignID

tell application "Adobe InDesign CC 2017"
	
	-- open first file
	
	set theFirstLine to item 1 of ListLines
	set myFields to (my tabfields(theFirstLine))
	
	set SignType to (item 2 of myFields)
	set NewFileAdditionAtStart to (item 3 of myFields)
	
	set myDocument to my openOriginalIDfile(SignType, NewFileAdditionAtStart)
	
	try -- only used to show InDesign document window in the event of an error
		set FirstSpreadAlreadyPresent to true
		set thePage to page -1 of myDocument
		
		set ListLines to rest of ListLines
		
		repeat with theLineItem in (ListLines)
			
			set theLine to contents of theLineItem
			set theLineFields to my tabfields(theLine)
			
			if ((item 1 of theLineFields) = "FILE") then
				
				-- close previous and open subsquent file
				close myDocument saving yes
				set FirstSpreadAlreadyPresent to true
				set SignType to (item 2 of theLineFields)
				set myDocument to my openOriginalIDfile(SignType, item 3 of theLineFields)
				set thePage to page -1 of myDocument
			else
				
				set SignID to first item of theLineFields
				set MastertoUse to second item of theLineFields
				
				if FirstSpreadAlreadyPresent then
					set FirstSpreadAlreadyPresent to false
				else
					tell myDocument
						set thePage to make page
					end tell
				end if
				
				
				--- below sets page number
				
				if true then
					
					set NewPageName to (name of thePage)
					if NewPageName ­ SignID then
						log NewPageName & "-" & SignID
						set SignIDInt to SignID as integer
						tell myDocument
							try
								set theSection to make section with properties {page start:thePage, page number start:SignIDInt}
							on error
								set ExtraPage to make page at end -- workaround for what I think is a bug
								set theSection to make section with properties {continue numbering:false, page start:thePage, page number start:SignIDInt}
								delete ExtraPage
								
							end try
							
						end tell
						
					end if
					
				end if
				
				--- end of what sets page number
				
				set applied master of thePage to master spread (MastertoUse & "-Master") of myDocument
				
				my override_and_place(thePage, IDPointPath & SignID & ".txt")
				
				tell override_library
					--overridetext("NonPrintingSignID", thePage, SignID)
					override_graphic_if_exists("MapFrame", thePage, (MapPath & SignType & ":" & SignID & ".pdf"))
				end tell
				
				
			end if
			
		end repeat
		
		close myDocument saving yes
		
		--try
	on error s number i partial result p from f to t
		try
			tell myDocument to make window
		end try
		error s number i partial result p from f to t
	end try
	
end tell

display notification "Completed making InDesign files from " & ListFileSpec with title "makepoints.app" sound name "Hero"

-- display alert "Finished making point schedules." giving up after 30

on openOriginalIDfile(OriginalIDFIle, AdditionalComponent)
	tell application "Adobe InDesign CC 2017"
		set OriginalIDFileSpec to OriginalIDFileFolder & OriginalIDFIle & ".indd"
		set myDocument to open OriginalIDFileSpec without showing window
		set NewIDFile to NewIDPath & ":" & OriginalIDFIle & "_" & Signup & "_" & AdditionalComponent & ".indd"
		set myDocument to save myDocument to NewIDFile with force save
		return myDocument
	end tell
end openOriginalIDfile

on override_and_place(myPage, myFile)
	tell application "Adobe InDesign CC 2017"
		
		tell applied master of myPage
			tell (first group whose label is "TextGroup")
				set myGroup to override destination page myPage
			end tell
		end tell
		
		tell myGroup
			set myItem to item 1 of (every page item whose label is "FirstHead")
			--tell item 1 of (every page item whose label is "FirstHead")
			tell myItem to place file myFile
		end tell
	end tell
	
	return
	
end override_and_place

on tabfields(myLine)
	tell AppleScript to set the text item delimiters to tab
	set myFields to text items of myLine
	return myFields
end tabfields

on EnsureFolderExists(theFolder)
	tell application "System Events"
		set ItExists to exists folder (theFolder)
		if (not ItExists) then
			set AppleScript's text item delimiters to ":"
			set EnclosingFolder to (reverse of rest of reverse of (text items of theFolder)) as text
			set theFolderName to (text item -1 of theFolder)
			
			make new folder at end of folder EnclosingFolder with properties {name:theFolderName}
		end if
		
	end tell
end EnsureFolderExists

--on overridetext(myLabel, myPage, myText)
--	tell application "Adobe InDesign CC 2015"
--		set myMasterItem to item 1 of (all page items of applied master of myPage) whose label is myLabel
--		
--		tell myMasterItem
--			set myItem to override destination page myPage
--		end tell
--		set contents of myItem to myText
--	end tell
--	return
--end overridetext 


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
