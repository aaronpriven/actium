tell application "System Events"
	set RootVolume to name of startup disk
end tell
set BiremeFolder to RootVolume & ":Users:apriven:Alameda - Contra Costa Transit:PubInfSys - Documents:"
set ActiumFolder to RootVolume & ":Users:apriven:Alameda - Contra Costa Transit:PubInfSys - Documents:Actium:"
set currentsignuplibrary to (ActiumFolder & "Applications:current_signup.scpt")
set libraryURL to (currentsignuplibrary as «class furl»)
set current_library to load script file libraryURL

global Signup

tell current_library
	set Signup to current_signup()
end tell

set SignupFolder to ActiumFolder & "signups:" & Signup
--set SignupFolder to "livia:Documents:signups:" & Signup
set TimetableDataFolder to SignupFolder & ":timetables:pub-idtags:"
set IDFileFolder to SignupFolder & ":timetables:tableart:"

try
	tell application "System Events" to make new folder at (folder (SignupFolder & ":timetables")) with properties {name:"tableart"}
end try

set TimetableDataListFile to TimetableDataFolder & "_ttlist.txt"
set MapFolder to BiremeFolder & "Maps:Repository:_linesnames:"

set PixFolder to "/Users/apriven/Alameda - Contra Costa Transit/PubInfSys - Documents/PubTimetables/"

set OriginalIDFile to POSIX file (PixFolder & "TimetableMasters.indd")
set GenericShortpage to POSIX file (PixFolder & "GenericTwoThirdsText.indd")
set PlaceholderCoverFile to POSIX file (PixFolder & "PlaceholderCover.indd")
set PlaceholderMapFile to POSIX file (PixFolder & "PlaceholderMap.indd")

--set IDFileFolder to (ActiumFolder & "tableart:indd:")
set CoverPageFileFolder to (ActiumFolder & "tableart:CoverPages:")

set TimetableDataListFileHandle to open for access file TimetableDataListFile
set TimetableDataList to read TimetableDataListFileHandle for (get eof TimetableDataListFileHandle) using delimiter ASCII character 10
close access TimetableDataListFileHandle

tell AppleScript to set the text item delimiters to "	" -- tab

set ColumnNames to item 1 of TimetableDataList
set TimetableDataList to rest of TimetableDataList -- skip first entry, which are the columnnames

set TimetableList to {}
repeat with TimetableValueList in TimetableDataList
	set TimetableValues to the text items of TimetableValueList
	set end of TimetableList to item 1 of TimetableValues
end repeat

set chosenTimetables to choose from list TimetableList with title "Choose one or more timetables" with multiple selections allowed and empty selection allowed

if chosenTimetables is false or ((count of chosenTimetables) is 0) then
	display dialog "No timetables chosen. Program ending." buttons {"OK"} default button "OK"
	return
end if

tell application "Adobe InDesign 2022"
	set myRotateMatrix to make transformation matrix with properties {counterclockwise rotation angle:90}
	
	set userCrop to PDF crop of PDF place preferences -- get the user's current settings for safekeeping
	set PDF crop of PDF place preferences to crop media -- content, art, PDF, trim, bleed, media
	
end tell

repeat with TimetableValueList in TimetableDataList
	
	set TimetableValues to the text items of TimetableValueList
	
	set filename to item 1 of TimetableValues
	
	if chosenTimetables contains {filename} then
		
		set effectivedate to item 2 of TimetableValues
		set PagesToAdd to item 3 of TimetableValues
		set MapFile to item 4 of TimetableValues
		set LeaveCoverForMap to item 5 of TimetableValues
		set FirstMasterPage to item 6 of TimetableValues & "-Master"
		set hasshortpage to item 7 of TimetableValues
		set PortraitChars to (characters of item 8 of TimetableValues)
		
		tell application "Adobe InDesign 2022"
			set myDocument to open OriginalIDFile without showing window
			
			try -- only used to show window in the event of an error
				
				set NewIDFile to IDFileFolder & filename & "-" & effectivedate & ".indd"
				set myDocument to save myDocument to NewIDFile with force save
				
				set FirstPage to page 1 of myDocument
				set applied master of FirstPage to master spread named (FirstMasterPage) of myDocument
				
				set FirstPageFrameList to my overridetextgroup("LineFrame", "FinalFrame", FirstPage)
				set LineFrame to item 1 of FirstPageFrameList
				
				set DataFile to (TimetableDataFolder & filename & ".txt") as alias
				
				tell LineFrame to place DataFile without autoflowing
				
				--set CoverPageFile to (CoverPageFileFolder & filename & ".pdf")
				--tell application "System Events" to set coverExists to exists disk item CoverPageFile
				--if coverExists = false then set CoverPageFile to PlaceholderCoverFile
				--set CoverPageFile to CoverPageFile as alias
				set CoverPageFile to my getPdfOrPlaceholder(filename, CoverPageFileFolder, PlaceholderCoverFile)
				tell FirstPage to set CoverPageContent to (item 1 of (place CoverPageFile))
				set CoverRectangle to parent of (item 1 of CoverPageContent)
				set item layer of CoverRectangle to layer "CoverText" of myDocument
				move CoverRectangle to {"6.9583in", 0}
				
				set PreviousFinalFrame to item 2 of FirstPageFrameList
				
				set GroupList to {}
				
				repeat PagesToAdd times
					--repeat with PortraitCharacter in PortraitChars
					set newPage to my makeblankpage(myDocument, "L")
					
					set PageFrameList to my overridetextgroup("InitialFrame", "FinalFrame", newPage)
					set InitialFrame to item 1 of PageFrameList
					set FinalFrame to item 2 of PageFrameList
					set TextGroup to item 3 of PageFrameList
					set end of GroupList to TextGroup
					set next text frame of PreviousFinalFrame to InitialFrame
					set PreviousFinalFrame to FinalFrame
					
				end repeat
				
				repeat with PageOffset from 1 to PagesToAdd
					set PortraitCharacter to item PageOffset of PortraitChars
					set PortraitCharacter to PortraitCharacter as string
					-- I think if I don't do that it is a reference to "character x of PortraitChars" or something, 
					-- even though "class of PortraitCharacter" still says "text". Very confusing.
					
					if PortraitCharacter = "P" then
						set thisPage to page (PageOffset + 1) of myDocument
						set applied master of thisPage to master spread named "R-Rotate" of myDocument
						set thisGroup to item PageOffset of GroupList
						transform thisGroup in spread coordinates from center anchor with matrix myRotateMatrix
					end if
					
				end repeat
				
				
				set myTables to tables of parent story of LineFrame
				repeat with thisTable in myTables
					set myRow to row 1 of thisTable
					set HeightOfMyRow to height of myRow
					set height of myRow to HeightOfMyRow
				end repeat
				
				--set myRow to row 1 of table 1 of parent story of LineFrame
				--set HeightOfMyRow to height of myRow
				--set height of myRow to HeightOfMyRow
				(* you would think that wouldn't do anything, but for some reason InDesign has been importing tables and making the heights of a lot of rows 0 when displayed, and that resets it *)
				
				set mapPage to my makeblankpage(myDocument, "L")
				
				set mapFileAlias to my getPdfOrPlaceholder(MapFile, MapFolder, PlaceholderMapFile)
				tell mapPage to set MapContent to (item 1 of (place mapFileAlias))
				
				set mapBounds to geometric bounds of MapContent
				set mapHeight to item 3 of mapBounds
				set mapWidth to item 4 of mapBounds
				set myRectangle to parent of (item 1 of MapContent)
				set item layer of myRectangle to layer "Map" of myDocument
				move myRectangle to {"9pt", "9pt"}
				
				-- hasshortpage is 1 when there is text on the short page
				if hasshortpage ≠ "1" and mapHeight < 7.6 and mapWidth < 6.75 then
					move myRectangle to FirstPage
					move myRectangle to {"9pt", "9pt"}
					
					tell mapPage to delete
				else
					if hasshortpage ≠ "1" then
						tell FirstPage to place GenericShortpage
						-- place generic text on short page
					end if
					if (mapHeight > 7.6 and mapHeight < 10.1 and mapWidth < 7.6) then
						set applied master of mapPage to master spread named ("R-Rotate") of myDocument
						move myRectangle to {"9pt", "9pt"}
					end if
				end if
				
				save myDocument with force save
				
			on error s number i partial result p from f to t
				try
					tell myDocument to make window
				end try
				error s number i partial result p from f to t
			end try
			
			close myDocument
			
		end tell
		
	end if
	
end repeat

tell application "Adobe InDesign 2022" to set PDF crop of PDF place preferences to userCrop -- set the user's orignal setting back
--say "Done making timetables." without waiting until completion
display alert "Done making timetables." giving up after 10

on getPdfOrPlaceholder(theFileName, theFolder, thePlaceholder)
	set thefile to theFolder & theFileName & ".pdf"
	--display dialog thefile
	tell application "System Events" to set myExists to exists disk item thefile
	if myExists = false then set thefile to thePlaceholder
	--set thefile to thefile as alias
	set thefile to (thefile as «class furl»)
	return thefile
end getPdfOrPlaceholder

on makeblankpage(theDocument, PortraitCharacter)
	tell application "Adobe InDesign 2022"
		tell theDocument
			set blankPage to make page
			if false then
				--if PortraitCharacter = "P" then
				set applied master of blankPage to master spread named "R-Rotate" of theDocument
			else
				set applied master of blankPage to master spread named "B-Blank" of theDocument
			end if
		end tell
	end tell
	return blankPage
end makeblankpage

on overridetextgroup(myInitialLabel, myFinalLabel, myPage)
	tell application "Adobe InDesign 2022"
		set myMasterItem to item 1 of (all page items of applied master of myPage) whose label is myInitialLabel
		set myMasterGroup to parent of myMasterItem
		tell myMasterGroup
			--tell me to display dialog "about to override"
			
			set myTextGroup to override destination page myPage
			--tell me to display dialog "just overrode"
			
		end tell
		
		set myInitialFrame to (item 1 of (all page items of myTextGroup) whose label is myInitialLabel)
		set myFinalFrame to (item 1 of (all page items of myTextGroup) whose label is myFinalLabel)
		
	end tell
	return {myInitialFrame, myFinalFrame, myTextGroup}
end overridetextgroup




