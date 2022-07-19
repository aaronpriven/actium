on MakeBags(BagListAlias)
	
	set BagListFileSpec to BagListAlias as string
	
	set TemporaryPath to (POSIX path of (path to temporary items))
	
	set theMasterPage to "G-AC Go"
	--set theMasterPage to "F-Flex"
	
	set AppleScript's text item delimiters to ":"
	set BagFileName to last text item of BagListFileSpec
	
	set AppleScript's text item delimiters to "."
	set BagIDFileName to (((reverse of rest of reverse of text items of BagFileName) as string) & ".indd")
	
	global OriginalIDFile
	global NewIDFile
	
	set OriginalIDFile to POSIX file "/Users/Shared/Dropbox (AC_PubInfSys)/AC_PubInfSys Team Folder/Flags/Bags/Generated_bag_template_2019.indd"
	set NewIDFile to "Users:apriven:Dropbox (AC_PubInfSys):Actium:signups:sp20:compare:bags:" & BagIDFileName
	
	set BagListFile to open for access file BagListFileSpec
	set BagListLines to read BagListFile for (get eof BagListFile) using delimiter ASCII character 10 -- LF
	close access BagListFile
	
	set BagListLines to rest of BagListLines -- skip header line
	
	tell application "Adobe InDesign 2022"
		
		set myDocument to open OriginalIDFile without showing window
		--display dialog NewIDFile
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
	
end MakeBags




on overridetext(myLabel, myPage, myText)
	tell application "Adobe InDesign 2022"
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

on run {}
	
	set BagListAlias to choose file of type {"public.text"} without invisibles
	
	tell me to MakeBags(BagListAlias)
	
	beep
	display alert "Finished making bags." giving up after 10
	
end run

on open Lst
	
	tell application id "com.adobe.InDesign"
		repeat with zFile in Lst
			set BagListAlias to zFile as alias
			
			tell me to MakeBags(BagListAlias)
			
			
		end repeat
	end tell
	
	beep
	display alert "Finished making bags." giving up after 10
	
end open