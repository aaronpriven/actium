@echo off

call c:\aarondoc\bin\mypath.cmd

C:
chdir \aaron\cygwin\bin

set HOME=c:\aarondoc\cygwinfiles

bash --login -i -c /bin/tcsh
