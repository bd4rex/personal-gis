@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\test-offline-recovery.ps1" %*
