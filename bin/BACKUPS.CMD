set TZ=PST8PDT
c:\aaron\backups\zip -r -u c:\aaron\backups\aarondoc c:\aarondoc\*.*
c:\aaron\backups\zip -r -u c:\aaron\backups\udrive u:\*.* -x u:\backups\*.*
c:\aaron\backups\zip -r -u c:\aaron\backups\s-mktg s:\marketing\apriven\*.* 
c:\aaron\backups\zip -r -u c:\aaron\backups\s-mandp "s:\marketing and planning\apriven\*.*"
c:\aaron\backups\zip -r -u c:\aaron\backups\s-proj s:\projects\apriven\*.*
c:\aaron\backups\zip -r -u c:\aaron\backups\profile "c:\Documents and Settings\apriven\*.*" -x "c:\Documents and Settings\apriven\ntuser.dat" -x "c:\Documents and Settings\apriven\ntuser.dat.log"

xcopy c:\aaron\backups\*.zip u:\backups\ /d
