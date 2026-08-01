@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\download-travel-guide.ps1" %*
