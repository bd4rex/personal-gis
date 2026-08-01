@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\plan-osm-incremental-updates.ps1" %*
