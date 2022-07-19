-- override library

on overridetext(myLabel, myPage, myText)
	tell application "Adobe InDesign 2022"
		set myMasterItem to item 1 of (all page items of applied master of myPage) whose label is myLabel
		
		try
			tell myMasterItem
				set myItem to override destination page myPage
			end tell
		on error eStr number eNum partial result rList from badObj to expectedType
			error "Couldn't override " & myLabel & ": " & eStr number eNum partial result rList from badObj to expectedType
		end try
		set contents of myItem to myText
	end tell
	return
end overridetext

on overridegraphic(myLabel, myPage, myFile)
	set FileURL to (myFile as «class furl»)
	tell application "Adobe InDesign 2022"
		
		set myMasterItem to item 1 of (all page items of applied master of myPage) whose label is myLabel
		tell myMasterItem
			set myItem to override destination page myPage
		end tell
		--tell myItem to place file myFile
		tell myItem to place FileURL
		return
	end tell
end overridegraphic

on override_graphic_if_exists(myLabel, myPage, myFile)
	tell application "Adobe InDesign 2022"
		set myMasterItems to (every item of all page items of applied master of myPage where label is myLabel)
		
		if ((count of myMasterItems) = 0) then
			return true
			
			--tell me to display notification "No items with label '" & myLabel & "' found." with title "Applescript"
		else
			set myMasterItem to item 1 of myMasterItems
			
			tell application "System Events"
				set ItExists to exists file (myFile)
			end tell
			if ItExists then
				
				my overridegraphic(myLabel, myPage, myFile)
				return true
			else
				tell me to display notification "File '" & myFile & "' not found." with title ((name of me))
				return false
			end if
			
			
		end if
		
	end tell
	
end override_graphic_if_exists