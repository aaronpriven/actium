@ECHO OFF
SET TZ=PST8PDT
SET DIRCMD= /ON /N /P
SET VIM=c:\vim\

call c:\aarondoc\bin\mypath.cmd

rem SET PATH=c:\aaron\bin;c:\aarondoc\bin;U:\BIN;%PATH%;C:\Program Files\Microsoft Office\Office

rem set PATHEXT=.gpl;.pl;%PATHEXT%

doskey vi=c:\vim\vim61\gvim $*
doskey mv=move $*
doskey rm=del $*

cd \aarondoc

title Command Me O Aaron

rem cls

echo Hello, Aaron! Welcome to Windows 2000!
