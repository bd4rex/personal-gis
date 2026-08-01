@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\create-offline-kit.ps1" %*
