set BagListFileSpec to choose file of type {"public.text"} without invisibles
set BagListFileSpec to BagListFileSpec as string

set TemporaryPath to (POSIX path of (path to temporary items))

set theMasterPage to "G-AC Go"
--set theMasterPage to "F-Flex"

set AppleScript's text item delimiters to ":"
set BagFileName to last text item of BagListFileSpec

set AppleScript's text item delimiters to "."
set BagIDFileName to (((reverse of rest of reverse of text items of BagFileName) as string) & ".indd")

global OriginalIDFile
global NewIDFile

set OriginalIDFile to POSIX file "/Users/Shared/Dropbox (AC_PubInfSys)/AC_PubInfSys Team Folder/Flags/Bags/Generated_bag_template_2016.indd"
set NewIDFile to "Bireme:Actium:flagart:bags:" & BagIDFileName

set BagListFile to open for access file BagListFileSpec
set BagListLines to read BagListFile for (get eof BagListFile) using delimiter ASCII character 10 -- LF
close access BagListFile

set BagListLines to rest of BagListLines -- skip header line

tell application "Adobe InDesign CC 2017"
	
	set myDocument to open OriginalIDFile without showing window
	set myDocument to save myDocument to NewIDFile with force save
	
	try -- only used to show InDesign document window in the event of an error
		set FirstSpreadAlreadyPresent to true
		
		set thecount to 0
		repeat with theLineItem in BagListLines
			
			set theLine to contents of theLineItem
			set theLineFields to my tabfields(theLine)
			
			set action to item 1 of theLineFields
			set phoneID to item 2 of theLineFields
			set mainbox to item 3 of theLineFields
			set instruction to item 4 of theLineFields
			
			set thecount to thecount + 1
			log thecount & ")  " & phoneID
			
			if FirstSpreadAlreadyPresent then
				set FirstSpreadAlreadyPresent to false
			else
				tell myDocument to make page
			end if
			
			set thePage to page -1 of myDocument
			
			set myMaster to master spread named (theMasterPage) of myDocument
			set applied master of thePage to myMaster
			
			my overridetext("StopID", thePage, phoneID)
			my overridetext("InstructionBox", thePage, instruction)
			
			
			set TemporaryFile to (TemporaryPath & phoneID & ".txt")
			
			tell me
				try
					set OutFH to open for access TemporaryFile with write permission
				on error
					display dialog "Can't open file for output"
					error s number i partial result p from f to t
				end try
				
				set eof OutFH to 0
				write "<ASCII-MAC>" & return & "<Version:6><FeatureSet:InDesign-Roman>" to OutFH
				write mainbox to OutFH
				close access OutFH
			end tell
			
			set myMasterItem to (item 1 of (all page items of applied master of thePage) whose label is "MainBox")
			tell myMasterItem
				set thisframe to override destination page thePage
			end tell
			
			tell thisframe to place POSIX file TemporaryFile
			
			repeat while overflows of thisframe
				
				set myStory to parent story of thisframe
				repeat with thisParagraphNum from 1 to (count of paragraphs of myStory)
					
					set myLeading to (leading of (paragraph thisParagraphNum of myStory))
					set mySize to (point size of (paragraph thisParagraphNum of myStory))
					set mySpaceAfter to (space after of (paragraph thisParagraphNum of myStory))
					set myParaShadingTop to (paragraph shading top offset of (paragraph thisParagraphNum of myStory))
					set myParaShadingBottom to (paragraph shading bottom offset of (paragraph thisParagraphNum of myStory))
					
					set myLeading to 0.98 * myLeading
					set mySize to 0.98 * mySize
					set mySpaceAfter to 0.98 * mySpaceAfter
					set myParaShadingTop to 0.98 * myParaShadingTop
					set myParaShadingBottom to 0.98 * myParaShadingBottom
					
					set leading of (paragraph thisParagraphNum of myStory) to myLeading
					set (point size of (paragraph thisParagraphNum of myStory)) to mySize
					set space after of (paragraph thisParagraphNum of myStory) to mySpaceAfter
					
					set (paragraph shading top offset of (paragraph thisParagraphNum of myStory)) to myParaShadingTop
					set (paragraph shading bottom offset of (paragraph thisParagraphNum of myStory)) to myParaShadingBottom
					
				end repeat
				
			end repeat
			
			if (action is equal to "RS") then
				
				set myMasterItem to (item 1 of (all page items of applied master of thePage) whose label is "RemoveBox")
				tell myMasterItem
					set myItem to override destination page thePage
				end tell
				
				set fill color of myItem to color "Pink" of myDocument
				
				
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
display alert "Finished making bags."

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

on tabfields(myLine)
	tell AppleScript to set the text item delimiters to tab
	set myFields to text items of myLine
	return myFields
end tabfields


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
