@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\prune-offline-kits.ps1" %*
