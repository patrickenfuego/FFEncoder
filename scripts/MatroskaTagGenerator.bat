@echo off
set PSScript=%~dpn0.ps1
powershell.exe -NoExit -ExecutionPolicy Bypass -File "%PSScript%" -Path "%~1"
