@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\rebuild-shared-indexes.ps1" %*
