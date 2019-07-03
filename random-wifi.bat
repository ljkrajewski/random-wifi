@echo off

rem https://www.howtogeek.com/204088/how-to-use-a-batch-file-to-make-powershell-scripts-easier-to-run/

rem echo "'%~dpn0.ps1' '%*'"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dpn0.ps1' '%*'"
rem PAUSE