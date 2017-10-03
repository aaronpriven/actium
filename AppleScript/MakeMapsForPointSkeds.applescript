set MapEnclosingFolder to "Bireme:Actium:signart2016:maps:"

set DuplicatePages to {}

tell application "Adobe InDesign CC 2017"
	
	set OldDocument to active document
	
	--try
	--set MapDocument to open document "Bireme:Actium:signart2016:maps:R22.indd" -- without showing window
	set MapDocument to document named "A_maps.indd"
	
	
	
	set AppleScript's text item delimiters to "-"
	set theName to name of OldDocument
	set SignType to text item 1 of theName
	
	--set MapFolder to MapEnclosingFolder & SignType
	--my EnsureFolderExists(MapFolder)
	
	set oldPages to pages of OldDocument
	
	--set ListOfPages to {"38", "432", "617", "643", "940", "944", "948", "1047", "1436", "1876", "1995", "2271"}
	
	repeat with oldPage in (oldPages)
		
		--- GET MAP FROM OLD DOCUMENT ---
		
		log (name of oldPage) as string
		
		--if ListOfPages contains name of oldPage then
		
		set theItems to page items of oldPage
		set OtherItems to {}
		set FoundMapFrame to false
		
		set FoundYAH to false
		set YAHCenter to {}
		
		repeat with theItem in theItems
			
			set FileName to my FileNameOfGraphic(theItem)
			
			if (FileName is equal to "North.eps" or FileName = "South.eps" or FileName = "Middle.eps" or FileName = "Full.eps") then
				set MapFrame to contents of theItem
				set FoundMapFrame to true
			else if FileName is equal to "you are here.ai" then
				set {yahY1, yahX1, yahY2, yahX2} to geometric bounds of theItem
				set FoundYAH to true
				set YAHCenter to {x:((yahX2 + yahX1) / 2), y:((yahY2 + yahY1) / 2)}
			else
				set end of OtherItems to theItem
			end if
			
		end repeat
		
		if FoundMapFrame then
			
			set oldStrokeWeight to stroke weight of MapFrame
			set stroke weight of MapFrame to 0
			
			set MapBounds to geometric bounds of MapFrame
			set {mapY1, mapX1, mapY2, mapX2} to MapBounds
			set myHeight to mapY2 - mapY1
			set myWidth to mapX2 - mapX1
			
			set SignID to name of oldPage
			local MapPage
			
			--- FIND PAGE OF MAP DOCUMENT --
			
			set searchValue to (SignID as integer)
			
			if searchValue > ((name of last page of MapDocument) as integer) then
				tell MapDocument
					set MapPage to make page at end
				end tell
			else
				set pagesToSearch to (pages of MapDocument)
				set {found, foundPageRef} to (my searchForPageNum:searchValue withValues:pagesToSearch)
				
				if found then
					set MapPage to contents of foundPageRef
					set end of DuplicatePages to SignID
				else
					
					log (document offset of contents of foundPageRef)
					set PreviousMapOffset to (document offset of contents of foundPageRef) - 1
					
					log PreviousMapOffset
					tell MapDocument
						set MapPage to (make page at after page PreviousMapOffset)
					end tell
				end if
				
			end if
			
			set NewPageName to (name of MapPage)
			if NewPageName ­ SignID then
				log NewPageName & "-" & SignID
				set SignIDInt to SignID as integer
				tell MapDocument
					try
						set theSection to make section with properties {page start:MapPage, page number start:SignIDInt}
					on error
						set ExtraPage to make page at end -- workaround for what I think is a bug
						set theSection to make section with properties {continue numbering:false, page start:MapPage, page number start:SignIDInt}
					end try
					
				end tell
				
			end if
			
			set (horizontal measurement units of view preferences of MapDocument) to (horizontal measurement units of view preferences of OldDocument)
			set (vertical measurement units of view preferences of MapDocument) to (vertical measurement units of view preferences of OldDocument)
			
			--resize MapPage in parent coordinates from top left anchor by replacing current dimensions with values {myWidth, myHeight}
			
			tell MapDocument
				set MapLayer to layer named "Map"
				set YAHLayer to layer named "You Are Here"
				set OtherLayer to layer named "Other"
			end tell
			
			--- DUPLICATE MAP --
			
			tell MapFrame
				set NewMapFrame to duplicate to MapPage
				set item layer of NewMapFrame to MapLayer
				set NewBounds to geometric bounds of NewMapFrame
				tell NewMapFrame to move to {0, 0}
			end tell
			
			set stroke weight of MapFrame to oldStrokeWeight
			
			-- PLACE YAH
			
			tell MapDocument
				
				tell MapPage
					set NewYAHImagePlaced to place POSIX file "/Users/Shared/Pixelapse/AtStopSchedules/Subsidiary/you are here.ai"
					
					tell item 1 of NewYAHImagePlaced
						tell transparency settings
							set properties of blending settings to {blend mode:darken, opacity:70.0}
						end tell
					end tell
					
				end tell
				set NewYAH to parent of item 1 of NewYAHImagePlaced
				
				set NewYahBounds to geometric bounds of NewYAH
				
				set {nyahY1, nyahX1, nyahY2, nyahX2} to NewYahBounds
				
				set NewYahWidth to (nyahX2 - nyahX1)
				set NewYahHeight to (nyahY2 - nyahY1)
				
				if FoundYAH then
					
					set NewYAHCenterX to ((x of YAHCenter) - mapX1)
					set NewYAHCenterY to ((y of YAHCenter) - mapY1)
					
					set nyahNewX to ((NewYAHCenterX) - (NewYahWidth / 2))
					set nyahNewY to ((NewYAHCenterY) - (NewYahHeight))
					
				else
					
					set nyahNewX to ((myWidth / 2) - (NewYahWidth / 2))
					set nyahNewY to ((myHeight / 2) - (NewYahHeight))
					
				end if
				
				move NewYAH to {nyahNewX, nyahNewY}
				
			end tell
			
			--- FIND AND DUPLICATE OVERLAPPING PAGE ITEMS ---
			
			if ((count of OtherItems) > 0) then
				
				tell MapDocument
					
					repeat with theItem in OtherItems
						
						set ItemBounds to geometric bounds of theItem
						if (my DoRectanglesOverlap(MapBounds, ItemBounds)) then
							
							tell theItem
								set NewOverlapItem to duplicate to MapPage
								set item layer of NewOverlapItem to OtherLayer
							end tell
							
							set {olapY1, olapX1, olapY2, olapX2} to ItemBounds
							move NewOverlapItem to {olapX1 - mapX1, olapY1 - mapY1}
							
						end if
						
						
					end repeat
					
				end tell
				
			end if
			
			-- SAVE --
			
			--set MapFile to MapFolder & ":" & SignID & ".indd"
			
			--save MapDocument to MapFile with force save
			--close MapDocument
			
		end if
		
		--end if
		
	end repeat
	
	try
	on error s number i partial result p from f to t
		try
			tell MapDocument to make window
		end try
		error s number i partial result p from f to t
	end try
	
end tell

if (count of DuplicatePages) ­ 0 then
	
	set AppleScript's text item delimiters to " "
	set DuplicatePagetext to DuplicatePages as text
	log "Duplicate Pages: " & DuplicatePagetext
	display dialog "Duplicate Pages: " & DuplicatePagetext
	
end if

on DoRectanglesOverlap(Rect1, Rect2)
	set {R1Y1, R1X1, R1Y2, R1X2} to Rect1
	set {R2Y1, R2X1, R2Y2, R2X2} to Rect2
	
	return (R1X2 ³ R2X1) and (R1Y2 ³ R2Y1) and (R1X1 ² R2X2) and (R1Y1 ² R2Y2)
	
end DoRectanglesOverlap

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

on FileNameOfGraphic(InDesignPageItem)
	
	tell application "Adobe InDesign CC 2017"
		
		set FileName to ""
		
		set TheseAllGraphics to all graphics of InDesignPageItem
		repeat with theGraphic in TheseAllGraphics
			set theLink to item link of theGraphic
			if theLink ­ nothing then
				set FileName to name of item link of theGraphic
				exit repeat -- only do it once. The "repeat" is so that if it's empty, it doesn't do it at all.
			end if
		end repeat
		
		return FileName
	end tell
end FileNameOfGraphic

on dialoglist(L)
	set AppleScript's text item delimiters to " / "
	set LText to (L as string)
	tell me to display dialog LText
end dialoglist



on searchForPageNum:aValue withValues:values
	
	set res to {false, "error"}
	
	set valuesLength to count values
	set midIndex to valuesLength div 2
	
	if midIndex = 0 then
		if aValue = (name of first item of values as integer) then
			set res to {true, a reference to item 1 of values}
		else
			set res to {false, a reference to item 1 of values}
		end if
		return res
	end if
	
	set midValue to item midIndex of values
	set midPageNum to (name of midValue as integer)
	
	
	if midPageNum > aValue then
		set res to (my searchForPageNum:aValue withValues:(items 1 thru midIndex of values))
	else if midPageNum < aValue then
		set res to (my searchForPageNum:aValue withValues:(items (midIndex + 1) thru valuesLength of values))
	else if midPageNum = aValue then
		set res to {true, a reference to item midIndex of values}
	end if
	
	return res
	
end searchForPageNum:withValues:



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
