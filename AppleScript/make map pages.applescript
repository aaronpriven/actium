set ListFileSpec to choose file of type {"public.text"} without invisibles
set ListFileSpec to ListFileSpec as string


set ListFile to open for access file ListFileSpec
set ListLines to read ListFile for (get eof ListFile) using delimiter ASCII character 10 -- LF
close access ListFile

set IDFileFolder to (POSIX file "/Users/apriven/Alameda - Contra Costa Transit/PubInfSys - Documents/Actium/signart2016/maps/") as text


tell application "Adobe InDesign 2022"
	
	set theFirstLine to item 1 of ListLines
	set myFields to (my tabfields(theFirstLine))
	set SignType to (item 2 of myFields)
	
	set IDFileSpec to IDFileFolder & SignType & ".indd"
	
	set myDocument to open IDFileSpec without showing window
	
	try
		
		
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
				set IDFileSpec to IDFileFolder & SignType & ".indd"
				set myDocument to open IDFileSpec without showing window
				
				set thePage to page -1 of myDocument
			else
				
				
				set SignID to first item of theLineFields
				
				if FirstSpreadAlreadyPresent then
					set FirstSpreadAlreadyPresent to false
				else
					tell myDocument
						set thePage to make page
					end tell
				end if
				
				set NewPageName to (name of thePage)
				if NewPageName ­ SignID then
					log NewPageName & "-" & SignID
					set SignIDInt to SignID as integer
					tell myDocument
						--try
						--	set theSection to make section with properties {page start:thePage, page number start:SignIDInt}
						--on error
						set ExtraPage to make page at end -- workaround for what I think is a bug
						set theSection to make section with properties {continue numbering:false, page start:thePage, page number start:SignIDInt}
						delete ExtraPage
						
						--end try
						
					end tell
				end if
				
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

on tabfields(myLine)
	tell AppleScript to set the text item delimiters to tab
	set myFields to text items of myLine
	return myFields
end tabfields