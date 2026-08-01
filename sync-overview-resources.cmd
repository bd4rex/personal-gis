@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\sync-overview-resources.ps1" %*
