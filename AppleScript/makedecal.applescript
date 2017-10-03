set IDFileFolder to "Bireme:Flag Projects:Flags 2011-02:Decals:"
set IconFileFolder to IDFileFolder & "icons & symbols:"
set OriginalIDFile to IDFileFolder & "8.25x5 decals.indd"
set NewIDFile to IDFileFolder & "Generated 8.25x5 decals.indd"

set bottomIconList to characters of "BACLFPV"
set topIconList to characters of "NRTWX"

set topIconHeights to {1.01, 0.84, 1.75, 2, 2}
set iconXCoord to 6.125
set rapidrectbounds to {0.104166666667, 0.104166666667, 4.895833333333, 5.990255555556}
set digitlist to {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}

-- set iconHeights to {A:0.6666, B:0.6666, C:0.6666, F:0.6666, N:1.01, P:0.6666, R:0.84, T:1.42, V:0.6666, W:2, X:2}
-- sadly, you can't say 'set myprop to "A" / get myprop of iconHeights 

-- Amtrak           => 'A', (bottom), 2" by .67"
-- BART             => 'B', (bottom), 2" by .67"
-- 'Amtrak/ACE'     => 'C', (bottom), 2" by .67"
-- 'Caltrain'     => 'L', (bottom), 2" by .67"
-- 'Ferry'          => 'F', (bottom), 2" by .67"
-- 'All Nighter'    => 'N', (top), 2" by 1.01"
--   Airport          => 'P', (bottom), 2" by .67"
-- Rapid            => 'R', (top), 2" by .84"
-- Transbay         => 'T', (top), 2" by 1.42"
--'VTA Light Rail' => 'V', (bottom), 2" by .67"
--Clockwise        => 'W', (top), 2" by 2"
--Counterclockwise => 'X', (top), 2" by 2"

set DecalSpecFile to open for access file "Bireme:Actium:db:f10:flags:decalspec.txt"
set DecalSpecs to read DecalSpecFile for (get eof DecalSpecFile) using delimiter ASCII character 10
close access DecalSpecFile

set FirstSpreadAlreadyPresent to true
tell application "Adobe InDesign CC 2017"
	set myDocument to open OriginalIDFile without showing window
	set myDocument to save myDocument to NewIDFile with force save
	set iconLayer to (layer named "Icons" of myDocument)
	
	tell myDocument
		set swatchRapidred to swatch "RapidRed"
		set swatchNone to swatch "None"
		set paraDestCon to paragraph style named "DestCon"
		set paraRouteCon to paragraph style named "RouteCon"
		set paraRouteExCon to paragraph style named "RouteExCon"
		set paraRouteUltCon to paragraph style named "RouteUltCon"
		
		-- set paraCodePlain to paragraph style named "Code-Plain" of myDocument
	end tell
	
	--repeat with theLineItem in items 152 through 163 of DecalSpecs
	repeat with theLineItem in DecalSpecs
		
		set theLine to contents of theLineItem
		
		tell AppleScript to set the text item delimiters to "	" -- tab
		set theLineFields to the text items of theLine
		
		set decalID to first item of theLineFields
		set myLine to second item of theLineFields
		set myswatch to third item of theLineFields
		set myRouteStyle to fourth item of theLineFields
		set hasDestination to (count of theLineFields) > 4
		if hasDestination then
			set destinationText to fifth item of theLineFields
			set iconList to characters of item 6 of theLineFields
		end if
		
		if FirstSpreadAlreadyPresent then
			set FirstSpreadAlreadyPresent to false
		else
			tell myDocument to make page
		end if
		
		set myPage to last page of myDocument
		
		my overrideswatch("Background", myPage, myswatch)
		set myLineItem to my overridetext("Line", myPage, myLine)
		
		if myRouteStyle ≠ "Route" then
			set applied paragraph style of parent story of myLineItem to (paragraph style named myRouteStyle of myDocument)
		end if
		
		-- if ((count of characters of myLine) > 2) then
		-- set applied paragraph style of parent story of page item "Line" of myPage to paraRouteCon
		-- end if
		
		-- my overridetext("noprintcode", myPage, "code->" & decalID)
		
		set linechars to characters of myLine
		if last item of linechars is "R" and digitlist contains first item of linechars then
			if not hasDestination then
				set coords to my inchcoords(iconXCoord, 0.125)
				place IconFileFolder & "R.ai" destination layer iconLayer place point coords on myPage
			end if
			tell myPage
				set myrect to make rectangle with properties {geometric bounds:rapidrectbounds, stroke color:swatchRapidred, fill color:swatchNone, «class pcOp»:rounded corner, «class pcrd»:0.25, stroke weight:5.0}
			end tell
		end if
		
		if hasDestination then
			
			if (characters of decalID contains "-") then
				my overridetext("Decalcode", myPage, decalID)
			end if
			
			my overridetext("Destination", myPage, destinationText)
			if overflows of page item "Destination" of myPage then
				set applied paragraph style of parent story of page item "Destination" of myPage to paraDestCon
				
			end if
			
			if (count of iconList) ≠ 0 then
				
				set iconYCoord to 4.2107
				
				repeat with theIconLetter in bottomIconList
					if iconList contains theIconLetter then
						set coords to my inchcoords(iconXCoord, iconYCoord)
						set thisIconFile to IconFileFolder & theIconLetter & ".ai"
						place thisIconFile destination layer iconLayer place point coords on myPage
						-- add icon, move location of next added icon
						set iconYCoord to iconYCoord - (0.6666 + 0.125)
					end if
					
				end repeat
				
				set iconYCoord to 0.125
				repeat with theIconIndex from 1 to (count of topIconList)
					--repeat with theIconLetter in topIconList
					set theIconLetter to item theIconIndex of topIconList
					if iconList contains theIconLetter then
						set theIconHeight to item theIconIndex of topIconHeights
						set coords to my inchcoords(iconXCoord, iconYCoord)
						set thisIconFile to IconFileFolder & theIconLetter & ".ai"
						place thisIconFile destination layer iconLayer place point coords on myPage
						-- add icon, move location of next added icon
						set iconYCoord to iconYCoord + (theIconHeight + 0.125)
					end if
				end repeat
				
			end if
			
		else
			
			-- set applied paragraph style of parent story of decalCodeItem to paraCodePlain
			set linelength to (count of linechars)
			
			if linelength is 3 and first item of linechars is "8" and digitlist contains item 2 of linechars and digitlist contains item 3 of linechars then
				set coords to my inchcoords(0.4968, 3.7153)
				place IconFileFolder & "N-plain.ai" destination layer iconLayer place point coords on myPage
				
			end if
			
			if linelength is 3 and first item of linechars is "6" and digitlist contains item 2 of linechars and digitlist contains item 3 of linechars then
				my overridetext("Destination", myPage, "Limited weekday hours")
			end if
			
		end if
		
	end repeat
	
	close myDocument saving yes
	
end tell

beep

on inchcoords(myX, myY)
	set inchesX to ((myX as string) & "in")
	set inchesY to ((myY as string) & "in")
	return {inchesX, inchesY}
end inchcoords

on overridetext(myLabel, myPage, myText)
	tell application "Adobe InDesign CC 2017"
		set myMasterItem to page item myLabel of applied master of myPage
		tell myMasterItem
			set myItem to override destination page myPage
		end tell
		set contents of myItem to myText
	end tell
	return myItem
end overridetext

on overridegraphic(myLabel, myPage, myEPS)
	tell application "Adobe InDesign CC 2017"
		set myMasterItem to page item myLabel of applied master of myPage
		tell myMasterItem
			set myItem to override destination page myPage
		end tell
		tell myItem to place myEPS
		return
	end tell
end overridegraphic

on overrideswatch(myLabel, myPage, myswatch)
	tell application "Adobe InDesign CC 2017"
		set myMasterItem to page item myLabel of applied master of myPage
		tell myMasterItem
			set myItem to override destination page myPage
		end tell
		set fill color of myItem to swatch myswatch of parent of parent of myPage
		
		return
	end tell
end overrideswatch


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
