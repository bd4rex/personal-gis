@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\refresh-offline-kit.ps1" %*
