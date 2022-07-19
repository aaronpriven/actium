on SaveAsEPS(Bleed, OutlineText, indd)
	
	set thePrintDirName to "SaveAsPDF"
	
	tell application id "com.adobe.InDesign"
		set inddFolder to file path of indd
		set inddName to name of indd
	end tell
	
	-- the following sets basename to be the InDesign filename without the .indd extension
	
	set AppleScript's text item delimiters to "."
	set TextItms to text items of inddName
	set LastItem to item -1 of TextItms
	if LastItem = "indd" then
		set TextItms to reverse of rest of reverse of TextItms
	end if
	set basename to (TextItms as string)
	set AppleScript's text item delimiters to ""
	
	
	tell application "System Events"
		
		if (exists folder thePrintDirName of desktop folder) is false then
			tell desktop folder to make folder with properties {name:thePrintDirName}
		end if
		set PrintFolder to folder thePrintDirName of desktop folder
		
		--if (exists folder basename of PrintFolder) is false then
		--	tell PrintFolder to make folder with properties {name:basename}
		--end if
		
		set ExportPath to (path of PrintFolder)
		
	end tell
	
	tell application id "com.adobe.InDesign"
		
		set theFileName to (ExportPath & basename) as string
		set thePDFName to (theFileName & ".pdf") as string
		
		set myBleedOffset to Bleed
		
		tell PDF export preferences
			set page range to all pages
			set bleed bottom to myBleedOffset
			set bleed top to myBleedOffset
			set bleed inside to myBleedOffset
			set bleed outside to myBleedOffset
		end tell
		
		
		--display dialog thePDFName
		
		tell indd
			with timeout of 600 seconds
				export format PDF type to thePDFName without showing options
			end timeout
		end tell
		
		
	end tell
	
end SaveAsEPS

on AskForOptions()
	
	set bleedDialog to "How much bleed should there be? " & return & "Use InDesign units, e.g.," & return & "     0.25i = one-quarter inch" & return & "     1p3 = one pica and three points" & return & "     6pt = six points" & return & "Or just 0 for no bleed."
	
	set ReturnList to display dialog bleedDialog buttons {"OK", "Cancel"} with title "Bleed" default button "OK" default answer "0.125i"
	
	set Bleed to text returned of ReturnList
	
	set OutlineText to false
	
	set L to {Bleed, OutlineText}
	
	return L
	
end AskForOptions

on run {}
	
	set Options to my AskForOptions()
	set theBleed to item 1 of Options
	set theOutlineText to item 2 of Options
	
	tell application id "com.adobe.InDesign"
		
		set theInDD to active document
		tell me to SaveAsEPS(theBleed, theOutlineText, theInDD)
		
	end tell
	
	beep
	display alert "Done exporting." giving up after 10
	
end run

on open Lst
	
	set Options to my AskForOptions()
	set theBleed to item 1 of Options
	set theOutlineText to item 2 of Options
	
	tell application id "com.adobe.InDesign"
		repeat with zItm in Lst
			set Itm to zItm as alias
			set theInDD to open Itm
			
			tell me to SaveAsEPS(theBleed, theOutlineText, theInDD)
			
			close theInDD saving no
			
		end repeat
	end tell
	
	beep
	display alert "Done exporting." giving up after 10
	
end open
